case "${1:-}" in
  set-default)
    [ $# -ge 2 ] || { echo "usage: nyx-audio set-default <node-id>" >&2; exit 2; }
    exec wpctl set-default "$2" ;;
  mute-output) exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle ;;
  mute-input)  exec wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle ;;
  *)
    echo "usage: nyx-audio {set-default <node-id>|mute-output|mute-input}" >&2
    exit 2 ;;
esac
