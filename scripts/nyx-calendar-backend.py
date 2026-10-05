#!/usr/bin/env python3
"""Read and create calendar events through Evolution Data Server.

Speaks the JSON contract that shell/services/Calendar.qml expects:
a list of {start, startTime, end, endTime, allDay, title, location, calendar},
dates as YYYY-MM-DD and times as HH:MM in local wall time, with allDay events
carrying empty time strings.

Wired up by calendar.nix, which supplies GI_TYPELIB_PATH.
"""

import datetime as dt
import json
import os
import sys
import urllib.parse
import uuid

import gi

gi.require_version("EDataServer", "1.2")
gi.require_version("ECal", "2.0")
gi.require_version("ICalGLib", "3.0")
from gi.repository import ECal, EDataServer, GLib, ICalGLib  # noqa: E402


def die(msg):
    print(f"nyx-calendar: {msg}", file=sys.stderr)
    raise SystemExit(1)


def registry():
    try:
        return EDataServer.SourceRegistry.new_sync(None)
    except GLib.Error as e:
        die(f"cannot reach Evolution Data Server ({e.message})")


def google_path(user, path):
    """The path Google's CalDAV endpoint serves for `user`, or None if `path` is right.

    Evolution's Google sign-in has saved a placeholder address in the path, which
    Google answers with 404, so the path is checked against the account's own.
    """
    want = f"/caldav/v2/{user}/events"
    if path.startswith("/caldav/v2/") and path != want:
        return want
    return None


def repair_google(reg):
    for source in reg.list_sources(EDataServer.SOURCE_EXTENSION_AUTHENTICATION):
        auth = source.get_extension(EDataServer.SOURCE_EXTENSION_AUTHENTICATION)
        if auth.get_method() != "Google" or not auth.get_user():
            continue
        dav = source.get_extension(EDataServer.SOURCE_EXTENSION_WEBDAV_BACKEND)
        fixed = google_path(auth.get_user(), dav.get_resource_path() or "")
        if fixed:
            dav.set_resource_path(fixed)
            try:
                source.write_sync(None)
            except GLib.Error as e:
                print(f"nyx-calendar: could not repair {source.get_display_name()}: {e.message}", file=sys.stderr)


def calendars(reg):
    repair_google(reg)
    return [
        s
        for s in reg.list_sources(EDataServer.SOURCE_EXTENSION_CALENDAR)
        if s.get_enabled()
    ]


def connect(source):
    return ECal.Client.connect_sync(source, ECal.ClientSourceType.EVENTS, 10, None)


def fmt_time(t):
    """ICalGLib.Time -> (YYYY-MM-DD, HH:MM or "", is_all_day).

    Fields are read directly: cmd_events pins each client's default timezone to
    the system one, so instance times already arrive as local wall time. Do not
    branch on t.is_utc() here -- instances come back claiming UTC while carrying
    local fields, and "converting" on that basis shifts every event by the local
    UTC offset.
    """
    if t is None or t.is_null_time():
        return "", "", True
    date = f"{t.get_year():04d}-{t.get_month():02d}-{t.get_day():02d}"
    if t.is_date():
        return date, "", True
    return date, f"{t.get_hour():02d}:{t.get_minute():02d}", False


def cmd_events(start_s, end_s):
    reg = registry()
    zone = ECal.util_get_system_timezone()
    first = dt.date.fromisoformat(start_s)
    # The panel asks for an inclusive range; DTEND semantics want the day after.
    last = dt.date.fromisoformat(end_s) + dt.timedelta(days=1)
    start = int(dt.datetime.combine(first, dt.time.min).timestamp())
    end = int(dt.datetime.combine(last, dt.time.min).timestamp())

    events = []
    reachable = False

    for source in calendars(reg):
        try:
            client = connect(source)
        except GLib.Error:
            # One unreachable calendar (offline account, revoked token) must not
            # blank out the others.
            continue
        reachable = True
        client.set_default_timezone(zone)
        name = source.get_display_name()

        def collect(*args):
            # ECal.RecurInstanceFn: (ICalGLib.Component, ICalGLib.Time start,
            # ICalGLib.Time end, GCancellable, GError). Using the per-instance
            # times is what makes a recurring event land on each of its days
            # rather than piling up on the master's DTSTART.
            comp, istart, iend = args[0], args[1], args[2]
            s_date, s_time, all_day = fmt_time(istart)
            e_date, e_time, _ = fmt_time(iend)
            if all_day and e_date:
                # iCalendar all-day DTEND is exclusive; report the last day the
                # event actually covers.
                e_date = (
                    dt.date.fromisoformat(e_date) - dt.timedelta(days=1)
                ).isoformat()
            events.append(
                {
                    "start": s_date,
                    "startTime": s_time,
                    "end": e_date or s_date,
                    "endTime": e_time,
                    "allDay": all_day,
                    "title": comp.get_summary() or "(no title)",
                    "location": comp.get_location() or "",
                    "calendar": name,
                }
            )
            return True

        try:
            client.generate_instances_sync(start, end, None, collect, None)
        except GLib.Error as e:
            print(f"nyx-calendar: {name}: {e.message}", file=sys.stderr)

    if not reachable:
        die("no calendar could be opened -- add one from the calendar panel")

    events.sort(key=lambda e: (e["start"], e["startTime"]))
    print(json.dumps(events))


def pick_target(reg, wanted):
    sources = calendars(reg)
    if not sources:
        die("no calendars configured -- add one from the calendar panel")
    if wanted:
        for s in sources:
            if s.get_display_name() == wanted:
                return s
        die(f"no calendar named {wanted!r} (see 'nyx-calendar calendars')")
    default = reg.ref_default_calendar()
    return default if default is not None else sources[0]


def target_name():
    """Explicit override, then the cached choice, then EDS's own default."""
    env = os.environ.get("EREBUS_CALENDAR")
    if env:
        return env
    state = os.path.join(
        os.environ.get("XDG_STATE_HOME") or os.path.expanduser("~/.local/state"),
        "nyx",
        "calendar",
    )
    try:
        with open(state) as fh:
            return fh.read().strip() or None
    except OSError:
        return None


def cmd_add(text):
    import parsedatetime

    parsed = parsedatetime.Calendar().nlp(text)
    if not parsed:
        die("could not find a date in that text")
    when, flags, begin, finish, _matched = parsed[0]

    # Everything outside the matched date phrase is the title.
    title = (text[:begin] + text[finish:]).strip(" -,@") or "(no title)"
    all_day = flags == 1  # 1 = date only, 2 = time only, 3 = both

    zone = ECal.util_get_system_timezone()
    comp = ICalGLib.Component.new(ICalGLib.ComponentKind.VEVENT_COMPONENT)
    comp.set_summary(title)

    is_date = 1 if all_day else 0
    span = dt.timedelta(days=1) if all_day else dt.timedelta(hours=1)
    comp.set_dtstart(
        ICalGLib.Time.new_from_timet_with_zone(int(when.timestamp()), is_date, zone)
    )
    comp.set_dtend(
        ICalGLib.Time.new_from_timet_with_zone(
            int((when + span).timestamp()), is_date, zone
        )
    )

    reg = registry()
    source = pick_target(reg, target_name())
    try:
        connect(source).create_object_sync(comp, ECal.OperationFlags.NONE, None)
    except GLib.Error as e:
        die(e.message)

    stamp = when.strftime("%a %d %b" if all_day else "%a %d %b %H:%M")
    print(f"Added to {source.get_display_name()}: {title} - {stamp}")


def caldav_source(name, url, user):
    """An uncommitted CalDAV calendar source for the calendar's own URL."""
    parts = urllib.parse.urlsplit(url)
    if parts.scheme not in ("http", "https") or not parts.hostname:
        die("the CalDAV address must start with http:// or https://")
    secure = parts.scheme == "https"
    path = parts.path or "/"
    if parts.query:
        path += "?" + parts.query

    source = EDataServer.Source.new_with_uid(str(uuid.uuid4()), None)
    source.set_display_name(name)

    calendar = source.get_extension(EDataServer.SOURCE_EXTENSION_CALENDAR)
    calendar.set_backend_name("caldav")
    calendar.set_selected(True)

    auth = source.get_extension(EDataServer.SOURCE_EXTENSION_AUTHENTICATION)
    auth.set_host(parts.hostname)
    auth.set_port(parts.port or (443 if secure else 80))
    auth.set_user(user)

    source.get_extension(EDataServer.SOURCE_EXTENSION_WEBDAV_BACKEND).set_resource_path(path)
    source.get_extension(EDataServer.SOURCE_EXTENSION_SECURITY).set_method(
        "tls" if secure else "none"
    )
    return source


def cmd_caldav_config(name, url, user):
    print(caldav_source(name, url, user).to_string()[0])


def cmd_add_caldav(name, url, user):
    """Create the calendar, with the password read from stdin, and prove it works."""
    password = sys.stdin.readline().rstrip("\n")
    if not password:
        die("no password given")
    source = caldav_source(name, url, user)
    uid = source.get_uid()
    reg = registry()
    try:
        reg.commit_source_sync(source, None)
    except GLib.Error as e:
        die(e.message)
    # The registry holds its own copy of a committed source.
    source = reg.ref_source(uid)
    try:
        source.store_password_sync(password, True, None)
        # Opening it is what checks the address and credentials.
        connect(source)
    except GLib.Error as e:
        try:
            source.remove_sync(None)
        except GLib.Error:
            pass
        message = e.message
        if "locked" in message:
            message = "the keyring is locked, so the password cannot be saved"
        die(message)
    print(f"Added calendar {name}")


def cmd_calendars():
    for s in calendars(registry()):
        print(s.get_display_name())


def main():
    args = sys.argv[1:]
    if args[:1] == ["events"] and len(args) == 3:
        cmd_events(args[1], args[2])
    elif args[:1] == ["add"] and len(args) == 2:
        cmd_add(args[1])
    elif args[:1] == ["add-caldav"] and len(args) == 4:
        cmd_add_caldav(*args[1:])
    elif args[:1] == ["caldav-config"] and len(args) == 4:
        cmd_caldav_config(*args[1:])
    elif args[:1] == ["google-path"] and len(args) == 3:
        print(google_path(args[1], args[2]) or "")
    elif args[:1] == ["calendars"]:
        cmd_calendars()
    else:
        print(
            "usage: nyx-calendar-backend {events <start> <end>|add <text>|add-caldav <name> <url> <user>|caldav-config <name> <url> <user>|google-path <user> <path>|calendars}",
            file=sys.stderr,
        )
        raise SystemExit(2)


if __name__ == "__main__":
    main()
