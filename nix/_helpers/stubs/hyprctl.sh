# Fake hyprctl: `-j monitors all` prints $STUB_DIR/monitors.json, eval calls are logged.
case "$1" in
  -j) [ "$2 $3" = "monitors all" ] && cat "$STUB_DIR/monitors.json" ;;
  eval) echo "$2" >> "$STUB_DIR/evals"; echo ok ;;
esac
