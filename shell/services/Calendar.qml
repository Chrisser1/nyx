// Month grid + Google Calendar events for modules/calendar/CalendarPanel.qml.
//
// Events come from the `nyx-calendar` helper (nix/_helpers/calendar.nix),
// which reads Evolution Data Server and emits JSON.
// Adding the Google account is a one-time step -- see `nyx-calendar auth`.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

Singleton {
  id: root

  // Monday-first, matching the rest of the shell's date formatting.
  readonly property var weekdays: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]

  // Not bound to the SystemClock directly: it ticks every second, and today
  // only ever changes at midnight. Time.date is formatted to day precision, so
  // its change signal is exactly the midnight rollover.
  property date today: new Date()
  Connections {
    target: Time
    function onDateChanged() { root.today = new Date() }
  }

  property int viewYear: today.getFullYear()
  property int viewMonth: today.getMonth()      // 0-based, like Date
  property date selectedDate: today

  // Parsed helper output, plus whether the helper actually succeeded. These are
  // distinct: an authenticated but empty month is [] with available === true.
  property var events: []
  property bool available: false
  property bool loading: false

  // Quick-add state, for the panel's text field.
  property bool adding: false
  property string addError: ""
  signal added()

  readonly property string monthLabel: `${Qt.locale().standaloneMonthName(viewMonth)} ${viewYear}`

  function ymd(d) {
    return `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, "0")}-${String(d.getDate()).padStart(2, "0")}`
  }

  function sameDay(a, b) {
    return a.getFullYear() === b.getFullYear()
      && a.getMonth() === b.getMonth()
      && a.getDate() === b.getDate()
  }

  // The 42 cells of the visible grid, starting on the Monday on or before the
  // 1st. Recomputed whenever the view or the event list changes.
  readonly property var days: {
    const first = new Date(root.viewYear, root.viewMonth, 1)
    // getDay() is 0=Sunday; shift so Monday is 0.
    const lead = (first.getDay() + 6) % 7
    const start = new Date(root.viewYear, root.viewMonth, 1 - lead)

    const cells = []
    for (let i = 0; i < 42; i++) {
      const d = new Date(start.getFullYear(), start.getMonth(), start.getDate() + i)
      const key = root.ymd(d)
      cells.push({
        date: d,
        key: key,
        day: d.getDate(),
        inMonth: d.getMonth() === root.viewMonth,
        isToday: root.sameDay(d, root.today),
        eventCount: root.events.filter(e => e.start === key).length
      })
    }
    return cells
  }

  readonly property var selectedEvents: {
    const key = root.ymd(root.selectedDate)
    return root.events.filter(e => e.start === key)
      // All-day first, then by start time. The backend already sorts, but
      // selectedEvents is a filter over it and shouldn't rely on that.
      .sort((a, b) => (a.startTime || "").localeCompare(b.startTime || ""))
  }

  function nextMonth() {
    if (root.viewMonth === 11) { root.viewYear++; root.viewMonth = 0 }
    else { root.viewMonth++ }
  }

  function prevMonth() {
    if (root.viewMonth === 0) { root.viewYear--; root.viewMonth = 11 }
    else { root.viewMonth-- }
  }

  function goToday() {
    root.viewYear = root.today.getFullYear()
    root.viewMonth = root.today.getMonth()
    root.selectedDate = root.today
  }

  // Hands off to GNOME Calendar for anything the quick-add line can't express.
  function openExternal() {
    openProc.running = true
  }

  // Natural-language quick-add, e.g. "lunch with Sam tomorrow 12pm". The helper
  // resolves which calendar to write to; see nyx-calendar in helpers.nix.
  function addEvent(text) {
    const t = (text ?? "").trim()
    if (!t || addProc.running) return
    root.addError = ""
    root.adding = true
    addProc.command = [Host.calendar, "add", t]
    addProc.running = true
  }

  // Fetch the whole visible grid, not just the month, so the leading/trailing
  // cells get their event dots too.
  property bool pendingRefresh: false

  // viewMonth/viewYear get their initial values during construction, before
  // the `days` binding has been evaluated, so ignore refreshes until then.
  property bool ready: false
  Component.onCompleted: { root.ready = true; root.refresh() }

  function refresh() {
    if (!root.ready) return
    if (proc.running) { root.pendingRefresh = true; return }
    const cells = root.days
    if (!cells || !cells.length) return
    proc.command = [Host.calendar, "events", cells[0].key, cells[cells.length - 1].key]
    root.loading = true
    proc.running = true
  }

  onViewMonthChanged: refresh()
  onViewYearChanged: refresh()

  Process {
    id: proc
    stdout: StdioCollector {
      id: collector
      onStreamFinished: {
        root.loading = false
        try {
          root.events = JSON.parse(collector.text)
        } catch (e) {
          root.events = []
        }
      }
    }
    onExited: (code) => {
      // The helper prints "[]" and exits non-zero when no calendar account
      // has been added yet, which is what tells `available` apart from an
      // authenticated but genuinely empty month.
      root.available = code === 0
      root.refreshed = true
      root.loading = false
      if (root.pendingRefresh) {
        root.pendingRefresh = false
        root.refresh()
      }
    }
  }

  Process {
    id: addProc
    stderr: StdioCollector { id: addErr }
    onExited: (code) => {
      root.adding = false
      if (code === 0) {
        root.added()
        // Pull the new event straight back in rather than waiting for the timer.
        root.refresh()
      } else {
        root.addError = addErr.text.trim().split("\n").pop() || "Could not add event"
      }
    }
  }

  Process {
    id: openProc
    command: [Host.calendar, "open"]
  }

  // Account setup, for modules/calendar/CalendarSetup.qml. The form shows on
  // request, and by itself while there is no calendar at all.
  property bool setupOpen: false
  property bool setupDismissed: false
  property bool refreshed: false
  property bool addingCalendar: false
  property string calendarError: ""
  property string pendingPassword: ""
  signal calendarAdded()

  readonly property bool setupShown: setupOpen || (!available && refreshed && !setupDismissed)

  function openSetup() {
    root.refreshGoogle()
    root.calendarError = ""
    root.setupOpen = true
  }

  function closeSetup() {
    root.setupOpen = false
    root.setupDismissed = true
  }

  // The Google account's calendars, shared ones included, for the setup form.
  // [{ name, path, added, primary }]
  property var googleCalendars: []
  property bool googleBusy: false
  property string googleError: ""

  function refreshGoogle() {
    if (googleProc.running) return
    root.googleError = ""
    googleProc.command = [Host.calendar, "google-calendars"]
    googleProc.running = true
  }

  // Adds or removes one of them, then shows the result in the list and the grid.
  function toggleGoogle(calendar) {
    if (googleBusy || calendar.primary) return
    root.googleBusy = true
    root.googleError = ""
    googleProc.command = calendar.added
      ? [Host.calendar, "remove-google", calendar.path]
      : [Host.calendar, "add-google", calendar.path, calendar.name]
    googleProc.running = true
  }

  Process {
    id: googleProc
    stdout: StdioCollector { id: googleOut }
    stderr: StdioCollector { id: googleErr }
    onExited: code => {
      const listing = command[1] === "google-calendars"
      root.googleBusy = false
      if (code !== 0) {
        root.googleError = googleErr.text.trim().split("\n").pop() || "Could not reach Google"
        return
      }
      if (listing) {
        root.googleCalendars = JSON.parse(googleOut.text)
      } else {
        root.refresh()
        root.refreshGoogle()
      }
    }
  }

  // Google sign-in lives in Evolution; re-check once it closes.
  function openAccounts() { accountsProc.running = true }

  // The password goes over stdin, never onto a command line.
  function addCalDav(name, url, user, password) {
    if (addCalDavProc.running) return
    root.calendarError = ""
    root.addingCalendar = true
    root.pendingPassword = password
    addCalDavProc.command = [Host.calendar, "add-caldav", name, url, user]
    addCalDavProc.running = true
  }

  Process {
    id: accountsProc
    command: [Host.calendar, "auth"]
    onExited: {
      root.refresh()
      root.refreshGoogle()
    }
  }

  Process {
    id: addCalDavProc
    stdinEnabled: true
    stderr: StdioCollector { id: calDavErr }
    onStarted: {
      write(`${root.pendingPassword}\n`)
      root.pendingPassword = ""
      stdinEnabled = false
    }
    onExited: code => {
      root.addingCalendar = false
      if (code === 0) {
        root.setupOpen = false
        root.calendarAdded()
        root.refresh()
      } else {
        root.calendarError = calDavErr.text.trim().split("\n").pop() || "Could not add the calendar"
      }
    }
  }

  Timer {
    interval: 5 * 60 * 1000
    running: true
    repeat: true
    onTriggered: root.refresh()
  }
}
