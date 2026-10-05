# Fake tailscale CLI: `status --json` prints $STUB_DIR/status.json, other commands are logged.
case "$1" in
  status) [ -f "$STUB_DIR/down" ] && { echo "failed to connect to local tailscaled" >&2; exit 1; }
          cat "$STUB_DIR/status.json" ;;
  *) echo "$*" >> "$STUB_DIR/calls" ;;
esac
