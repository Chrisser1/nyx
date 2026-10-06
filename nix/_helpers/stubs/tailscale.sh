# Fake tailscale CLI: `status --json` prints $STUB_DIR/status.json, `ping` prints
# $STUB_DIR/ping.txt, `serve status --json` prints $STUB_DIR/serve.json; other
# commands are logged.
case "$1" in
  status) [ -f "$STUB_DIR/down" ] && { echo "failed to connect to local tailscaled" >&2; exit 1; }
          cat "$STUB_DIR/status.json" ;;
  ping) cat "$STUB_DIR/ping.txt" ;;
  serve) if [ "$2" = status ]; then cat "$STUB_DIR/serve.json"; else echo "$*" >> "$STUB_DIR/calls"; fi ;;
  file) echo "$*" >> "$STUB_DIR/calls"
        [ "$2" != get ] || echo "moved 2/2 files" ;;
  *) echo "$*" >> "$STUB_DIR/calls" ;;
esac
