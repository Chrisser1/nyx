case "${1:-}" in
  events)
    [ $# -eq 3 ] || { echo "usage: nyx-calendar events <start> <end>" >&2; exit 2; }
    # Non-zero exit tells Calendar.qml no account is set up.
    nyx-calendar-backend events "$2" "$3" || { echo "[]"; exit 1; } ;;
  add)
    [ $# -eq 2 ] || { echo "usage: nyx-calendar add <text>" >&2; exit 2; }
    exec nyx-calendar-backend add "$2" ;;
  calendars) exec nyx-calendar-backend calendars ;;
  # Add accounts via File -> New -> Collection Account.
  auth) exec evolution -c calendar ;;
  open) exec gnome-calendar ;;
  *)
    echo "usage: nyx-calendar {events <start> <end>|add <text>|calendars|auth|open}" >&2
    exit 2 ;;
esac
