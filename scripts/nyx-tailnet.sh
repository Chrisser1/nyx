# Tailscale status and controls. Changing state needs the user to be the
# operator (`tailscale set --operator=$USER`).
usage() {
  echo "usage: nyx-tailnet {status|up|down|exit-node <ip>|exit-node none|ssh <dns> [ip...]|ssh-check <dns> [ip...]|ping <ip>|send <ip> <file...>|receive <dir>|shares|share <port>|unshare <http|https> <port>|funnel <port>|unfunnel <port>}" >&2
  exit 2
}

# A TCP port number, or usage.
port_arg() {
  case $1 in
    ""|*[!0-9]*) usage ;;
  esac
  { [ "$1" -ge 1 ] && [ "$1" -le 65535 ]; } || usage
}

# Logins to try for a node, best first: an ssh config alias that points at it
# (it knows the right user), then this user, then root. Tailscale SSH only lets
# in the users the tailnet policy names, which is often just root.
candidates() {
  local dns=${1%.} short=${1%%.*} key host alias ip
  local -a words
  shift
  CANDIDATES=()
  if [ -f "$HOME/.ssh/config" ]; then
    while read -r -a words; do
      [ "${#words[@]}" -ge 2 ] && [ "${words[0],,}" = host ] || continue
      for alias in "${words[@]:1}"; do
        case $alias in *[*?!]*) continue ;; esac
        host=""
        while read -r key value; do
          [ "$key" = hostname ] && { host=$value; break; }
        done < <(ssh -G "$alias" 2> /dev/null)
        [ -n "$host" ] || continue
        if [ "$host" = "$dns" ] || [ "$host" = "$short" ]; then CANDIDATES+=("$alias"); continue; fi
        for ip in "$@"; do [ "$host" = "$ip" ] && CANDIDATES+=("$alias"); done
      done
    done < "$HOME/.ssh/config"
  fi
  [ -n "${USER:-}" ] && CANDIDATES+=("$USER@$dns")
  CANDIDATES+=("root@$dns")
}

# The first line of ssh output that says something, past the host key notice.
first_error() {
  local line
  while read -r line; do
    case $line in ""|"Warning: Permanently added"*) continue ;; esac
    echo "${line%$'\r'}"
    return
  done <<< "$1"
}

# Sets CHOSEN to the first login that gets in without a prompt, and ERRORS to
# why the others did not. Stops early when the node cannot be reached at all.
probe() {
  local cand out
  CHOSEN=""
  ERRORS=()
  for cand in "${CANDIDATES[@]}"; do
    # Throwaway host keys: the probe only runs `true`, and the real connection
    # still asks about an unknown key.
    if out=$(ssh -n -o BatchMode=yes -o ConnectTimeout=6 -o StrictHostKeyChecking=no \
        -o UserKnownHostsFile=/dev/null "$cand" true 2>&1); then
      CHOSEN=$cand
      return 0
    fi
    ERRORS+=("$cand: $(first_error "$out")")
    case $out in *refused*|*"timed out"*|*"No route"*|*"Could not resolve"*) return 1 ;; esac
  done
  return 1
}

# Interactive: the terminal stays open when ssh itself fails, so the reason can be read.
connect() {
  local rc=0
  candidates "$@"
  probe || true
  ssh "${CHOSEN:-${CANDIDATES[0]}}" || rc=$?
  if [ "$rc" -eq 255 ]; then
    echo
    printf 'ssh failed. Tried:\n'
    printf '  %s\n' "${ERRORS[@]}"
    read -r -p "Press Enter to close " _ || true
  fi
  exit "$rc"
}

case "${1:-}" in
  status)
    # Peers online first; an unreachable daemon is reported, not an error.
    if ! out=$(tailscale status --json 2>/dev/null); then
      echo '{"available":false,"running":false,"peers":[]}'
      exit 0
    fi
    jq -c '
      def node($self): {
        id: .ID,
        name: .HostName,
        host: ((.DNSName // "") | split(".")[0] | if . == "" then null else . end),
        dns: ((.DNSName // "") | rtrimstr(".")),
        ips: (.TailscaleIPs // []),
        os: .OS,
        online: (.Online // false),
        direct: ((.CurAddr // "") != ""),
        relay: (.Relay // ""),
        exitNode: (.ExitNode // false),
        exitNodeOption: (.ExitNodeOption // false),
        tailscaleSsh: ((.sshHostKeys // []) | length > 0),
        lastSeen: ((.LastSeen // "") | if startswith("0001-") then "" else . end),
        self: $self
      } | .host //= .name;
      {
        available: true,
        running: (.BackendState == "Running"),
        state: .BackendState,
        tailnet: (.CurrentTailnet.Name // ""),
        self: (if .Self then .Self | node(true) else null end),
        peers: ([(.Peer // {})[] | node(false)] | sort_by((.online | not), (.name | ascii_downcase)))
      }' <<< "$out" ;;
  ssh)
    [ $# -ge 2 ] || usage
    shift
    connect "$@" ;;
  ssh-check)
    [ $# -ge 2 ] || usage
    shift
    candidates "$@"
    ok=false
    probe && ok=true
    jq -nc --argjson ok "$ok" --arg chosen "$CHOSEN" '{ok: $ok, login: $chosen, errors: $ARGS.positional}' --args "${ERRORS[@]}" ;;
  ping)
    [ $# -eq 2 ] || usage
    # Three pings at the Tailscale layer; each says whether it went direct or via a relay.
    out=$(tailscale ping -c 3 --timeout 3s "$2" 2>&1 || true)
    jq -Rsc '
      [split("\n")[] | capture("^pong from \\S+ \\([^)]+\\) via (?<via>.+) in (?<ms>[0-9.]+)(?<unit>ms|s)$")?
        | {via, ms: ((.ms | tonumber) * (if .unit == "s" then 1000 else 1 end))}] as $pongs
      | {
          ok: ($pongs | length > 0),
          avg: (if ($pongs | length) > 0 then ($pongs | map(.ms) | add / length) else null end),
          direct: ($pongs | any(.via | test("^(DERP|peer-relay)") | not)),
          via: (($pongs | last // {}).via // ""),
          error: (if ($pongs | length) > 0 then "" else (split("\n") | map(select(. != "")) | last // "no reply") end)
        }' <<< "$out" ;;
  send)
    [ $# -ge 3 ] || usage
    tailscale file cp "${@:3}" "$2:" ;;
  receive)
    [ $# -eq 2 ] || usage
    # Moves whatever Taildrop has waiting into the directory.
    tailscale file get --verbose --conflict=rename "$2" 2>&1 ;;
  shares)
    # Tailscale Serve and Funnel entries on this device, one per host:port.
    tailscale serve status --json | jq -c '
      . as $c
      | [(.Web // {}) | to_entries[]
          | (.key | capture("^(?<host>.*):(?<port>[0-9]+)$")) as $hp
          | ($c.TCP // {})[$hp.port] as $tcp
          | (if ($tcp.HTTP // false) then "http" else "https" end) as $scheme
          | {
              port: ($hp.port | tonumber),
              scheme: $scheme,
              funnel: (($c.AllowFunnel // {})[.key] // false),
              url: "\($scheme)://\($hp.host)\(if ($scheme == "https" and $hp.port == "443") or ($scheme == "http" and $hp.port == "80") then "" else ":\($hp.port)" end)",
              mounts: [.value.Handlers | to_entries[] | {path: .key, target: (.value.Proxy // .value.Path // .value.Text // "")}]
            }
        ] | sort_by(.port)' ;;
  share)
    [ $# -eq 2 ] || usage
    port_arg "$2"
    # Tailnet only, over plain http on the same port number.
    tailscale serve --bg --http="$2" "$2" > /dev/null ;;
  unshare)
    [ $# -eq 3 ] || usage
    case "$2" in http|https) ;; *) usage ;; esac
    port_arg "$3"
    tailscale serve --"$2"="$3" off ;;
  funnel)
    [ $# -eq 2 ] || usage
    port_arg "$2"
    # Public on the internet, over https on 443.
    tailscale funnel --bg "$2" > /dev/null ;;
  unfunnel)
    [ $# -eq 2 ] || usage
    port_arg "$2"
    tailscale funnel --https="$2" off ;;
  up|down) tailscale "$1" ;;
  exit-node)
    [ $# -ge 2 ] || usage
    if [ "$2" = none ]; then tailscale set --exit-node=; else tailscale set --exit-node="$2"; fi ;;
  *) usage ;;
esac
