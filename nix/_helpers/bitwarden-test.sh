# nyx-bitwarden against the fake rbw, wl-clipboard and notify-send in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub
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
echo me@example.com > "$STUB_DIR/email"
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
