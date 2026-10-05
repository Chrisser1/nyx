case "${1:-}" in
  shutdown)  exec systemctl poweroff ;;
  reboot)    exec systemctl reboot ;;
  suspend)   exec systemctl suspend ;;
  hibernate) exec systemctl hibernate ;;
  lock)      exec sh -c "$NYX_LOCK_COMMAND" ;;
  logout)    exec hyprctl dispatch 'hl.dsp.exit()' ;;
  *)
    echo "usage: nyx-power {shutdown|reboot|suspend|hibernate|lock|logout}" >&2
    exit 2 ;;
esac
