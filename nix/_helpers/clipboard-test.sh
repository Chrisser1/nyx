# Behaviour tests for nyx-clipboard against a real cliphist database.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_status() { local want=$1; shift; if "$@" >/dev/null 2>&1; then got=0; else got=$?; fi; [ "$got" -eq "$want" ] || fail "$* exited $got, want $want"; }
list() { nyx-clipboard list; }

export HOME=$PWD/home XDG_CACHE_HOME=$PWD/cache XDG_STATE_HOME=$PWD/state
mkdir -p "$HOME"

expect_status 2 nyx-clipboard bogus
expect_status 2 nyx-clipboard text
expect_status 1 nyx-clipboard text 'not-an-id'
expect_status 1 nyx-clipboard text pdeadbeefdeadbeef
[ "$(list)" = "[]" ] || fail "empty list"

printf 'hello\tworld' | nyx-clipboard store
magick -size 32x16 xc:'#b8bb26' image.png
nyx-clipboard store < image.png
printf 'hunter2' | CLIPBOARD_STATE=sensitive nyx-clipboard store
CLIPBOARD_STATE=nil nyx-clipboard store < /dev/null

[ "$(list | jq length)" = 2 ] || fail "two entries; sensitive and empty states skipped"
[ "$(list | jq -c '.[0] | [.kind, .format, .width, .height, .pinned]')" = '["image","png",32,16,false]' ] || fail "image entry: $(list | jq -c '.[0]')"
[ "$(list | jq -r '.[1] | .kind + ":" + .preview')" = "text:hello world" ] || fail "text entry"
now=$(date +%s)
list | jq -e --argjson now "$now" 'all(.time != null and $now - .time < 60)' > /dev/null || fail "arrival times"

text_id=$(list | jq -r '.[1].id')
image_id=$(list | jq -r '.[0].id')
[ "$(nyx-clipboard text "$text_id")" = "$(printf 'hello\tworld')" ] || fail "text decode"
cmp -s image.png "$(nyx-clipboard image "$image_id")" || fail "image decode"
cmp -s image.png "$(nyx-clipboard image "$image_id")" || fail "cached image"

pin=$(nyx-clipboard pin "$text_id")
[[ $pin =~ ^p[0-9a-f]{16}$ ]] || fail "pin id $pin"
[ "$(list | jq -c 'map([.id, .pinned])')" = "[[\"$pin\",true],[\"$image_id\",false]]" ] || fail "pin moves entry: $(list)"
[ "$(nyx-clipboard pin "$pin")" = "" ] || fail "pinning a pin is a no-op"

nyx-clipboard wipe
[ "$(list | jq -c 'map(.id)')" = "[\"$pin\"]" ] || fail "wipe keeps pins"
[ "$(nyx-clipboard text "$pin")" = "$(printf 'hello\tworld')" ] || fail "pin text"
[ -z "$(find "$XDG_CACHE_HOME/nyx/clipboard" -type f)" ] || fail "wipe clears image cache"

nyx-clipboard unpin "$pin"
[ "$(list | jq -c 'map([.kind, .pinned])')" = '[["text",false]]' ] || fail "unpin returns to history"
expect_status 1 nyx-clipboard text "$pin"

nyx-clipboard delete "$(list | jq -r '.[0].id')"
[ "$(list)" = "[]" ] || fail "delete"
[ ! -s "$XDG_STATE_HOME/nyx/clipboard/seen.tsv" ] || fail "stale times kept"

# A history larger than a pipe buffer still records arrival times.
for i in $(seq 700); do printf "entry %04d %0120d" "$i" 0 | nyx-clipboard store; done
[ "$(list | jq "map(select(.time == null)) | length")" = 0 ] || fail "times missing in a large history"

echo "all clipboard tests passed"
