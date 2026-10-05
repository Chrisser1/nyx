# Fake notify-send: the last argument is the body.
echo "${*: -1}" >> "$STUB_DIR/notifications"
