# nyx-bitwarden against the fake rbw, wl-clipboard and notify-send in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub XDG_DATA_HOME=$PWD/data
mkdir -p "$STUB_DIR/secrets"
cat > "$STUB_DIR/list.json" <<'JSON'
[
  {"id":"u1","name":"GitHub","user":"chris","folder":"Dev","uris":["https://github.com"],"type":"Login"},
  {"id":"u2","name":"Wifi","user":null,"folder":null,"uris":null,"type":"Note"}
]
JSON
printf 'hunter2' > "$STUB_DIR/secrets/u1.password"
printf 'chris' > "$STUB_DIR/secrets/u1.username"
printf '123456' > "$STUB_DIR/secrets/u1.totp"

if nyx-bitwarden bogus 2>/dev/null; then fail "bogus accepted"; fi
if nyx-bitwarden copy u1 2>/dev/null; then fail "copy without field accepted"; fi
if nyx-bitwarden copy u1 secret 2>/dev/null; then fail "unknown field accepted"; fi

[ "$(nyx-bitwarden list)" = '{"state":"unconfigured","entries":[]}' ] || fail "unconfigured"
if nyx-bitwarden setup me@example.com mars 2>/dev/null; then fail "unknown region accepted"; fi
if nyx-bitwarden setup me@example.com 2>/dev/null; then fail "setup without region accepted"; fi

# A failed login still records the email, so the launcher offers login again.
touch "$STUB_DIR/login-fails"
if nyx-bitwarden setup me@example.com eu; then fail "failed login succeeded"; fi
grep -q "Login failed: Username or password is incorrect" "$STUB_DIR/notifications" || fail "login failure notified"
[ "$(nyx-bitwarden list)" = '{"state":"login","entries":[]}' ] || fail "login after failed setup"
rm "$STUB_DIR/login-fails"
rbw login

nyx-bitwarden setup me@example.com eu
[ "$(cat "$STUB_DIR/cfg/base_url")" = https://api.bitwarden.eu ] || fail "eu base url"
[ "$(cat "$STUB_DIR/cfg/identity_url")" = https://identity.bitwarden.eu ] || fail "eu identity url"
[ "$(cat "$STUB_DIR/cfg/pinentry")" = /stub/pinentry ] || fail "pinentry configured"
[ "$(nyx-bitwarden list | jq -r .state)" = unlocked ] || fail "setup unlocks"
grep -q sync "$STUB_DIR/calls" || fail "setup syncs"
nyx-bitwarden setup me@example.com https://vault.example.org
[ "$(cat "$STUB_DIR/cfg/base_url")" = https://vault.example.org ] || fail "self-hosted base url"
[ ! -e "$STUB_DIR/cfg/identity_url" ] || fail "self-hosted keeps identity url"
nyx-bitwarden setup me@example.com com
[ ! -e "$STUB_DIR/cfg/base_url" ] || fail "com clears base url"

# A device Bitwarden has not seen is registered with the API key, then logged in.
touch "$STUB_DIR/new-device"
rm -f "$STUB_DIR/cfg/email" "$XDG_DATA_HOME/rbw/me@example.com.json" "$STUB_DIR/calls" "$STUB_DIR/notifications"
nyx-bitwarden setup me@example.com eu
grep -q '^register$' "$STUB_DIR/calls" || fail "new device is registered"
grep -q "New device: enter your API key" "$STUB_DIR/notifications" || fail "API key hint notified"
[ "$(nyx-bitwarden list | jq -r .state)" = unlocked ] || fail "logged in after registering"
# An ordinary failed login does not ask for an API key.
rm -f "$STUB_DIR/new-device" "$STUB_DIR/registered" "$STUB_DIR/calls" "$XDG_DATA_HOME/rbw/me@example.com.json"
touch "$STUB_DIR/login-fails"
if nyx-bitwarden setup me@example.com eu; then fail "failed login succeeded"; fi
if grep -q '^register$' "$STUB_DIR/calls" 2>/dev/null; then fail "wrong password asked for an API key"; fi
rm "$STUB_DIR/login-fails"
rbw login

nyx-bitwarden lock
[ "$(nyx-bitwarden list)" = '{"state":"locked","entries":[]}' ] || fail "locked"
nyx-bitwarden unlock
l=$(nyx-bitwarden list)
[ "$(jq -r '.state' <<< "$l")" = unlocked ] || fail "unlocked: $l"
[ "$(jq -c '.entries[0]' <<< "$l")" = '{"id":"u1","name":"GitHub","user":"chris","folder":"Dev","type":"Login","uri":"https://github.com"}' ] || fail "login entry: $l"
[ "$(jq -c '.entries[1] | [.user, .folder, .uri]' <<< "$l")" = '["","",""]' ] || fail "nulls become empty: $l"

nyx-bitwarden copy u1 password
[ "$(cat "$STUB_DIR/clip")" = hunter2 ] && [ -f "$STUB_DIR/sensitive" ] || fail "password copied as sensitive"
nyx-bitwarden copy u1 username
[ "$(cat "$STUB_DIR/clip")" = chris ] || fail "username"
nyx-bitwarden copy u1 totp
[ "$(cat "$STUB_DIR/clip")" = 123456 ] || fail "totp"
if nyx-bitwarden copy u2 totp; then fail "missing totp succeeded"; fi
[ "$(cat "$STUB_DIR/clip")" = 123456 ] || fail "failed copy touched the clipboard"
grep -q "Could not read the totp" "$STUB_DIR/notifications" || fail "failure notified"

# Cleared after NYX_BITWARDEN_CLEAR seconds, unless something else was copied.
nyx-bitwarden copy u1 password
sleep 2
[ ! -e "$STUB_DIR/clip" ] || fail "secret not cleared"
nyx-bitwarden copy u1 password
printf 'other' | wl-copy
sleep 2
[ "$(cat "$STUB_DIR/clip")" = other ] || fail "cleared someone else's copy"

nyx-bitwarden lock
[ "$(nyx-bitwarden list | jq -r .state)" = locked ] || fail "lock"

echo "bitwarden helper tests passed"
