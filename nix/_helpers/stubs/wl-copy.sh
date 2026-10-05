# Fake wl-copy: the clipboard is $STUB_DIR/clip; --sensitive is recorded.
case "$1" in
  --clear) rm -f "$STUB_DIR/clip" ;;
  --sensitive) cat > "$STUB_DIR/clip"; touch "$STUB_DIR/sensitive" ;;
  *) cat > "$STUB_DIR/clip"; rm -f "$STUB_DIR/sensitive" ;;
esac
