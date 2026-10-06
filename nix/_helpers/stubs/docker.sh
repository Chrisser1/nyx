# Fake docker CLI: `ps` prints $STUB_DIR/ps.json (or, with --quiet, the ids in
# $STUB_DIR/ids), `stats`, `inspect` and `logs` print their stub files, other
# commands are logged. Acting on a container named "broken" fails.
case "$1" in
  ps) [ -f "$STUB_DIR/down" ] && { echo "Cannot connect to the Docker daemon" >&2; exit 1; }
      case " $* " in
        *" --quiet "*) cat "$STUB_DIR/ids" 2>/dev/null || true ;;
        *) cat "$STUB_DIR/ps.json" ;;
      esac ;;
  stats) cat "$STUB_DIR/stats.json" ;;
  inspect) cat "$STUB_DIR/inspect.json" ;;
  logs) cat "$STUB_DIR/logs.txt" ;;
  events) ;;
  *) echo "$*" >> "$STUB_DIR/calls"
     [ "${2:-}" != broken ] || { echo "Error response from daemon: $1 failed" >&2; exit 1; } ;;
esac
