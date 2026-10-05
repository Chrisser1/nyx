# nyx-docker against the fake docker in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub
mkdir -p "$STUB_DIR"
cat > "$STUB_DIR/ps.json" <<'JSON'
{"ID":"aaaaaaaaaaaaaaaa","Names":"web","Image":"nginx:latest","State":"exited","Status":"Exited (0) 2 hours ago","Ports":"","CreatedAt":"2026-10-01 10:00:00 +0200 CEST","Labels":"com.docker.compose.project=site,com.docker.compose.service=web"}
{"ID":"bbbbbbbbbbbbbbbb","Names":"db","Image":"postgres:17","State":"running","Status":"Up 3 minutes","Ports":"0.0.0.0:5432->5432/tcp","CreatedAt":"2026-10-01 09:00:00 +0200 CEST","Labels":""}
JSON

if nyx-docker bogus 2>/dev/null; then fail "bogus accepted"; fi
if nyx-docker stop 2>/dev/null; then fail "stop without id accepted"; fi

list=$(nyx-docker list)
[ "$(jq -r '[.containers[].name] | join(" ")' <<< "$list")" = "db web" ] || fail "running first: $list"
[ "$(jq -r '.containers[1].project' <<< "$list")" = "site" ] || fail "compose project"
[ "$(jq -r '.containers[0].project' <<< "$list")" = "" ] || fail "no project"
[ "$(jq -r '.containers[0].id' <<< "$list")" = "bbbbbbbbbbbb" ] || fail "short id"
[ "$(jq -r '.available' <<< "$list")" = true ] || fail "available"

: > "$STUB_DIR/ps.json"
[ "$(nyx-docker list)" = '{"available":true,"containers":[]}' ] || fail "empty list"

touch "$STUB_DIR/down"
[ "$(nyx-docker list)" = '{"available":false,"containers":[]}' ] || fail "daemon down"

nyx-docker start web
nyx-docker restart db
nyx-docker unpause worker
nyx-docker remove web
[ "$(cat "$STUB_DIR/calls")" = "$(printf 'start web\nrestart db\nunpause worker\nrm web')" ] || fail "calls: $(cat "$STUB_DIR/calls")"

echo "docker helper tests passed"
