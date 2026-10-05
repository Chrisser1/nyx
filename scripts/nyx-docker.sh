# Containers of the user's Docker daemon; DOCKER_HOST is honoured, so rootless works.
usage() {
  echo "usage: nyx-docker {list|events|start <id>|stop <id>|restart <id>|unpause <id>|remove <id>|logs <id>|shell <id>}" >&2
  exit 2
}

[ $# -ge 1 ] || usage
case "$1" in
  list|events) ;;
  start|stop|restart|unpause|remove|logs|shell) [ $# -ge 2 ] || usage ;;
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
  logs) exec docker logs --follow --tail 200 "$2" ;;
  shell) exec docker exec -it "$2" sh -c 'if command -v bash > /dev/null; then exec bash; else exec sh; fi' ;;
esac
