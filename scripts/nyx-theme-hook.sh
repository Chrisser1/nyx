# Reloads an app after matugen renders its theme.
usage() { echo "usage: nyx-theme-hook {kitty|hyprland <file>|gtk <mode>|btop}" >&2; exit 2; }

case "${1:-}" in
  kitty) pkill -USR1 '^\.?kitty' || true ;;
  hyprland)
    [ $# -ge 2 ] || usage
    hyprctl eval "dofile(\"$2\")" >/dev/null 2>&1 || true ;;
  gtk)
    [ $# -ge 2 ] || usage
    theme=adw-gtk3
    if [ "$2" = dark ]; then theme=adw-gtk3-dark; fi
    gsettings set org.gnome.desktop.interface color-scheme "prefer-$2" 2>/dev/null || true
    gsettings set org.gnome.desktop.interface gtk-theme "$theme" 2>/dev/null || true ;;
  btop)
    conf="${XDG_CONFIG_HOME:-$HOME/.config}/btop/btop.conf"
    if [ -f "$conf" ] && grep -q '^color_theme' "$conf"; then
      sed -i 's|^color_theme = .*|color_theme = "nyx"|' "$conf"
    else
      mkdir -p "$(dirname "$conf")"
      echo 'color_theme = "nyx"' >> "$conf"
    fi ;;
  *) usage ;;
esac
