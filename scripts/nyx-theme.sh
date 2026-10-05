STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx/theme.json"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/nyx/theme"
mkdir -p "$(dirname "$STATE")" "$CACHE"

usage() {
  echo "usage: nyx-theme {scheme <name> [accent]|wallpaper <path>|mode <dark|light>|sync <path>|apply|current|schemes}" >&2
  exit 2
}

state() { if [ -f "$STATE" ]; then cat "$STATE"; else cat "$NYX_DEFAULT_THEME"; fi; }
field() { state | jq -r --arg k "$1" '.[$k] // empty'; }
save() { state | jq "$@" > "$STATE.tmp" && mv "$STATE.tmp" "$STATE"; }

render_scheme() {
  local file="$NYX_SCHEMES_DIR/$1.yaml" data="$CACHE/scheme.json"
  [ -f "$file" ] || { echo "nyx-theme: unknown scheme $1" >&2; exit 1; }
  yq -o json "$file" | jq --arg accent "$2" -f "$NYX_BASE16_JQ" > "$data"
  matugen json "$data" -c "$NYX_MATUGEN_CONFIG" -q
}

render_wallpaper() {
  local image=$1
  [ -f "$image" ] || { echo "nyx-theme: no such file $image" >&2; exit 1; }
  # matugen needs a still; take a frame from videos.
  case "${image,,}" in
    *.mp4|*.mkv|*.webm|*.avi|*.mov)
      ffmpeg -y -loglevel error -ss 1 -i "$image" -frames:v 1 "$CACHE/frame.png"
      image="$CACHE/frame.png" ;;
  esac
  matugen image "$image" -c "$NYX_MATUGEN_CONFIG" -q \
    -m "$2" -t "$NYX_MATUGEN_TYPE" --source-color-index 0
}

apply_state() {
  case "$(field source)" in
    scheme) render_scheme "$(field scheme)" "$(field accent)" ;;
    wallpaper)
      if [ -n "$(field wallpaper)" ]; then render_wallpaper "$(field wallpaper)" "$(field mode)"; fi ;;
    *) echo "nyx-theme: invalid state in $STATE" >&2; exit 1 ;;
  esac
}

case "${1:-}" in
  scheme)
    [ $# -ge 2 ] || usage
    accent=${3:-$(field accent)}
    render_scheme "$2" "${accent:-base0D}"
    save --arg s "$2" --arg a "${accent:-base0D}" '.source = "scheme" | .scheme = $s | .accent = $a' ;;
  wallpaper)
    [ $# -ge 2 ] || usage
    path=$(realpath "$2")
    mode=$(field mode)
    render_wallpaper "$path" "${mode:-dark}"
    save --arg w "$path" '.source = "wallpaper" | .wallpaper = $w' ;;
  mode)
    case "${2:-}" in dark|light) ;; *) usage ;; esac
    save --arg m "$2" '.mode = $m'
    if [ "$(field source)" = wallpaper ]; then apply_state; fi ;;
  sync)
    # Called on wallpaper changes; only matters when following the wallpaper.
    [ $# -ge 2 ] || usage
    if [ "$(field source)" = wallpaper ]; then
      save --arg w "$(realpath "$2")" '.wallpaper = $w'
      apply_state
    fi ;;
  apply) apply_state ;;
  current) state ;;
  schemes) find "$NYX_SCHEMES_DIR" -name '*.yaml' -printf '%f\n' | sed 's/\.yaml$//' | sort ;;
  *) usage ;;
esac
