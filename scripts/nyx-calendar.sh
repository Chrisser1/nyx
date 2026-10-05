case "${1:-}" in
  events)
    [ $# -eq 3 ] || { echo "usage: nyx-calendar events <start> <end>" >&2; exit 2; }
    # Non-zero exit tells Calendar.qml no account is set up.
    nyx-calendar-backend events "$2" "$3" || { echo "[]"; exit 1; } ;;
  add)
    [ $# -eq 2 ] || { echo "usage: nyx-calendar add <text>" >&2; exit 2; }
    exec nyx-calendar-backend add "$2" ;;
  # The password is read from stdin, so it never appears in a process list.
  add-caldav)
    [ $# -eq 4 ] || { echo "usage: nyx-calendar add-caldav <name> <url> <user> (password on stdin)" >&2; exit 2; }
    exec nyx-calendar-backend add-caldav "$2" "$3" "$4" ;;
  caldav-config)
    [ $# -eq 4 ] || { echo "usage: nyx-calendar caldav-config <name> <url> <user>" >&2; exit 2; }
    exec nyx-calendar-backend caldav-config "$2" "$3" "$4" ;;
  google-calendars) exec nyx-calendar-backend google-calendars ;;
  add-google)
    [ $# -eq 3 ] || { echo "usage: nyx-calendar add-google <path> <name>" >&2; exit 2; }
    exec nyx-calendar-backend add-google "$2" "$3" ;;
  remove-google)
    [ $# -eq 2 ] || { echo "usage: nyx-calendar remove-google <path>" >&2; exit 2; }
    exec nyx-calendar-backend remove-google "$2" ;;
  calendars) exec nyx-calendar-backend calendars ;;
  # Google and other online accounts: File -> New -> Collection Account.
  auth) exec evolution -c calendar ;;
  # GLib finds no time zone on NixOS without TZDIR, and GNOME Calendar aborts.
  open) TZDIR="${TZDIR:-/etc/zoneinfo}" exec gnome-calendar ;;
  *)
    echo "usage: nyx-calendar {events <start> <end>|add <text>|add-caldav <name> <url> <user>|caldav-config <name> <url> <user>|google-calendars|add-google <path> <name>|remove-google <path>|calendars|auth|open}" >&2
    exit 2 ;;
esac
