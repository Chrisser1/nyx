# Fake calendar backend: `no-calendar` makes events fail like an empty account,
# `caldav-fails` makes add-caldav fail, and calls are logged without the password.
case "$1" in
  events) [ -f "$STUB_DIR/no-calendar" ] && exit 1; echo '[]' ;;
  add-caldav)
    echo "$*" >> "$STUB_DIR/calls"
    cat > "$STUB_DIR/password"
    if [ -f "$STUB_DIR/caldav-fails" ]; then echo "nyx-calendar: Authentication failed" >&2; exit 1; fi
    rm -f "$STUB_DIR/no-calendar" ;;
  caldav-config) echo "$*" >> "$STUB_DIR/calls" ;;
esac
