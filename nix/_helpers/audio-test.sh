# nyx-audio chain against the fake pw-dump and pw-metadata in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub XDG_STATE_HOME=$PWD/state
mkdir -p "$STUB_DIR"
log() { cat "$STUB_DIR/metadata" 2>/dev/null || true; }
nodes() { jq -n --argjson names "$1" '$names | to_entries | map({id: (.key + 10), info: {props: {"node.name": .value}}})'; }

if nyx-audio bogus 2>/dev/null; then fail "bogus accepted"; fi
if nyx-audio chain set 2>/dev/null; then fail "chain set without a name accepted"; fi
[ -z "$(nyx-audio chain)" ] || fail "nothing stored yet"

# The chain and the headset exist: the chain is pointed at the headset (ids are index + 10).
nodes '["capture.rnnoise_source","headset","webcam"]' > "$STUB_DIR/pw.json"
nyx-audio chain set headset
[ "$(nyx-audio chain)" = headset ] || fail "choice stored"
[ "$(log)" = "-n default 10 target.object headset Spa:String" ] || fail "chain targeted: $(log)"

# The stored choice is applied again when the chain comes back (PipeWire restart).
rm "$STUB_DIR/metadata"
nyx-audio chain apply
[ "$(log)" = "-n default 10 target.object headset Spa:String" ] || fail "reapplied: $(log)"

# A microphone that is gone is not targeted; the chain goes back to following the default.
nodes '["capture.rnnoise_source","webcam"]' > "$STUB_DIR/pw.json"
rm "$STUB_DIR/metadata"
nyx-audio chain apply
[ "$(log)" = "-n default -d 10 target.object" ] || fail "missing mic: $(log)"

# Without the chain there is nothing to point.
nodes '["headset"]' > "$STUB_DIR/pw.json"
rm "$STUB_DIR/metadata"
nyx-audio chain set headset
[ ! -e "$STUB_DIR/metadata" ] || fail "no chain node, but metadata set: $(log)"

echo "audio helper tests passed"
