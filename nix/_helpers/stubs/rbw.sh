# Fake rbw backed by $STUB_DIR: `email` marks it configured, login writes the
# vault file under $XDG_DATA_HOME, `unlocked` unlocks,
# list.json is the vault and secrets/<id>.<field> the secrets.
case "$1" in
  config) [ -f "$STUB_DIR/email" ] || exit 1; echo "{\"email\":\"$(cat "$STUB_DIR/email")\"}" ;;
  login) mkdir -p "$XDG_DATA_HOME/rbw" && touch "$XDG_DATA_HOME/rbw/api.bitwarden.com:$(cat "$STUB_DIR/email").json" ;;
  unlocked) [ -f "$STUB_DIR/unlocked" ] ;;
  unlock) touch "$STUB_DIR/unlocked" ;;
  lock) rm -f "$STUB_DIR/unlocked" ;;
  sync) echo sync >> "$STUB_DIR/calls" ;;
  list) cat "$STUB_DIR/list.json" ;;
  get) if [ "$2" = --field ]; then f="$4.$3"; else f="$2.password"; fi
       cat "$STUB_DIR/secrets/$f" 2>/dev/null || { echo "couldn't find entry" >&2; exit 1; } ;;
  code) cat "$STUB_DIR/secrets/$2.totp" 2>/dev/null || { echo "not a totp entry" >&2; exit 1; } ;;
esac
