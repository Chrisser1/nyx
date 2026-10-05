mkdir -p "$NYX_SCREENSHOT_DIR"

case "${1:-region}" in
  region)
    geom=$(slurp) || exit 0
    capture=(grim -g "$geom" -) ;;
  output)
    mon=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name')
    capture=(grim -o "$mon" -) ;;
  *)
    echo "usage: nyx-screenshot {region|output}" >&2
    exit 2 ;;
esac

"${capture[@]}" | satty --filename - \
  --output-filename "$NYX_SCREENSHOT_DIR/screenshot_%Y%m%d_%H%M%S.png" \
  --copy-command wl-copy --early-exit
