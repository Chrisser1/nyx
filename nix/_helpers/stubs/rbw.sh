# Fake rbw backed by $STUB_DIR: cfg/<key> holds the config, login writes the
# vault file under $XDG_DATA_HOME (and fails while `login-fails` exists),
# `unlocked` unlocks, list.json is the vault and secrets/<id>.<field> the secrets.
cfg() { cat "$STUB_DIR/cfg/$1" 2>/dev/null || true; }
case "$1" in
  config)
    mkdir -p "$STUB_DIR/cfg"
    case "$2" in
      show) jq -n --arg e "$(cfg email)" --arg b "$(cfg base_url)" --arg p "$(cfg pinentry)" \
              'def v: if . == "" then null else . end; {email: ($e | v), base_url: ($b | v), pinentry: $p}' ;;
      set) printf '%s' "$4" > "$STUB_DIR/cfg/$3" ;;
      unset) rm -f "$STUB_DIR/cfg/$3" ;;
    esac ;;
  login)
    if [ -f "$STUB_DIR/login-fails" ]; then echo "Username or password is incorrect. Try again." >&2; exit 1; fi
    mkdir -p "$XDG_DATA_HOME/rbw" && touch "$XDG_DATA_HOME/rbw/$(cfg email).json" ;;
  unlocked) [ -f "$STUB_DIR/unlocked" ] ;;
  unlock) touch "$STUB_DIR/unlocked" ;;
  lock) rm -f "$STUB_DIR/unlocked" ;;
  sync) echo sync >> "$STUB_DIR/calls" ;;
  list) cat "$STUB_DIR/list.json" ;;
  get) if [ "$2" = --field ]; then f="$4.$3"; else f="$2.password"; fi
       cat "$STUB_DIR/secrets/$f" 2>/dev/null || { echo "couldn't find entry" >&2; exit 1; } ;;
  code) cat "$STUB_DIR/secrets/$2.totp" 2>/dev/null || { echo "not a totp entry" >&2; exit 1; } ;;
esac
