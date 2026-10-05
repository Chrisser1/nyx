# Behaviour tests for nyx-theme; run by the `theme` flake check.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }
expect_status() { local want=$1; shift; if "$@" >/dev/null 2>&1; then got=0; else got=$?; fi; [ "$got" -eq "$want" ] || fail "$* exited $got, want $want"; }

export HOME=$PWD/home
unset XDG_CONFIG_HOME XDG_STATE_HOME XDG_CACHE_HOME
mkdir -p "$HOME"
colors=$HOME/.local/state/nyx/colors.json
outputs=(
  "$colors"
  "$HOME/.config/kitty/themes/nyx.conf"
  "$HOME/.config/hypr/nyx-theme.lua"
  "$HOME/.config/gtk-3.0/nyx.css"
  "$HOME/.config/gtk-4.0/nyx.css"
  "$HOME/.config/qt5ct/colors/nyx.conf"
  "$HOME/.config/qt6ct/colors/nyx.conf"
  "$HOME/.config/btop/themes/nyx.theme"
)

check_outputs() {
  for f in "${outputs[@]}"; do
    [ -s "$f" ] || fail "missing $f"
    if grep -q '{{\|}}' "$f"; then fail "unrendered keyword in $f"; fi
  done
  jq -e 'to_entries | all(.value | test("^#[0-9a-f]{6}$"))' "$colors" >/dev/null || fail "colors.json not all hex"
  luac -p "$HOME/.config/hypr/nyx-theme.lua" || fail "hyprland theme is not valid Lua"
}

expect_status 2 nyx-theme
expect_status 2 nyx-theme mode purple
expect_status 1 nyx-theme scheme no-such-scheme
expect_status 2 nyx-theme-hook

# The kitty hook reaches a process named kitty.
printf '#!%s\ntrap "touch %s/reloaded; exit 0" USR1\nwhile :; do sleep 0.1; done\n' "$(command -v bash)" "$PWD" > kitty
chmod +x kitty
./kitty &
sleep 0.5
nyx-theme-hook kitty
for _ in $(seq 20); do [ -e reloaded ] && break; sleep 0.1; done
[ -e reloaded ] || fail "kitty hook did not signal kitty"

nyx-theme schemes | jq -e 'length > 300 and any(.id == "gruvbox-dark-medium")
  and all(.colors | length == 16 and all(test("^#[0-9a-fA-F]{6}$")))' > /dev/null || fail "scheme index"
[ "$(nyx-theme current | jq -r .scheme)" = gruvbox-dark-medium ] || fail "default state"

# Named scheme.
nyx-theme scheme gruvbox-dark-medium base0B
check_outputs
[ "$(jq -r .accent "$colors")" = "#b8bb26" ] || fail "accent: $(jq -r .accent "$colors")"
[ "$(jq -r .black "$colors")" = "#282828" ] || fail "surface"
grep -q '^color1  #fb4934$' "$HOME/.config/kitty/themes/nyx.conf" || fail "kitty red"
grep -qx 'color_theme = "nyx"' "$HOME/.config/btop/btop.conf" || fail "btop hook"
grep -qx "color_scheme_path=$HOME/.config/qt6ct/colors/nyx.conf" "$HOME/.config/qt6ct/qt6ct.conf" || fail "qt6ct hook"
grep -qx "custom_palette=true" "$HOME/.config/qt6ct/qt6ct.conf" || fail "qt6ct custom palette"
[ "$(nyx-theme current | jq -c '[.source, .scheme, .accent]')" = '["scheme","gruvbox-dark-medium","base0B"]' ] || fail "scheme state"
before=$(cat "$colors")
nyx-theme apply
[ "$(cat "$colors")" = "$before" ] || fail "apply is not idempotent"

# The accent persists when only the scheme changes.
nyx-theme scheme nord
[ "$(nyx-theme current | jq -r .accent)" = base0B ] || fail "accent not kept"

# Changing only the accent re-renders the scheme.
expect_status 2 nyx-theme accent base10
nyx-theme accent base0E
[ "$(jq -r .accent "$colors")" = "#b48ead" ] || fail "accent change: $(jq -r .accent "$colors")"
nord=$(cat "$colors")

# Wallpaper changes are ignored while following a scheme.
magick -size 64x64 gradient:'#d02020'-'#2040d0' wall.png
nyx-theme sync wall.png
[ "$(cat "$colors")" = "$nord" ] || fail "sync changed a scheme theme"

# Wallpaper source, still and video.
nyx-theme wallpaper wall.png
check_outputs
[ "$(nyx-theme current | jq -r .source)" = wallpaper ] || fail "wallpaper state"
[ "$(cat "$colors")" != "$nord" ] || fail "wallpaper theme did not change colours"
dark=$(cat "$colors")

ffmpeg -loglevel error -f lavfi -i testsrc=duration=2:size=64x64:rate=10 -pix_fmt yuv420p clip.mp4
nyx-theme wallpaper clip.mp4
check_outputs

nyx-theme wallpaper wall.png
nyx-theme mode light
[ "$(nyx-theme current | jq -r .mode)" = light ] || fail "mode state"
[ "$(cat "$colors")" != "$dark" ] || fail "light mode did not change colours"

# Every packaged base16 scheme converts.
for f in "$SCHEMES"/*.yaml; do
  yq -o json "$f" | jq -e --arg accent base0D -f "$BASE16_JQ" >/dev/null || fail "convert $f"
done

echo "all theme tests passed"
