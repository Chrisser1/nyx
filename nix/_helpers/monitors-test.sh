# nyx-monitors against the fake hyprctl and notify-send in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub XDG_STATE_HOME=$PWD/state XDG_CONFIG_HOME=$PWD/config
mkdir -p "$STUB_DIR"
STATE_FILE=$XDG_STATE_HOME/nyx/monitors/profiles.json
cat > "$STUB_DIR/monitors.json" <<'JSON'
[
  {"id":0,"name":"HDMI-A-1","description":"Dell (HDMI-A-1)","width":1920,"height":1080,"refreshRate":60,"x":0,"y":0,"scale":1,"disabled":false,"mirrorOf":"none","focused":false},
  {"id":1,"name":"DP-1","description":"LG (DP-1)","width":2560,"height":1440,"refreshRate":143.97,"x":1920,"y":0,"scale":1,"disabled":false,"mirrorOf":"none","focused":true}
]
JSON

want=$(printf 'HDMI-A-1\t1920x1080@60\tenabled\tnone\t-\nDP-1\t2560x1440@143\tenabled\tnone\tfocused')
[ "$(nyx-monitors list | cut -f1,3,6,7,8)" = "$want" ] || fail "list: $(nyx-monitors list)"

# Hyprland names a mirror source by id; the list shows its name.
jq '(.[0].mirrorOf = "1")' "$STUB_DIR/monitors.json" > "$STUB_DIR/mirrored.json"
cp "$STUB_DIR/monitors.json" "$STUB_DIR/plain.json" && cp "$STUB_DIR/mirrored.json" "$STUB_DIR/monitors.json"
[ "$(nyx-monitors list | cut -f1,7 | paste -sd ' ')" = $'HDMI-A-1\tDP-1 DP-1\tnone' ] || fail "mirror source by name: $(nyx-monitors list)"
cp "$STUB_DIR/plain.json" "$STUB_DIR/monitors.json"

if nyx-monitors mirror HDMI-A-1 2>/dev/null; then fail "mirror without a target accepted"; fi

# The mirrored output is the target; `mirror` names the source.
nyx-monitors mirror HDMI-A-1 DP-1
grep -qF 'output = "DP-1", disabled = false, mode = "preferred", position = "auto", scale = 1, mirror = "HDMI-A-1"' "$STUB_DIR/evals" || fail "mirror eval: $(cat "$STUB_DIR/evals")"
grep -q "HDMI-A-1  →  DP-1" "$STUB_DIR/notifications" || fail "mirror notified"

# Undoing it puts back the geometry saved before mirroring.
nyx-monitors unmirror DP-1
grep -qF 'output = "DP-1", disabled = false, mode = "2560x1440@143.97"' "$STUB_DIR/evals" || fail "unmirror restores the mode: $(cat "$STUB_DIR/evals")"
grep -qF 'position = "1920x0", scale = 1, mirror = "none"' "$STUB_DIR/evals" || fail "unmirror clears the mirror"

# A change is applied in place and saved under the set of connected monitors.
: > "$STUB_DIR/evals"
nyx-monitors scale DP-1 1.5
grep -qF 'output = "DP-1", mode = "2560x1440@143.97", position = "1920x0", scale = 1.5' "$STUB_DIR/evals" || fail "scale eval: $(cat "$STUB_DIR/evals")"
if nyx-monitors scale DP-1 2>/dev/null; then fail "scale without a value accepted"; fi
if nyx-monitors scale NOPE 2 2>/dev/null; then fail "scale of an unknown output accepted"; fi
# The fake compositor does not move on its own, so show it the new scale.
jq '(.[1].scale = 1.5)' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
nyx-monitors save
[ "$(jq -r '.sets["Dell+LG"].LG.scale' "$STATE_FILE")" = 1.5 ] || fail "profile keeps the scale: $(cat "$STATE_FILE")"
[ "$(jq -r '.known.LG.scale' "$STATE_FILE")" = 1.5 ] || fail "monitor remembered"
grep -qF 'scale    = 1.5' "$XDG_CONFIG_HOME/hypr/monitors.lua" || fail "boot fallback written: $(cat "$XDG_CONFIG_HOME/hypr/monitors.lua")"
grep -qF 'output   = "DP-1"' "$XDG_CONFIG_HOME/hypr/monitors.lua" || fail "fallback names the connector"

# After a reboot Hyprland starts with defaults; restore puts the profile back.
jq '(.[1].scale = 1)' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
: > "$STUB_DIR/evals"
nyx-monitors restore
grep -qF 'output = "DP-1", disabled = false, mode = "2560x1440@143.97", position = "1920x0", scale = 1.5, mirror = "none"' "$STUB_DIR/evals" || fail "restore: $(cat "$STUB_DIR/evals")"

# The same screens on other connectors are still the same set.
jq '(.[1].name = "DP-3") | (.[1].description = "LG (DP-3)")' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
: > "$STUB_DIR/evals"
nyx-monitors restore
grep -qF 'output = "DP-3", disabled = false' "$STUB_DIR/evals" || fail "restore by identity: $(cat "$STUB_DIR/evals")"
jq '(.[1].name = "DP-1") | (.[1].description = "LG (DP-1)")' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"

# A new screen: the known one keeps its mode and scale, the new one is left alone.
jq '. + [{"id":2,"name":"DP-2","description":"Acme (DP-2)","width":1280,"height":720,"refreshRate":60,"x":4480,"y":0,"scale":1,"disabled":false,"mirrorOf":"none","focused":false}]' \
  "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
: > "$STUB_DIR/evals"
nyx-monitors restore
[ "$(wc -l < "$STUB_DIR/evals")" = 2 ] || fail "only known screens touched: $(cat "$STUB_DIR/evals")"
grep -qF 'output = "DP-1", disabled = false, mode = "2560x1440@143.97", position = "auto", scale = 1.5' "$STUB_DIR/evals" || fail "known screen keeps scale: $(cat "$STUB_DIR/evals")"
if grep -q 'DP-2' "$STUB_DIR/evals"; then fail "unknown screen configured"; fi
jq -e '.sets["Acme+Dell+LG"]' "$STATE_FILE" > /dev/null || fail "new set saved"

# Back to the pair: its own layout returns.
jq 'map(select(.name != "DP-2"))' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
: > "$STUB_DIR/evals"
nyx-monitors restore
grep -qF 'position = "1920x0", scale = 1.5' "$STUB_DIR/evals" || fail "pair profile back: $(cat "$STUB_DIR/evals")"

# A set with nothing known is left to Hyprland.
jq '[{"id":0,"name":"DP-9","description":"Nobody (DP-9)","width":800,"height":600,"refreshRate":60,"x":0,"y":0,"scale":1,"disabled":false,"mirrorOf":"none","focused":true}]' \
  "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && cp "$STUB_DIR/monitors.json" "$STUB_DIR/pair.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
: > "$STUB_DIR/evals"
nyx-monitors restore
[ ! -s "$STUB_DIR/evals" ] || fail "unknown set touched: $(cat "$STUB_DIR/evals")"
cp "$STUB_DIR/pair.json" "$STUB_DIR/monitors.json"

# Enabling a disabled output uses what the profile remembers.
jq '(.[0].disabled = true)' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"
nyx-monitors save
jq -e '.sets["Dell+LG"].Dell | .disabled and .mode == "1920x1080@60"' "$STATE_FILE" > /dev/null || fail "disabled keeps geometry: $(cat "$STATE_FILE")"
: > "$STUB_DIR/evals"
nyx-monitors enable HDMI-A-1
grep -qF 'output = "HDMI-A-1", disabled = false, mode = "1920x1080@60", position = "0x0", scale = 1, mirror = "none"' "$STUB_DIR/evals" || fail "enable: $(cat "$STUB_DIR/evals")"
jq '(.[0].disabled = false)' "$STUB_DIR/monitors.json" > "$STUB_DIR/n.json" && mv "$STUB_DIR/n.json" "$STUB_DIR/monitors.json"

jq 'map(select(.name == "DP-1"))' "$STUB_DIR/monitors.json" > "$STUB_DIR/one.json" && mv "$STUB_DIR/one.json" "$STUB_DIR/monitors.json"
if nyx-monitors disable DP-1; then fail "disabled the only monitor"; fi
grep -q "Refusing to disable" "$STUB_DIR/notifications" || fail "refusal notified"

echo "monitors helper tests passed"
