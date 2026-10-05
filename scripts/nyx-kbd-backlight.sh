case "${1:-}" in
  up|down|cycle|toggle|status) ;;
  *)
    echo "usage: nyx-kbd-backlight {up|down|cycle|toggle|status}" >&2
    exit 2 ;;
esac

# The LED name is vendor specific and desktops have none.
led=""
for d in /sys/class/leds/*kbd_backlight*; do
  [ -e "$d" ] || continue
  led=${d##*/}
  break
done
[ -n "$led" ] || exit 0

cur() { cat "/sys/class/leds/$led/brightness"; }
max() { cat "/sys/class/leds/$led/max_brightness"; }
set_level() { brightnessctl -q -c leds -d "$led" set "$1"; }

case "$1" in
  up)     set_level +1 ;;
  down)   set_level 1- ;;
  cycle)  set_level $(( ($(cur) + 1) % ($(max) + 1) )) ;;
  toggle) if [ "$(cur)" -gt 0 ]; then set_level 0; else set_level 100%; fi ;;
  status) echo "$(cur) $(max)"; exit 0 ;;
esac

# sysfs has no change events; tell the OSD to re-read.
hyprctl dispatch 'hl.dsp.global("nyx:kbdBacklightChanged")' >/dev/null 2>&1 || true
