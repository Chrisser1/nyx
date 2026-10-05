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
      clipboardMaxItems = 500;
    };

    # Runs tests/<name>/shell.qml headless against a copy of shell/; it prints PASS.
    qmlTest = name: { inputs ? [ ], setup ? "" }:
      pkgs.runCommand "nyx-${name}-test" { nativeBuildInputs = [ pkgs.quickshell ] ++ inputs; } ''
        export HOME=$PWD/home XDG_CACHE_HOME=$PWD/cache XDG_STATE_HOME=$PWD/state
        export XDG_RUNTIME_DIR=$PWD QT_QPA_PLATFORM=offscreen
        mkdir -p $HOME $XDG_STATE_HOME/nyx
        cp -r ${../shell} cfg && chmod -R u+w cfg
        cp ${../tests/${name}/shell.qml} cfg/shell.qml
        ${setup}
        timeout 60 quickshell -p cfg 2>&1 | tee log
        grep -q PASS log
        touch $out
      '';
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

      colors = qmlTest "colors" { };

      clipboard-panel = qmlTest "clipboard" {
        inputs = [ helpers.clipboard pkgs.imagemagick ];
        setup = ''
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-clipboard"' '"${lib.getExe helpers.clipboard}"'
          printf 'Some notes\nsecond line\nthird' | nyx-clipboard store
          printf '#b8bb26' | nyx-clipboard store
          printf 'https://example.com' | nyx-clipboard store
          magick -size 1362x766 gradient:red-blue image.png
          nyx-clipboard store < image.png
        '';
      };

      clipboard = pkgs.runCommand "nyx-clipboard-test" {
        nativeBuildInputs = [ helpers.clipboard pkgs.imagemagick pkgs.jq ];
      } ''
        bash ${./_helpers/clipboard-test.sh}
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
