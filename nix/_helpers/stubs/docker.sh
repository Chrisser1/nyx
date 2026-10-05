# Fake docker CLI: `ps` prints $STUB_DIR/ps.json, other commands are logged.
# Acting on a container named "broken" fails.
case "$1" in
  ps) [ -f "$STUB_DIR/down" ] && { echo "Cannot connect to the Docker daemon" >&2; exit 1; }
      cat "$STUB_DIR/ps.json" ;;
  events) ;;
  *) echo "$*" >> "$STUB_DIR/calls"
     [ "${2:-}" != broken ] || { echo "Error response from daemon: $1 failed" >&2; exit 1; } ;;
esac
