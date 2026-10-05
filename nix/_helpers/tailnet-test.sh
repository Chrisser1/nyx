# nyx-tailnet against the fake tailscale in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub
mkdir -p "$STUB_DIR"
cp --no-preserve=mode "$STATUS_JSON" "$STUB_DIR/status.json"

if nyx-tailnet bogus 2>/dev/null; then fail "bogus accepted"; fi
if nyx-tailnet exit-node 2>/dev/null; then fail "exit-node without target accepted"; fi

s=$(nyx-tailnet status)
[ "$(jq -r '[.available, .running, .tailnet] | join(" ")' <<< "$s")" = "true true example.com" ] || fail "summary: $s"
[ "$(jq -r '[.peers[].host] | join(" ")' <<< "$s")" = "pc-1 server pixel" ] || fail "online first, by name: $s"
[ "$(jq -r '.self | "\(.host) \(.ips[0]) \(.self)"' <<< "$s")" = "laptop 100.64.0.1 true" ] || fail "self"
[ "$(jq -r '.peers[] | select(.host == "server") | [.direct, .exitNode, .exitNodeOption, .lastSeen == ""] | join(" ")' <<< "$s")" = "true true true true" ] || fail "server peer"
[ "$(jq -r '.peers[] | select(.host == "pixel") | [.direct, .online, .lastSeen] | join(" ")' <<< "$s")" = "false false 2026-09-18T12:40:23Z" ] || fail "pixel peer"

jq '.BackendState = "Stopped" | del(.Peer)' "$STATUS_JSON" > "$STUB_DIR/status.json"
[ "$(nyx-tailnet status | jq -c '[.running, .state, .peers]')" = '[false,"Stopped",[]]' ] || fail "stopped"

touch "$STUB_DIR/down"
[ "$(nyx-tailnet status)" = '{"available":false,"running":false,"peers":[]}' ] || fail "daemon down"

nyx-tailnet up
nyx-tailnet exit-node 100.64.0.3
nyx-tailnet exit-node none
nyx-tailnet down
[ "$(cat "$STUB_DIR/calls")" = "$(printf 'up\nset --exit-node=100.64.0.3\nset --exit-node=\ndown')" ] || fail "calls: $(cat "$STUB_DIR/calls")"

echo "tailnet helper tests passed"
