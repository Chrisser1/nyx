{ inputs, ... }: {
  perSystem = { pkgs, lib, system, config, nyx, ... }:
  let
    wallpapers = pkgs.runCommand "nyx-test-wallpapers" { } ''
      mkdir -p $out/a $out/b
      touch $out/a/still.png $out/b/clip.mp4 $out/b/notes.txt
    '';

    helpers = import ./_helpers {
      inherit pkgs lib;
      inherit (nyx.theming) theme;
      gslapper = inputs.gslapper.packages.${system}.gslapper;
      hyprland = pkgs.hyprland;
      lockCommand = "true";
      wallpaperDir = "${wallpapers}";
      defaultWallpaper = "";
      screenshotDir = "/tmp";
    };
  in {
    checks = {
      shell = config.packages.default;

      helpers = pkgs.runCommand "nyx-helpers-test" {
        nativeBuildInputs = helpers.all;
        NYX_WALLPAPER_DIR = "${wallpapers}";
      } ''
        bash ${./_helpers/test.sh}
        touch $out
      '';

      colors = pkgs.runCommand "nyx-colors-test" { nativeBuildInputs = [ pkgs.quickshell ]; } ''
        cp -r ${../tests/colors} cfg && chmod -R u+w cfg
        mkdir -p cfg/config state/nyx
        cp ${../shell/config/Colors.qml} cfg/config/Colors.qml
        export HOME=$PWD XDG_STATE_HOME=$PWD/state XDG_RUNTIME_DIR=$PWD QT_QPA_PLATFORM=offscreen
        timeout 30 quickshell -p cfg 2>&1 | tee log
        grep -q PASS log
        touch $out
      '';

      theme = pkgs.runCommand "nyx-theme-test" {
        nativeBuildInputs = [ nyx.theming.theme nyx.theming.hook ] ++ (with pkgs; [ jq yq-go lua5_4 imagemagick ffmpeg-headless procps ]);
        SCHEMES = "${pkgs.base16-schemes}/share/themes";
        BASE16_JQ = "${../theme/base16.jq}";
      } ''
        bash ${./_theme/test.sh}
        touch $out
      '';
    };
  };
}
