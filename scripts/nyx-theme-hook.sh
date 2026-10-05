# Reloads an app after matugen renders its theme.
usage() { echo "usage: nyx-theme-hook {kitty|hyprland <file>|gtk <mode>|qt|btop}" >&2; exit 2; }

case "${1:-}" in
  kitty) pkill -USR1 '^\.?kitty' || true ;;
  hyprland)
    [ $# -ge 2 ] || usage
    hyprctl eval "dofile(\"$2\")" >/dev/null 2>&1 || true ;;
  gtk)
    [ $# -ge 2 ] || usage
    theme=adw-gtk3
    if [ "$2" = dark ]; then theme=adw-gtk3-dark; fi
    # dconf, not gsettings: it needs no compiled schemas.
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-$2'" 2>/dev/null || true
    dconf write /org/gnome/desktop/interface/gtk-theme "'$theme'" 2>/dev/null || true ;;
  qt)
    # qt6ct reads the scheme from its own config, so point that at ours.
    conf="${XDG_CONFIG_HOME:-$HOME/.config}/qt6ct/qt6ct.conf"
    scheme="$(dirname "$conf")/colors/nyx.conf"
    mkdir -p "$(dirname "$conf")"
    [ -f "$conf" ] || printf '[Appearance]\n' > "$conf"
    sed -i -e "s|^color_scheme_path=.*|color_scheme_path=$scheme|" -e 's|^custom_palette=.*|custom_palette=true|' "$conf"
    grep -q '^color_scheme_path=' "$conf" || sed -i "/^\[Appearance\]/a color_scheme_path=$scheme\ncustom_palette=true" "$conf" ;;
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
