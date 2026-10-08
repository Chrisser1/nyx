# Behaviour tests for the helpers; run by the `helpers` flake check.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_usage() { if "$@" >/dev/null 2>&1; then fail "$* should fail"; else [ $? -eq 2 ] || fail "$* exit != 2"; fi; }

export HOME=$PWD/home XDG_STATE_HOME=$PWD/state XDG_RUNTIME_DIR=$PWD/run
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"

for cmd in power audio kbd-backlight brightness clipboard calc calendar monitors wallpaper emoji; do
  expect_usage "nyx-$cmd" bogus
done
expect_usage nyx-screenshot bogus

[ "$(nyx-calc eval '2 + 2')" = "4" ] || fail "calc eval"
[ "$(nyx-calc eval '5 km to m')" = "5000 m" ] || fail "calc units: $(nyx-calc eval '5 km to m')"

[ "$(nyx-wallpaper root)" = "$NYX_WALLPAPER_DIR" ] || fail "wallpaper root"
[ "$(nyx-wallpaper list)" = "$(printf 'a/still.png\nb/clip.mp4')" ] || fail "wallpaper list: $(nyx-wallpaper list)"
[ "$(nyx-wallpaper state)" = "{}" ] || fail "wallpaper state"
[ -z "$(nyx-wallpaper current DP-1)" ] || fail "wallpaper current"

# Pause state is remembered so a replacement player can start paused.
nyx-wallpaper pause DP-1
[ -e "$XDG_RUNTIME_DIR/nyx-gslapper/DP-1.paused" ] || fail "pause marker"
nyx-wallpaper resume DP-1
[ ! -e "$XDG_RUNTIME_DIR/nyx-gslapper/DP-1.paused" ] || fail "resume clears marker"
expect_usage nyx-wallpaper pause

nyx-kbd-backlight up || fail "kbd-backlight must no-op without an LED"

# Thumbnails: one per wallpaper, JPEGs, cached between runs.
export XDG_CACHE_HOME=$PWD/cache
thumbs=$(nyx-wallpaper thumbs | sort)
[ "$(cut -f 1 <<< "$thumbs")" = "$(printf 'a/still.png\nb/clip.mp4')" ] || fail "thumbs list: $thumbs"
while IFS=$'\t' read -r rel thumb; do
  [ -s "$thumb" ] || fail "no thumbnail for $rel"
  [ "$(od -An -tx1 -N3 "$thumb" | tr -d ' ')" = ffd8ff ] || fail "$rel thumbnail is not a JPEG"
done <<< "$thumbs"
before=$(stat -c %Y "$XDG_CACHE_HOME"/nyx/wallpapers/*)
sleep 1
nyx-wallpaper thumbs > /dev/null
[ "$(stat -c %Y "$XDG_CACHE_HOME"/nyx/wallpapers/*)" = "$before" ] || fail "thumbnails regenerated"

# Emoji: recently used first, a skin tone counting as its base, capped at 32.
emoji=$(nyx-emoji list)
[ "$(jq length <<< "$emoji")" -gt 1800 ] || fail "emoji count"
[ "$(jq -r '.[0].e' <<< "$emoji")" = "😀" ] || fail "emoji default order"
jq -e '.[] | select(.n == "thumbs up") | (.k | index("+1")) and (.v | length == 5)' <<< "$emoji" > /dev/null || fail "emoji keywords/variants"
nyx-emoji record 🎉
nyx-emoji record 👍🏽
[ "$(nyx-emoji list | jq -r '[.[:2][].e] | join(" ")')" = "👍 🎉" ] || fail "emoji recent order"
nyx-emoji record 🎉
[ "$(nyx-emoji list | jq -r '.[0].e')" = "🎉" ] || fail "emoji re-use moves to front"
for e in $(nyx-emoji list | jq -r '.[100:140][].e'); do nyx-emoji record "$e"; done
[ "$(wc -l < "$XDG_STATE_HOME/nyx/emoji-recent")" -eq 32 ] || fail "emoji recent cap"

echo "all helper tests passed"
