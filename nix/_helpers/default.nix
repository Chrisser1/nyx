# Helper binaries the shell calls; sources live in scripts/.
{ pkgs, lib, gslapper, hyprland, theme, lockCommand, wallpaperDir, defaultWallpaper, screenshotDir, clipboardMaxItems, emojiType, bitwardenClear }:
let
  script = import ./script.nix { inherit pkgs; };

  # pinentry-qt is Qt6, so it needs the qt6ct platform theme to pick up the
  # colours nyx-theme writes.
  pinentry = pkgs.symlinkJoin {
    name = "nyx-pinentry";
    paths = [ pkgs.pinentry-qt ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/pinentry \
        --set QT_QPA_PLATFORMTHEME qt6ct \
        --prefix QT_PLUGIN_PATH : ${pkgs.kdePackages.qt6ct}/lib/qt-6/plugins
    '';
  };

  # Disables qalc's mixed-unit output ("3 mi + 188 yd + ...").
  qalcConfig = pkgs.writeTextDir "qalculate/qalc.cfg" ''
    mixed_units_conversion=0
    update_exchange_rates=0
  '';

  emojiData = pkgs.runCommand "nyx-emoji-data" { nativeBuildInputs = [ pkgs.python3 ]; } ''
    python3 ${./emoji-data.py} \
      ${pkgs.unicode-emoji}/share/unicode/emoji/emoji-test.txt \
      ${pkgs.cldr-annotations}/share/unicode/cldr/common/annotations/en.xml \
      ${pkgs.cldr-annotations}/share/unicode/cldr/common/annotationsDerived/en.xml \
      $out
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
  inherit calendarBackend;
  power = script "power" [ pkgs.systemd hyprland ] { NYX_LOCK_COMMAND = lockCommand; };
  screenshot = script "screenshot" (with pkgs; [ grim slurp satty jq wl-clipboard hyprland ]) { NYX_SCREENSHOT_DIR = screenshotDir; };
  colorpicker = script "colorpicker" (with pkgs; [ hyprpicker libnotify ]) { };
  audio = script "audio" [ pkgs.wireplumber ] { };
  kbdBacklight = script "kbd-backlight" [ pkgs.brightnessctl hyprland ] { };
  brightness = script "brightness" [ pkgs.brightnessctl hyprland ] { };
  clipboard = script "clipboard" (with pkgs; [ cliphist wl-clipboard jq gawk gnugrep coreutils findutils diffutils ]) { NYX_CLIPBOARD_MAX_ITEMS = toString clipboardMaxItems; };
  calc = script "calc" (with pkgs; [ libqalculate wl-clipboard ]) { NYX_QALC_CONFIG = "${qalcConfig}"; };
  calendar = script "calendar" (with pkgs; [ calendarBackend evolution gnome-calendar ]) { };
  monitors = script "monitors" (with pkgs; [ jq libnotify wdisplays hyprland ]) { };
  emoji = script "emoji" (with pkgs; [ jq gnugrep gawk coreutils wl-clipboard wtype ]) {
    NYX_EMOJI_DATA = "${emojiData}";
    NYX_EMOJI_TYPE = if emojiType then "1" else "0";
  };
  docker = script "docker" [ pkgs.docker-client pkgs.jq ] { };
  tailnet = script "tailnet" [ pkgs.tailscale pkgs.jq ] { };
  bitwarden = script "bitwarden" (with pkgs; [ rbw jq wl-clipboard wtype libnotify coreutils findutils gnugrep ]) {
    NYX_BITWARDEN_CLEAR = toString bitwardenClear;
    NYX_BITWARDEN_TYPE_DELAY = "0.25";
    NYX_BITWARDEN_PINENTRY = "${pinentry}/bin/pinentry";
  };
  wallpaper = script "wallpaper" (with pkgs; [ jq procps findutils coreutils ffmpeg-headless gslapper hyprland theme ]) {
    NYX_WALLPAPER_DIR = wallpaperDir;
    NYX_WALLPAPER_DEFAULT = defaultWallpaper;
  };

  all = [ power screenshot colorpicker audio kbdBacklight brightness clipboard calc calendar monitors wallpaper emoji docker tailnet bitwarden ];
}
