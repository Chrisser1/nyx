# Containers of the user's Docker daemon; DOCKER_HOST is honoured, so rootless works.
usage() {
  echo "usage: nyx-docker {list|events|stats|start <id>|stop <id>|restart <id>|unpause <id>|remove <id>|logs <id>|shell <id>|inspect <id>|project <start|stop|restart> <name>}" >&2
  exit 2
}

[ $# -ge 1 ] || usage
case "$1" in
  list|events|stats) ;;
  start|stop|restart|unpause|remove|logs|shell|inspect) [ $# -ge 2 ] || usage ;;
  project) [ $# -eq 3 ] || usage
    case "$2" in start|stop|restart) ;; *) usage ;; esac ;;
  *) usage ;;
esac

case "$1" in
  list)
    # Running first; an unreachable daemon is reported, not an error.
    if ! out=$(docker ps --all --no-trunc --format json 2>/dev/null); then
      echo '{"available":false,"containers":[]}'
      exit 0
    fi
    jq -sc '{
      available: true,
      containers: map({
        id: .ID[:12],
        name: .Names,
        image: .Image,
        state: .State,
        status: .Status,
        ports: .Ports,
        created: .CreatedAt,
        project: (([(.Labels // "") | capture("com\\.docker\\.compose\\.project=(?<p>[^,]+)")] | .[0].p) // "")
      }) | sort_by(.state != "running", .name)
    }' <<< "$out" ;;
  events) exec docker events --filter type=container --format '{{.Action}} {{.Actor.ID}}' ;;
  start|stop|restart|unpause) docker "$1" "$2" > /dev/null ;;
  remove) docker rm "$2" > /dev/null ;;
  # stderr too: many images log there, and the panel only reads stdout.
  logs) exec docker logs --follow --tail 200 "$2" 2>&1 ;;
  stats)
    # One sample per running container, keyed by short id.
    docker stats --no-stream --format json | jq -sc 'map({key: .ID[:12], value: {
      cpu: (.CPUPerc | rtrimstr("%") | tonumber? // 0),
      memory: .MemUsage,
      memPercent: (.MemPerc | rtrimstr("%") | tonumber? // 0)
    }}) | from_entries' ;;
  inspect)
    docker inspect "$2" | jq -c '.[0] | {
      health: (.State.Health.Status // ""),
      restarts: .RestartCount,
      command: (((.Config.Entrypoint // []) + (.Config.Cmd // [])) | join(" ")),
      env: (.Config.Env // []),
      mounts: [.Mounts[] | "\(.Source // .Name) -> \(.Destination)"],
      networks: [(.NetworkSettings.Networks // {}) | to_entries[] | "\(.key) \(.value.IPAddress)"]
    }' ;;
  project)
    # A compose project is the containers carrying its label; no compose file needed.
    ids=$(docker ps --all --quiet --filter "label=com.docker.compose.project=$3")
    [ -n "$ids" ] || exit 0
    # shellcheck disable=SC2086
    docker "$2" $ids > /dev/null ;;
  shell) exec docker exec -it "$2" sh -c 'if command -v bash > /dev/null; then exec bash; else exec sh; fi' ;;
esac
