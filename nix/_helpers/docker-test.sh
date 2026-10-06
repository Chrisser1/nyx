# nyx-docker against the fake docker in stubs/.
set -euo pipefail

fail() { echo "FAIL: $*" >&2; exit 1; }

export STUB_DIR=$PWD/stub
mkdir -p "$STUB_DIR"
cat > "$STUB_DIR/ps.json" <<'JSON'
{"ID":"aaaaaaaaaaaaaaaa","Names":"web","Image":"nginx:latest","State":"exited","Status":"Exited (0) 2 hours ago","Ports":"","CreatedAt":"2026-10-01 10:00:00 +0200 CEST","Labels":"com.docker.compose.project=site,com.docker.compose.service=web"}
{"ID":"bbbbbbbbbbbbbbbb","Names":"db","Image":"postgres:17","State":"running","Status":"Up 3 minutes","Ports":"0.0.0.0:5432->5432/tcp","CreatedAt":"2026-10-01 09:00:00 +0200 CEST","Labels":""}
JSON
cat > "$STUB_DIR/stats.json" <<'JSON'
{"ID":"bbbbbbbbbbbbbbbb","CPUPerc":"12.50%","MemUsage":"10MiB / 1GiB","MemPerc":"0.98%"}
JSON
cat > "$STUB_DIR/inspect.json" <<'JSON'
[{"State":{"Health":{"Status":"healthy"}},"RestartCount":2,"Config":{"Entrypoint":["docker-entrypoint.sh"],"Cmd":["postgres"],"Env":["A=1","B=2"]},"Mounts":[{"Source":"/data","Destination":"/var/lib"},{"Name":"vol","Destination":"/cache"}],"NetworkSettings":{"Networks":{"bridge":{"IPAddress":"172.17.0.2"}}}}]
JSON
printf 'aaaaaaaaaaaa\nbbbbbbbbbbbb\n' > "$STUB_DIR/ids"

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
rm "$STUB_DIR/down"

stats=$(nyx-docker stats)
[ "$(jq '.bbbbbbbbbbbb.cpu == 12.5' <<< "$stats")" = true ] || fail "stats cpu: $stats"
[ "$(jq -r '.bbbbbbbbbbbb.memory' <<< "$stats")" = "10MiB / 1GiB" ] || fail "stats memory"

summary=$(nyx-docker inspect db)
[ "$(jq -r '.health, .restarts, .command' <<< "$summary" | paste -sd,)" = "healthy,2,docker-entrypoint.sh postgres" ] || fail "inspect: $summary"
[ "$(jq -r '.mounts | join(";")' <<< "$summary")" = "/data -> /var/lib;vol -> /cache" ] || fail "inspect mounts"
[ "$(jq -r '.networks[0]' <<< "$summary")" = "bridge 172.17.0.2" ] || fail "inspect networks"

if nyx-docker project bogus site 2>/dev/null; then fail "project bogus action accepted"; fi

nyx-docker start web
nyx-docker restart db
nyx-docker unpause worker
nyx-docker remove web
nyx-docker project stop site
[ "$(cat "$STUB_DIR/calls")" = "$(printf 'start web\nrestart db\nunpause worker\nrm web\nstop aaaaaaaaaaaa bbbbbbbbbbbb')" ] || fail "calls: $(cat "$STUB_DIR/calls")"

echo "docker helper tests passed"
