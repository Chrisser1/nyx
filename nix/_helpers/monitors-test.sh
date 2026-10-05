# nyx-monitors against the fake hyprctl and notify-send in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub XDG_STATE_HOME=$PWD/state
mkdir -p "$STUB_DIR"
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

jq 'map(select(.name == "DP-1"))' "$STUB_DIR/monitors.json" > "$STUB_DIR/one.json" && mv "$STUB_DIR/one.json" "$STUB_DIR/monitors.json"
if nyx-monitors disable DP-1; then fail "disabled the only monitor"; fi
grep -q "Refusing to disable" "$STUB_DIR/notifications" || fail "refusal notified"

echo "monitors helper tests passed"
