# Behaviour tests for the helpers; run by the `helpers` flake check.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_usage() { if "$@" >/dev/null 2>&1; then fail "$* should fail"; else [ $? -eq 2 ] || fail "$* exit != 2"; fi; }

export HOME=$PWD/home XDG_STATE_HOME=$PWD/state XDG_RUNTIME_DIR=$PWD/run
mkdir -p "$HOME" "$XDG_RUNTIME_DIR"

for cmd in power audio kbd-backlight brightness clipboard calc calendar monitors wallpaper; do
  expect_usage "nyx-$cmd" bogus
done
expect_usage nyx-screenshot bogus

[ "$(nyx-calc eval '2 + 2')" = "4" ] || fail "calc eval"
[ "$(nyx-calc eval '5 km to m')" = "5000 m" ] || fail "calc units: $(nyx-calc eval '5 km to m')"

[ "$(nyx-wallpaper root)" = "$NYX_WALLPAPER_DIR" ] || fail "wallpaper root"
[ "$(nyx-wallpaper list)" = "$(printf 'a/still.png\nb/clip.mp4')" ] || fail "wallpaper list: $(nyx-wallpaper list)"
[ "$(nyx-wallpaper state)" = "{}" ] || fail "wallpaper state"
[ -z "$(nyx-wallpaper current DP-1)" ] || fail "wallpaper current"

nyx-kbd-backlight up || fail "kbd-backlight must no-op without an LED"

echo "all helper tests passed"
