# Fake GNOME Calendar: logs the time zone directory it was started with.
echo "gnome-calendar TZDIR=${TZDIR:-}" >> "$STUB_DIR/calls"
