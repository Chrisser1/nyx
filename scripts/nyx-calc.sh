# qalc's mixed-unit output is only configurable via its config file.
export XDG_CONFIG_HOME="$NYX_QALC_CONFIG"

case "${1:-}" in
  eval)
    [ $# -ge 2 ] || exit 0
    qalc -t -m 2000 "$2" 2>/dev/null || exit 0 ;;
  copy)
    [ $# -ge 2 ] || { echo "usage: nyx-calc copy <text>" >&2; exit 2; }
    printf '%s' "$2" | wl-copy ;;
  update-rates) exec qalc -e ;;
  *)
    echo "usage: nyx-calc {eval <expr>|copy <text>|update-rates}" >&2
    exit 2 ;;
esac
