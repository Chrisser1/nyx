# Tailscale status and controls. Changing state needs the user to be the
# operator (`tailscale set --operator=$USER`).
usage() {
  echo "usage: nyx-tailnet {status|up|down|exit-node <ip>|exit-node none}" >&2
  exit 2
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
  up|down) tailscale "$1" ;;
  exit-node)
    [ $# -ge 2 ] || usage
    if [ "$2" = none ]; then tailscale set --exit-node=; else tailscale set --exit-node="$2"; fi ;;
  *) usage ;;
esac
