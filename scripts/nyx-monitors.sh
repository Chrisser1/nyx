# The Lua config has no `hyprctl keyword`; runtime changes go through hl.monitor().
#
# Layouts are remembered per set of connected monitors (a "profile"), keyed by
# what the monitors are rather than which connector they sit on. Every change
# saves the profile; `restore` re-applies it at login and when a monitor is
# plugged or unplugged. A set not seen before reuses each monitor's own last
# mode and scale, so a laptop panel keeps its scale next to a new screen.
STATE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx"
PROFILES="$STATE/monitors/profiles.json"
# Read by Hyprland before nyx starts, so the layout is right from the first frame.
FALLBACK="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/monitors.lua"
mkdir -p "$STATE/monitors"
[ -f "$PROFILES" ] || echo '{"sets":{},"known":{}}' > "$PROFILES"

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

# What a monitor is, whatever connector it is on: its description without the
# trailing "(DP-1)".
IDENT='def ident: (.description // "" | sub(" \\([^)]*\\)$"; "")) as $d | if $d == "" then .name else $d end;'

set_key() { all | jq -r "$IDENT"' [.[] | ident] | sort | join("+")'; }

# name, description, WxH@Hz, XxY, scale, enabled|disabled, mirrored output (or none), focused.
# hyprctl reports a mirror source by id, so it is looked up by name here.
list() {
  all | jq -r '. as $all | .[] | [
    .name,
    (.description // "" | split(" (")[0]),
    ((.width|tostring) + "x" + (.height|tostring) + "@" + ((.refreshRate // 0)|floor|tostring)),
    ((.x|tostring) + "x" + (.y|tostring)),
    ((.scale // 1)|tostring),
    (if .disabled then "disabled" else "enabled" end),
    (if (.mirrorOf // "none") == "none" then "none"
     else (.mirrorOf | tostring) as $id | ($all | map(select((.id | tostring) == $id)) | .[0].name) // $id end),
    (if .focused then "focused" else "-" end)
  ] | @tsv'
}

# Writes the current layout as this set's profile. A disabled or mirrored
# monitor keeps the geometry it had before, so enabling it puts it back.
save_profile() {
  local key old set tmp
  key=$(set_key)
  old=$(jq -c --arg k "$key" '.sets[$k] // {}' "$PROFILES")
  set=$(all | jq -c --argjson old "$old" "$IDENT"'
    . as $all
    | map(
        . as $m | ident as $i | ($old[$i] // {}) as $o
        | (($m.disabled // false) or (($m.mirrorOf // "none") != "none")) as $frozen
        | { key: $i, value: (
            (if $frozen and $o.mode != null then { mode: $o.mode, pos: $o.pos, scale: $o.scale }
             elif $frozen then { mode: "preferred", pos: "auto", scale: ($m.scale // 1) }
             else { mode: "\($m.width)x\($m.height)@\($m.refreshRate * 1000 | round / 1000)",
                    pos: "\($m.x)x\($m.y)", scale: ($m.scale // 1) } end)
            + { disabled: ($m.disabled // false),
                mirror: (if ($m.mirrorOf // "none") == "none" then null
                         else ($all | map(select((.id | tostring) == ($m.mirrorOf | tostring))) | .[0] | ident) end) }) })
    | from_entries')
  tmp=$(mktemp)
  jq --arg k "$key" --argjson set "$set" '
    .sets[$k] = $set
    | .known += ($set | to_entries
        | map(select((.value.disabled | not) and .value.mirror == null))
        | map({ key, value: { mode: .value.mode, scale: .value.scale } }) | from_entries)' \
    "$PROFILES" > "$tmp" && mv "$tmp" "$PROFILES"
  write_fallback "$set"
}

# The profile as a Lua file, by connector name, for the next boot.
write_fallback() {
  mkdir -p "$(dirname "$FALLBACK")"
  all | jq -r --argjson set "$1" "$IDENT"'
    . as $all
    | .[] | . as $m | ($set[ident] // empty) as $e
    | if $e.disabled then "hl.monitor({ output = \"\($m.name)\", disabled = true })"
      else "hl.monitor({\n  output   = \"\($m.name)\",\n  mode     = \"\($e.mode)\",\n  position = \"\($e.pos)\",\n  scale    = \($e.scale),"
        + (if $e.mirror then "\n  mirror   = \"\($all | map(select(ident == $e.mirror)) | .[0].name)\"," else "" end)
        + "\n})" end' > "$FALLBACK.tmp" && mv "$FALLBACK.tmp" "$FALLBACK"
}

# hl.monitor() calls that put the connected monitors into this set's profile:
# plain ones first, so a mirror finds its source, disabled ones last.
profile_lines() {
  all | jq -r --argjson set "$1" "$IDENT"'
    . as $all
    | map(. as $m | ($set[ident] // empty) as $e | { m: $m, e: $e })
    | sort_by(if .e.disabled then 2 elif .e.mirror then 1 else 0 end)
    | .[] | .m as $m | .e as $e
    | if $e.disabled then "hl.monitor({ output = \"\($m.name)\", disabled = true })"
      else "hl.monitor({ output = \"\($m.name)\", disabled = false, mode = \"\($e.mode)\", position = \"\($e.pos)\", scale = \($e.scale), mirror = \"\(if $e.mirror then ($all | map(select(ident == $e.mirror)) | .[0].name) else "none" end)\" })" end'
}

# For a set never seen: each known monitor's own mode and scale, laid out automatically.
known_lines() {
  all | jq -r --argjson known "$(jq -c .known "$PROFILES")" "$IDENT"'
    .[] | select((.disabled | not) and (.mirrorOf // "none") == "none")
    | ident as $i | select($known[$i] != null)
    | "hl.monitor({ output = \"\(.name)\", disabled = false, mode = \"\($known[$i].mode)\", position = \"auto\", scale = \($known[$i].scale), mirror = \"none\" })"'
}

apply_lines() {
  local line
  while IFS= read -r line; do
    [ -z "$line" ] || hl_eval "$line" || true
  done
}

restore() {
  local key set lines
  key=$(set_key)
  set=$(jq -c --arg k "$key" '.sets[$k] // empty' "$PROFILES")
  if [ -n "$set" ]; then
    # Never leave nothing on.
    [ "$(jq '[.[] | select(.disabled | not)] | length' <<< "$set")" -gt 0 ] || return 0
    profile_lines "$set" | apply_lines
  else
    lines=$(known_lines)
    [ -n "$lines" ] || return 0
    apply_lines <<< "$lines"
    save_profile
  fi
}

# Re-applies the profile whenever a monitor comes or goes.
watch() {
  local sock="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/hypr/${HYPRLAND_INSTANCE_SIGNATURE:?not running under Hyprland}/.socket2.sock"
  socat -U - "UNIX-CONNECT:$sock" | while IFS= read -r event; do
    case "$event" in
      monitoradded*|monitorremoved*)
        # Events come in bursts, and restoring causes some of its own.
        sleep 1
        restore
        while read -r -t 2 _; do :; done ;;
    esac
  done
}

# Where an output's mode, position and scale are now.
current() {
  all | jq -r --arg n "$1" '.[] | select(.name == $n)
    | "\(.width)x\(.height)@\(.refreshRate * 1000 | round / 1000) \(.x)x\(.y) \(.scale // 1)"'
}

# Changes one of mode, position or scale and keeps the rest.
set_geometry() {
  local out=$1 field=$2 value=$3 mode pos scale
  read -r mode pos scale <<< "$(current "$out")"
  [ -n "$mode" ] || { echo "nyx-monitors: no output $out" >&2; exit 1; }
  case "$field" in
    mode) mode=$value ;;
    position) pos=$value ;;
    scale) scale=$value ;;
  esac
  hl_eval "hl.monitor({ output = \"$out\", mode = \"$mode\", position = \"$pos\", scale = $scale })"
  save_profile
}

# Puts an output back as the profile has it; without one, as Hyprland would.
restore_geometry() {
  local saved mode pos scale
  saved=$(profile_geometry "$1")
  if [ -n "$saved" ]; then
    IFS='|' read -r mode pos scale <<< "$saved"
  else
    mode="preferred"; pos="auto"; scale="1"
  fi
  # Both disabled and mirror must be cleared explicitly.
  hl_eval "hl.monitor({ output = \"$1\", disabled = false, mode = \"$mode\", position = \"$pos\", scale = $scale, mirror = \"none\" })"
  save_profile
}

# mode|position|scale the profile holds for a connector.
profile_geometry() {
  local ident
  ident=$(all | jq -r --arg n "$1" "$IDENT"' .[] | select(.name == $n) | ident')
  [ -n "$ident" ] || return 0
  jq -r --arg k "$(set_key)" --arg i "$ident" \
    '.sets[$k][$i] // empty | select(.mode != null) | "\(.mode)|\(.pos)|\(.scale)"' "$PROFILES"
}

need() { [ "$1" -ge "$2" ] || { echo "usage: nyx-monitors $3" >&2; exit 2; }; }

case "${1:-list}" in
  list) list ;;
  json) all ;;
  arrange) wdisplays; save_profile ;;
  save)
    save_profile
    notify-send -u low -t 3000 "Display" "Layout saved" ;;
  restore) restore ;;
  watch) watch ;;
  scale|mode|position)
    need $# 3 "$1 <output> <value>"
    set_geometry "$2" "$1" "$3" ;;
  enable)
    need $# 2 "enable <output>"
    restore_geometry "$2" ;;
  disable)
    need $# 2 "disable <output>"
    if [ "$(all | jq '[.[] | select(.disabled | not)] | length')" -le 1 ]; then
      notify-send -u critical "Display" "Refusing to disable the only active monitor"
      exit 1
    fi
    save_profile
    hl_eval "hl.monitor({ output = \"$2\", disabled = true })"
    save_profile ;;
  toggle)
    need $# 2 "toggle <output>"
    if [ "$(all | jq -r --arg n "$2" '.[] | select(.name == $n) | .disabled')" = "true" ]; then
      exec "$0" enable "$2"
    else
      exec "$0" disable "$2"
    fi ;;
  mirror)
    need $# 3 "mirror <source> <target>"
    save_profile
    hl_eval "hl.monitor({ output = \"$3\", disabled = false, mode = \"preferred\", position = \"auto\", scale = 1, mirror = \"$2\" })"
    save_profile
    notify-send -u low -t 3000 "Display" "$2  →  $3  (mirrored)" ;;
  unmirror)
    need $# 2 "unmirror <output>"
    restore_geometry "$2"
    notify-send -u low -t 3000 "Display" "$2 restored to extended mode" ;;
  *)
    echo "usage: nyx-monitors {list|json|arrange|save|restore|watch|scale <o> <n>|mode <o> <WxH@Hz>|position <o> <XxY>|enable <o>|disable <o>|toggle <o>|mirror <src> <dst>|unmirror <o>}" >&2
    exit 2 ;;
esac
