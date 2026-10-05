case "${1:-}" in
  up)     brightnessctl -q -c backlight set 5%+ ;;
  # -n keeps the panel from going fully black.
  down)   brightnessctl -q -c backlight -n set 5%- ;;
  status) exec brightnessctl -c backlight -m info ;;
  *)
    echo "usage: nyx-brightness {up|down|status}" >&2
    exit 2 ;;
esac

# sysfs has no change events; tell the OSD to re-read.
hyprctl dispatch 'hl.dsp.global("nyx:brightnessChanged")' >/dev/null 2>&1 || true
