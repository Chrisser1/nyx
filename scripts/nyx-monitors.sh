# The Lua config has no `hyprctl keyword`; runtime changes go through hl.monitor().
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx"
GEOMETRY="$STATE/monitors.json"
mkdir -p "$STATE"
[ -f "$GEOMETRY" ] || echo '{}' > "$GEOMETRY"

# `all`, because mirrored outputs drop out of the plain listing.
all() { hyprctl -j monitors all; }

hl_eval() {
  local out
  out=$(hyprctl eval "$1" 2>&1 || true)
  case "$out" in
    ok*) ;;
    *) echo "nyx-monitors: hyprctl eval failed: $out" >&2; return 1 ;;
  esac
}

# name, description, WxH@Hz, XxY, scale, enabled|disabled, mirrored, focused
list() {
  all | jq -r '.[] | [
    .name,
    (.description // "" | split(" (")[0]),
    ((.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate // 0)|floor|tostring)),
    ((.x|tostring) + "x" + (.y|tostring)),
    ((.scale // 1)|tostring),
    (if .disabled then "disabled" else "enabled" end),
    (if (.mirrorOf // "none") == "none" then "none" else "yes" end),
    (if .focused then "focused" else "-" end)
  ] | @tsv'
}

save_geometry() {
  local g tmp
  g=$(all | jq -r --arg n "$1" \
    '.[] | select(.name == $n and (.mirrorOf // "none") == "none" and (.disabled | not))
     | ((.width|tostring) + "x" + (.height|tostring) + "@" + (.refreshRate|tostring))
       + "|" + ((.x|tostring) + "x" + (.y|tostring)) + "|" + ((.scale // 1)|tostring)')
  [ -n "$g" ] || return 0
  tmp=$(mktemp)
  jq --arg o "$1" --arg g "$g" '.[$o] = $g' "$GEOMETRY" > "$tmp" && mv "$tmp" "$GEOMETRY"
}

restore_geometry() {
  local saved mode rest pos scale tmp
  saved=$(jq -r --arg o "$1" '.[$o] // ""' "$GEOMETRY")
  if [ -n "$saved" ]; then
    mode=${saved%%|*}; rest=${saved#*|}
    pos=${rest%%|*}; scale=${rest##*|}
  else
    mode="preferred"; pos="auto"; scale="1"
  fi
  # Both disabled and mirror must be cleared explicitly.
  hl_eval "hl.monitor({ output = \"$1\", disabled = false, mode = \"$mode\", position = \"$pos\", scale = $scale, mirror = \"none\" })"
  tmp=$(mktemp)
  jq --arg o "$1" 'del(.[$o])' "$GEOMETRY" > "$tmp" && mv "$tmp" "$GEOMETRY"
}

need() { [ "$1" -ge "$2" ] || { echo "usage: nyx-monitors $3" >&2; exit 2; }; }

case "${1:-list}" in
  list) list ;;
  json) all ;;
  arrange) exec wdisplays ;;
  # Provided by the host config.
  save) exec hypr-save-monitors ;;
  enable)
    need $# 2 "enable <output>"
    restore_geometry "$2" ;;
  disable)
    need $# 2 "disable <output>"
    if [ "$(all | jq '[.[] | select(.disabled | not)] | length')" -le 1 ]; then
      notify-send -u critical "Display" "Refusing to disable the only active monitor"
      exit 1
    fi
    save_geometry "$2"
    hl_eval "hl.monitor({ output = \"$2\", disabled = true })" ;;
  toggle)
    need $# 2 "toggle <output>"
    if [ "$(all | jq -r --arg n "$2" '.[] | select(.name == $n) | .disabled')" = "true" ]; then
      exec "$0" enable "$2"
    else
      exec "$0" disable "$2"
    fi ;;
  mirror)
    need $# 3 "mirror <source> <target>"
    save_geometry "$3"
    hl_eval "hl.monitor({ output = \"$3\", disabled = false, mode = \"preferred\", position = \"auto\", scale = 1, mirror = \"$2\" })"
    notify-send -u low -t 3000 "Display" "$2  →  $3  (mirrored)" ;;
  unmirror)
    need $# 2 "unmirror <output>"
    restore_geometry "$2"
    notify-send -u low -t 3000 "Display" "$2 restored to extended mode" ;;
  *)
    echo "usage: nyx-monitors {list|json|arrange|save|enable <o>|disable <o>|toggle <o>|mirror <src> <dst>|unmirror <o>}" >&2
    exit 2 ;;
esac
