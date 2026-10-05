# Helper binaries the shell calls; sources live in scripts/.
{ pkgs, lib, gslapper, hyprland, theme, lockCommand, wallpaperDir, defaultWallpaper, screenshotDir, clipboardMaxItems }:
let
  script = import ./script.nix { inherit pkgs; };

  # Disables qalc's mixed-unit output ("3 mi + 188 yd + ...").
  qalcConfig = pkgs.writeTextDir "qalculate/qalc.cfg" ''
    mixed_units_conversion=0
    update_exchange_rates=0
  '';

  calendarBackend =
    let
      # libxml2's typelib ships in gobject-introspection.
      giPackages = with pkgs; [ evolution-data-server libical libsoup_3 json-glib glib gobject-introspection ];
      python = pkgs.python3.withPackages (ps: [ ps.pygobject3 ps.parsedatetime ]);
    in pkgs.runCommand "nyx-calendar-backend" { nativeBuildInputs = [ pkgs.makeWrapper ]; } ''
      install -Dm755 ${../../scripts/nyx-calendar-backend.py} $out/bin/nyx-calendar-backend
      substituteInPlace $out/bin/nyx-calendar-backend \
        --replace-fail '#!/usr/bin/env python3' '#!${python}/bin/python3'
      wrapProgram $out/bin/nyx-calendar-backend \
        --prefix GI_TYPELIB_PATH : "${lib.makeSearchPath "lib/girepository-1.0" giPackages}" \
        --prefix LD_LIBRARY_PATH : "${lib.makeLibraryPath giPackages}"
    '';
in rec {
  power = script "power" [ pkgs.systemd hyprland ] { NYX_LOCK_COMMAND = lockCommand; };
  screenshot = script "screenshot" (with pkgs; [ grim slurp satty jq wl-clipboard hyprland ]) { NYX_SCREENSHOT_DIR = screenshotDir; };
  colorpicker = script "colorpicker" (with pkgs; [ hyprpicker libnotify ]) { };
  audio = script "audio" [ pkgs.wireplumber ] { };
  kbdBacklight = script "kbd-backlight" [ pkgs.brightnessctl hyprland ] { };
  brightness = script "brightness" [ pkgs.brightnessctl hyprland ] { };
  clipboard = script "clipboard" (with pkgs; [ cliphist wl-clipboard jq gawk gnugrep coreutils findutils ]) { NYX_CLIPBOARD_MAX_ITEMS = toString clipboardMaxItems; };
  calc = script "calc" (with pkgs; [ libqalculate wl-clipboard ]) { NYX_QALC_CONFIG = "${qalcConfig}"; };
  calendar = script "calendar" (with pkgs; [ calendarBackend evolution gnome-calendar ]) { };
  monitors = script "monitors" (with pkgs; [ jq libnotify wdisplays hyprland ]) { };
  wallpaper = script "wallpaper" (with pkgs; [ jq procps findutils coreutils ffmpeg-headless gslapper hyprland theme ]) {
    NYX_WALLPAPER_DIR = wallpaperDir;
    NYX_WALLPAPER_DEFAULT = defaultWallpaper;
  };

  all = [ power screenshot colorpicker audio kbdBacklight brightness clipboard calc calendar monitors wallpaper ];
}
