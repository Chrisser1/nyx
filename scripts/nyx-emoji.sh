# Emoji picker data and actions; recently used emoji are listed first.
RECENT="${XDG_STATE_HOME:-$HOME/.local/state}/nyx/emoji-recent"
MAX_RECENT=32

usage() {
  echo "usage: nyx-emoji {list|record <emoji>|copy <emoji>}" >&2
  exit 2
}

record() {
  local tmp
  mkdir -p "$(dirname "$RECENT")"
  touch "$RECENT"
  tmp=$(mktemp "$RECENT.XXXXXX")
  { printf '%s\n' "$1"; grep -vxF -- "$1" "$RECENT" || true; } | awk -v max="$MAX_RECENT" 'NR <= max' > "$tmp"
  mv "$tmp" "$RECENT"
}

case "${1:-}" in
  list)
    recent='[]'
    [ -f "$RECENT" ] && recent=$(jq -R . "$RECENT" | jq -sc .)
    # A skin-tone variant counts as a use of its base emoji.
    jq -c --argjson recent "$recent" '
      def pos($x): $recent | index($x);
      map(. + {r: ([pos(.e), (.v[].e | pos(.))] | map(select(. != null)) | min)})
      | (map(select(.r != null)) | sort_by(.r)) + map(select(.r == null))
      | map(del(.r))
    ' "$NYX_EMOJI_DATA" ;;
  record)
    [ $# -ge 2 ] || usage
    record "$2" ;;
  copy)
    [ $# -ge 2 ] || usage
    record "$2"
    printf '%s' "$2" | wl-copy
    if [ "$NYX_EMOJI_TYPE" = 1 ]; then
      # Let focus return from the launcher first.
      sleep 0.2
      wtype -- "$2"
    fi ;;
  *) usage ;;
esac
