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
    monitorsStubbed = stubbed "monitors" [ (stub "hyprctl") (stub "notify-send") pkgs.jq pkgs.coreutils ] { };
    calendarStubbed = stubbed "calendar" [ (stub "nyx-calendar-backend") (stub "evolution") ] { };
    # The default keybinds as Lua and as the shell's JSON.
    keybindsRendered =
      let
        kb = import ./_keybinds { inherit lib; };
        binds = map (b: { shortcut = null; command = null; release = false; nonConsuming = false; locked = false; repeating = false; hidden = false; } // b) kb.defaults;
        args = { modifier = "SUPER"; inherit binds; };
      in {
        inherit binds;
        lua = pkgs.writeText "keybinds.lua" (kb.lua args);
        json = pkgs.writeText "keybinds.json" (kb.json args);
      };
    # Prints one frame every 100 ms, like cava with four raw ascii bars.
    fakeCava = pkgs.writeShellScript "fake-cava" "while :; do echo \"0;50;100;20\"; sleep 0.1; done";
    bitwardenStubbed = stubbed "bitwarden" (map stub [ "rbw" "wl-copy" "wl-paste" "notify-send" "wtype" ] ++ [ pkgs.jq pkgs.coreutils pkgs.findutils pkgs.gnugrep ]) { NYX_BITWARDEN_CLEAR = "1"; NYX_BITWARDEN_PINENTRY = "/stub/pinentry"; NYX_BITWARDEN_TYPE_DELAY = "0"; };

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

      display-launcher = qmlTest "displays" {
        setup = ''
          export STUB_DIR=$PWD/stub
          mkdir -p $STUB_DIR
          cp --no-preserve=mode ${../tests/displays/monitors.json} $STUB_DIR/monitors.json
          cp --no-preserve=mode ${../tests/displays/mirrored.json} $STUB_DIR/mirrored.json
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-monitors"' '"${lib.getExe monitorsStubbed}"'
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
          mkdir -p $STUB_DIR/secrets
          printf hunter2 > $STUB_DIR/secrets/u1.password
          printf chris > $STUB_DIR/secrets/u1.username
          mkdir -p $STUB_DIR/cfg
          echo me@example.com > $STUB_DIR/cfg/email
          export XDG_DATA_HOME=$HOME/.local/share
          mkdir -p $HOME/.local/share/rbw
          touch "$XDG_DATA_HOME/rbw/me@example.com.json"
          touch $STUB_DIR/unlocked
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-bitwarden"' '"${lib.getExe bitwardenStubbed}"'
        '';
      };


      audio-panel = qmlTest "audiopanel" { };
      audio-visual = qmlTest "audio" {
        setup = ''
          substituteInPlace cfg/config/Host.qml --replace-fail '"cava"' '"${fakeCava}"'
        '';
      };

      calendar-panel = qmlTest "calendar" {
        setup = ''
          export STUB_DIR=$PWD/stub
          mkdir -p $STUB_DIR
          touch $STUB_DIR/no-calendar
          substituteInPlace cfg/config/Host.qml --replace-fail '"nyx-calendar"' '"${lib.getExe calendarStubbed}"'
        '';
      };

      calendar = pkgs.runCommand "nyx-calendar-test" {
        nativeBuildInputs = [ calendarStubbed ];
      } ''
        bash ${./_helpers/calendar-test.sh}
        touch $out
      '';

      # Builds the CalDAV source for real, against Evolution Data Server's
      # typelibs; committing it needs a running server, so that is not covered.
      calendar-backend = pkgs.runCommand "nyx-calendar-backend-test" {
        nativeBuildInputs = [ helpers.calendarBackend ];
      } ''
        cfg=$(nyx-calendar-backend caldav-config Work https://cloud.example.org:8443/remote.php/dav/calendars/me/personal/ me)
        for want in 'DisplayName=Work' 'BackendName=caldav' 'Host=cloud.example.org' 'Port=8443' 'User=me' \
                    'Method=tls' 'ResourcePath=/remote.php/dav/calendars/me/personal/'; do
          grep -qxF "$want" <<< "$cfg" || { echo "FAIL: missing $want in:"; echo "$cfg"; exit 1; }
        done
        plain=$(nyx-calendar-backend caldav-config Home http://nas.lan/dav/ me)
        grep -qxF 'Port=80' <<< "$plain" || { echo "FAIL: default http port"; exit 1; }
        grep -qxF 'Method=none' <<< "$plain" || { echo "FAIL: plain http is not secured"; exit 1; }
        if nyx-calendar-backend caldav-config Bad ftp://nas/dav me 2>/dev/null; then echo "FAIL: ftp accepted"; exit 1; fi
        if nyx-calendar-backend caldav-config Bad nas/dav me 2>/dev/null; then echo "FAIL: schemeless address accepted"; exit 1; fi
        touch $out
      '';

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

      # The keybind list renders valid Lua with one bind each, and the shell's
      # JSON leaves out the hidden ones.
      keybinds = pkgs.runCommand "nyx-keybinds-test" { nativeBuildInputs = [ pkgs.lua pkgs.jq ]; } ''
          luac -p ${keybindsRendered.lua}
          [ "$(grep -c '^hl.bind(' ${keybindsRendered.lua})" = ${toString (builtins.length keybindsRendered.binds)} ] || { echo "FAIL: one hl.bind per entry"; exit 1; }
          grep -qF 'hl.bind("ALT + ALT_L", nyx("windowSwitcherCommit"), { release = true, non_consuming = true })' ${keybindsRendered.lua} || { echo "FAIL: release bind"; exit 1; }
          grep -qF 'hl.bind("SUPER + SHIFT + S", hl.dsp.exec_cmd("nyx-screenshot region"))' ${keybindsRendered.lua} || { echo "FAIL: command bind"; exit 1; }
          [ "$(jq length ${keybindsRendered.json})" = ${toString (builtins.length (builtins.filter (b: !b.hidden) keybindsRendered.binds))} ] || { echo "FAIL: hidden binds listed"; exit 1; }
          jq -e 'all(.[]; (.keys | type == "string") and (.label | length > 0))' ${keybindsRendered.json} > /dev/null || { echo "FAIL: entries need keys and a label"; exit 1; }
          jq -e 'any(.[]; .keys == "SUPER + T" and .label == "System panel")' ${keybindsRendered.json} > /dev/null || { echo "FAIL: system panel entry"; exit 1; }
          touch $out
        '';

      keybinds-panel = qmlTest "keybinds" {
        setup = ''
          mkdir -p $HOME/.config/nyx
          cp ${keybindsRendered.json} $HOME/.config/nyx/keybinds.json
        '';
      };

      monitors = pkgs.runCommand "nyx-monitors-test" {
        nativeBuildInputs = [ monitorsStubbed pkgs.jq ];
      } ''
        bash ${./_helpers/monitors-test.sh}
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
