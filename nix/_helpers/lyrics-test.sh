# nyx-lyrics against the fake curl in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub
mkdir -p "$STUB_DIR"

if nyx-lyrics onlyone 2>/dev/null; then fail "wrong argument count accepted"; fi

# Exact match.
echo '{"syncedLyrics": "[00:01.00]hello", "plainLyrics": "hello", "id": 1}' > "$STUB_DIR/get.json"
[ "$(nyx-lyrics "Some Artist" "Some Title" "Some Album" 200.4)" = '{"synced":"[00:01.00]hello","plain":"hello"}' ] || fail "exact match"
grep -q 'duration=200' "$STUB_DIR/curl.log" || fail "duration rounded: $(cat "$STUB_DIR/curl.log")"
grep -q 'artist_name=Some Artist' "$STUB_DIR/curl.log" || fail "artist passed"

# No exact match: search, synced ahead of plain.
rm "$STUB_DIR/get.json"
echo '[{"plainLyrics": "just text", "syncedLyrics": null}, {"plainLyrics": "t", "syncedLyrics": "[00:02.00]sync"}]' > "$STUB_DIR/search.json"
[ "$(nyx-lyrics a b c 100 | jq -r .synced)" = "[00:02.00]sync" ] || fail "search prefers synced"

echo '[{"plainLyrics": "only plain", "syncedLyrics": null}]' > "$STUB_DIR/search.json"
[ "$(nyx-lyrics a b c 100 | jq -r '[.synced, .plain] | join("|")')" = "|only plain" ] || fail "plain fallback"

# Nothing anywhere: {} and success.
echo '[{"plainLyrics": "", "syncedLyrics": null}]' > "$STUB_DIR/search.json"
[ "$(nyx-lyrics a b c 100)" = "{}" ] || fail "empty result"
echo '[]' > "$STUB_DIR/search.json"
[ "$(nyx-lyrics a b c 100)" = "{}" ] || fail "no hits"

# Offline: non-zero.
rm "$STUB_DIR/search.json"
if nyx-lyrics a b c 100 2>/dev/null; then fail "failure swallowed"; fi
