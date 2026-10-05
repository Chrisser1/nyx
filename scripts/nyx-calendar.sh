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
  calendars) exec nyx-calendar-backend calendars ;;
  # Google and other online accounts: File -> New -> Collection Account.
  auth) exec evolution -c calendar ;;
  open) exec gnome-calendar ;;
  *)
    echo "usage: nyx-calendar {events <start> <end>|add <text>|add-caldav <name> <url> <user>|caldav-config <name> <url> <user>|calendars|auth|open}" >&2
    exit 2 ;;
esac
