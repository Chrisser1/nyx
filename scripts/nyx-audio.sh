# Audio helpers. `chain` picks the microphone the noise cancelling source
# listens to: the chain (modules/features/system/noise-cancellation.nix) has no
# fixed input, so it would follow the default source, which is itself once the
# chain is the default. The choice is stored and applied through PipeWire's
# default metadata, which does not outlive PipeWire.
MIC_FILE="${XDG_STATE_HOME:-$HOME/.local/state}/nyx/audio-mic"
CHAIN_NODE=capture.rnnoise_source

usage() {
  echo "usage: nyx-audio {set-default <node-id>|mute-output|mute-input|chain [set <node-name>|apply]}" >&2
  exit 2
}

# Points the chain at the stored microphone, or back at the default when that
# microphone is gone (a missing target would leave the chain unlinked).
chain_apply() {
  local dump id name
  dump=$(pw-dump)
  id=$(jq -r --arg n "$CHAIN_NODE" '[.[] | select(.info.props["node.name"] == $n)][0].id // empty' <<< "$dump")
  [ -n "$id" ] || return 0
  name=$(cat "$MIC_FILE" 2>/dev/null || true)
  if [ -n "$name" ] && jq -e --arg n "$name" 'any(.[]; .info.props["node.name"] == $n)' <<< "$dump" > /dev/null; then
    pw-metadata -n default "$id" target.object "$name" Spa:String > /dev/null
  else
    pw-metadata -n default -d "$id" target.object > /dev/null
  fi
}

case "${1:-}" in
  set-default)
    [ $# -ge 2 ] || usage
    exec wpctl set-default "$2" ;;
  mute-output) exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  mute-input)  exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
  chain)
    case "${2:-}" in
      "") cat "$MIC_FILE" 2>/dev/null || true ;;
      set)
        [ $# -eq 3 ] || usage
        mkdir -p "$(dirname "$MIC_FILE")"
        printf '%s' "$3" > "$MIC_FILE"
        chain_apply ;;
      apply) chain_apply ;;
      *) usage ;;
    esac ;;
  *) usage ;;
esac
