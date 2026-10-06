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

# SSH: aliases in ~/.ssh/config that point at a node win; otherwise this user, then root.
export HOME=$PWD/home USER=tester
mkdir -p "$HOME/.ssh"
cat > "$HOME/.ssh/config" <<'CONF'
Host srv
  HostName 100.64.0.3
Host other other2
  HostName elsewhere
Host *
  ControlMaster no
CONF
printf 'srv 100.64.0.3\nother elsewhere\nother2 elsewhere\n' > "$STUB_DIR/hosts"

printf 'srv\n' > "$STUB_DIR/allowed"
c=$(nyx-tailnet ssh-check server.tail0.ts.net 100.64.0.3 fd7a::3)
[ "$(jq -c '[.ok, .login, .errors]' <<< "$c")" = '[true,"srv",[]]' ] || fail "alias login: $c"

printf 'root@pc-1.tail0.ts.net\n' > "$STUB_DIR/allowed"
c=$(nyx-tailnet ssh-check pc-1.tail0.ts.net 100.64.0.4)
[ "$(jq -r '[.ok, .login] | join(" ")' <<< "$c")" = "true root@pc-1.tail0.ts.net" ] || fail "falls back to root: $c"
[ "$(jq -r '.errors[0]' <<< "$c")" = 'tester@pc-1.tail0.ts.net: tailscale: tailnet policy does not permit you to SSH as user "tester"' ] || fail "reason kept: $c"

: > "$STUB_DIR/allowed"
c=$(nyx-tailnet ssh-check pc-1.tail0.ts.net 100.64.0.4)
[ "$(jq -c '[.ok, .login, (.errors | length)]' <<< "$c")" = '[false,"",2]' ] || fail "nothing allowed: $c"

printf 'tester@pc-1.tail0.ts.net\n' > "$STUB_DIR/allowed"
: > "$STUB_DIR/calls"
nyx-tailnet ssh pc-1.tail0.ts.net 100.64.0.4
[ "$(cat "$STUB_DIR/calls")" = "ssh tester@pc-1.tail0.ts.net" ] || fail "ssh call: $(cat "$STUB_DIR/calls")"

: > "$STUB_DIR/allowed"
: > "$STUB_DIR/calls"
echo | nyx-tailnet ssh nowhere.tail0.ts.net 100.64.0.9 || true
[ "$(cat "$STUB_DIR/calls")" = "ssh tester@nowhere.tail0.ts.net" ] || fail "unreachable still tries the first login: $(cat "$STUB_DIR/calls")"
if nyx-tailnet ssh-check 2>/dev/null; then fail "ssh-check without target accepted"; fi

# Ping: direct and relayed pongs, and no reply.
printf 'pong from pc-1 (100.64.0.4) via DERP(fra) in 30ms\npong from pc-1 (100.64.0.4) via 1.2.3.4:41641 in 10ms\ndirect connection not established\n' > "$STUB_DIR/ping.txt"
p=$(nyx-tailnet ping 100.64.0.4)
[ "$(jq -c '[.ok, .avg, .direct, .via]' <<< "$p")" = '[true,20,true,"1.2.3.4:41641"]' ] || fail "direct ping: $p"
printf 'pong from pc-1 (100.64.0.4) via DERP(ams) in 1.2s\n' > "$STUB_DIR/ping.txt"
p=$(nyx-tailnet ping 100.64.0.4)
[ "$(jq -c '[.ok, .avg, .direct, .via]' <<< "$p")" = '[true,1200,false,"DERP(ams)"]' ] || fail "relayed ping: $p"
printf 'no reply from 100.64.0.4\n' > "$STUB_DIR/ping.txt"
p=$(nyx-tailnet ping 100.64.0.4)
[ "$(jq -c '[.ok, .avg, .error]' <<< "$p")" = '[false,null,"no reply from 100.64.0.4"]' ] || fail "unanswered ping: $p"
if nyx-tailnet ping 2>/dev/null; then fail "ping without target accepted"; fi

# Serve and Funnel entries.
cp --no-preserve=mode "$SERVE_JSON" "$STUB_DIR/serve.json"
sh=$(nyx-tailnet shares)
[ "$(jq -r '[.[] | "\(.port) \(.scheme) \(.funnel) \(.url)"] | join("|")' <<< "$sh")" = "443 https true https://pc.tail0.ts.net|8080 http false http://pc.tail0.ts.net:8080" ] || fail "shares: $sh"
[ "$(jq -r '.[0].mounts | map("\(.path)=\(.target)") | join(" ")' <<< "$sh")" = "/=http://127.0.0.1:3000 /files=/srv/files" ] || fail "share mounts: $sh"
echo '{}' > "$STUB_DIR/serve.json"
[ "$(nyx-tailnet shares)" = '[]' ] || fail "no shares"

: > "$STUB_DIR/calls"
nyx-tailnet share 3000
nyx-tailnet unshare http 3000
nyx-tailnet funnel 3000
nyx-tailnet unfunnel 443
nyx-tailnet send 100.64.0.4 /tmp/a.txt "/tmp/b c.txt"
[ "$(nyx-tailnet receive /tmp/inbox)" = "moved 2/2 files" ] || fail "receive output"
[ "$(cat "$STUB_DIR/calls")" = "$(printf 'serve --bg --http=3000 3000\nserve --http=3000 off\nfunnel --bg 3000\nfunnel --https=443 off\nfile cp /tmp/a.txt /tmp/b c.txt 100.64.0.4:\nfile get --verbose --conflict=rename /tmp/inbox')" ] || fail "share calls: $(cat "$STUB_DIR/calls")"
for bad in "share abc" "share 0" "share 70000" "unshare ftp 80" "funnel -1" "send 100.64.0.4"; do
  # shellcheck disable=SC2086
  if nyx-tailnet $bad 2>/dev/null; then fail "'$bad' accepted"; fi
done

: > "$STUB_DIR/calls"
nyx-tailnet up
nyx-tailnet exit-node 100.64.0.3
nyx-tailnet exit-node none
nyx-tailnet down
[ "$(cat "$STUB_DIR/calls")" = "$(printf 'up\nset --exit-node=100.64.0.3\nset --exit-node=\ndown')" ] || fail "calls: $(cat "$STUB_DIR/calls")"

echo "tailnet helper tests passed"
