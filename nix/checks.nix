{ inputs, ... }: {
  perSystem = { pkgs, lib, system, config, nyx, ... }:
  let
    wallpapers = pkgs.runCommand "nyx-test-wallpapers" { nativeBuildInputs = [ pkgs.imagemagick pkgs.ffmpeg-headless ]; } ''
      mkdir -p $out/a $out/b
      magick -size 64x36 xc:'#b8bb26' $out/a/still.png
      ffmpeg -loglevel error -f lavfi -i testsrc=duration=2:size=64x36:rate=10 -pix_fmt yuv420p $out/b/clip.mp4
      touch $out/b/notes.txt
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
      emojiType = false;
      bitwardenClear = 30;
    };

    # A helper built against fakes in _helpers/stubs instead of the real CLIs.
    stub = name: pkgs.writeShellScriptBin name (builtins.readFile ./_helpers/stubs/${name}.sh);
    stubbed = name: runtimeInputs: env: import ./_helpers/script.nix { inherit pkgs; } name runtimeInputs env;
    dockerStubbed = stubbed "docker" [ (stub "docker") pkgs.jq ] { };
    tailnetStubbed = stubbed "tailnet" [ (stub "tailscale") pkgs.jq ] { };
    bitwardenStubbed = stubbed "bitwarden" (map stub [ "rbw" "wl-copy" "wl-paste" "notify-send" ] ++ [ pkgs.jq pkgs.coreutils pkgs.findutils pkgs.gnugrep ]) { NYX_BITWARDEN_CLEAR = "1"; };

    # Runs tests/<name>/shell.qml headless against a copy of shell/; it prints PASS.
    qmlTest = name: { inputs ? [ ], setup ? "" }:
      pkgs.runCommand "nyx-${name}-qml-test" { nativeBuildInputs = [ pkgs.quickshell ] ++ inputs; } ''
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
        nativeBuildInputs = helpers.all ++ [ pkgs.jq ];
        NYX_WALLPAPER_DIR = "${wallpapers}";
      } ''
        bash ${./_helpers/test.sh}
        touch $out
      '';

      colors = qmlTest "colors" { };

      switcher = qmlTest "switcher" { };

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

      launcher = qmlTest "launcher" {
        setup = ''
          substituteInPlace cfg/config/Host.qml \
            --replace-fail '"nyx-theme"' '"${lib.getExe nyx.theming.theme}"' \
            --replace-fail '"nyx-wallpaper"' '"${lib.getExe helpers.wallpaper}"' \
            --replace-fail '"nyx-emoji"' '"${lib.getExe helpers.emoji}"'
        '';
      };

      docker-panel = qmlTest "docker" {
        setup = ''
          export STUB_DIR=$PWD/stub
          mkdir -p $STUB_DIR
          cp ${../tests/docker/ps.json} $STUB_DIR/ps.json
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-docker"' '"${lib.getExe dockerStubbed}"'
        '';
      };

      tailnet-panel = qmlTest "tailnet" {
        setup = ''
          export STUB_DIR=$PWD/stub
          mkdir -p $STUB_DIR
          cp --no-preserve=mode ${../tests/tailnet/status.json} $STUB_DIR/status.json
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-tailnet"' '"${lib.getExe tailnetStubbed}"'
        '';
      };

      bitwarden-launcher = qmlTest "bitwarden" {
        setup = ''
          export STUB_DIR=$PWD/stub
          mkdir -p $STUB_DIR
          cp --no-preserve=mode ${../tests/bitwarden/list.json} $STUB_DIR/list.json
          echo me@example.com > $STUB_DIR/email
          mkdir -p $HOME/.local/share/rbw
          touch "$HOME/.local/share/rbw/api.bitwarden.com:me@example.com.json"
          touch $STUB_DIR/unlocked
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-bitwarden"' '"${lib.getExe bitwardenStubbed}"'
        '';
      };

      clipboard = pkgs.runCommand "nyx-clipboard-test" {
        nativeBuildInputs = [ helpers.clipboard pkgs.imagemagick pkgs.jq ];
      } ''
        bash ${./_helpers/clipboard-test.sh}
        touch $out
      '';

      docker = pkgs.runCommand "nyx-docker-test" {
        nativeBuildInputs = [ dockerStubbed pkgs.jq ];
      } ''
        bash ${./_helpers/docker-test.sh}
        touch $out
      '';

      tailnet = pkgs.runCommand "nyx-tailnet-test" {
        nativeBuildInputs = [ tailnetStubbed pkgs.jq ];
        STATUS_JSON = "${../tests/tailnet/status.json}";
      } ''
        bash ${./_helpers/tailnet-test.sh}
        touch $out
      '';

      bitwarden = pkgs.runCommand "nyx-bitwarden-test" {
        nativeBuildInputs = [ bitwardenStubbed pkgs.jq (stub "wl-copy") (stub "rbw") ];
      } ''
        bash ${./_helpers/bitwarden-test.sh}
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
