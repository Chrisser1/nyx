# shell/ with a generated Host.qml, run from the store as `nyx-shell`.
{ pkgs, lib, helpers, theme, hyprland, outputs, terminal, iconTheme, trayHidden ? [ ] }:
let
  exe = lib.getExe;

  hostQml = pkgs.writeText "Host.qml" ''
    pragma Singleton
    import Quickshell

    Singleton {
      readonly property string primary: "${outputs.primary}"
      readonly property string left: "${outputs.left}"
      readonly property string right: "${outputs.right}"

      readonly property string terminal: "${terminal}"

      readonly property var trayHidden: ${builtins.toJSON (map lib.toLower trayHidden)}

      readonly property string power: "${exe helpers.power}"
      readonly property string screenshot: "${exe helpers.screenshot}"
      readonly property string colorpicker: "${exe helpers.colorpicker}"
      readonly property string audio: "${exe helpers.audio}"
      readonly property string monitors: "${exe helpers.monitors}"
      readonly property string clipboard: "${exe helpers.clipboard}"
      readonly property string wallpaper: "${exe helpers.wallpaper}"
      readonly property string theme: "${exe theme}"
      readonly property string calendar: "${exe helpers.calendar}"
      readonly property string calc: "${exe helpers.calc}"
      readonly property string emoji: "${exe helpers.emoji}"
      readonly property string docker: "${exe helpers.docker}"
      readonly property string tailnet: "${exe helpers.tailnet}"
      readonly property string lyrics: "${exe helpers.lyrics}"
      readonly property string bitwarden: "${exe helpers.bitwarden}"
      readonly property string brightnessctl: "${exe pkgs.brightnessctl}"
      readonly property string kbdBacklight: "${exe helpers.kbdBacklight}"
      readonly property string sysmon: "${exe pkgs.btop}"
      readonly property string cava: "${exe pkgs.cava}"
      readonly property string hyprctl: "${hyprland}/bin/hyprctl"
      readonly property string hcitool: "${pkgs.bluez}/bin/hcitool"
    }
  '';

  src = pkgs.runCommand "nyx-shell-src" { } ''
    cp -r ${../../shell} $out
    chmod -R u+w $out
    cp ${hostQml} $out/config/Host.qml

    # Untracked files are invisible to flakes; fail instead of shipping a broken shell.
    missing=0
    for mod in $(grep -rhoE '^import qs\.[A-Za-z0-9_.]+' $out --include='*.qml' | sed 's/^import qs\.//' | sort -u); do
      if [ ! -d "$out/$(echo "$mod" | tr . /)" ]; then
        echo "nyx-shell: unresolvable QML import qs.$mod (git add?)" >&2
        missing=1
      fi
    done
    [ $missing -eq 0 ]
  '';
in
let
  shell = pkgs.writeShellApplication {
    name = "nyx-shell";
    runtimeInputs = [ pkgs.jq ];
    # qt6ct for Qt styling; icons come from QS_ICON_THEME.
    runtimeEnv = {
      QT_QPA_PLATFORMTHEME = "qt6ct";
      QS_ICON_THEME = iconTheme;
    };
    text = ''
      # `restart` stops the running shell (whichever build it is, so it works
      # right after a rebuild), then starts this one detached.
      if [ "''${1:-}" = restart ]; then
        for pid in $(${exe pkgs.quickshell} list --all --json | jq -r '.[] | select(.config_path | test("nyx-shell-src")) | .pid'); do
          ${exe pkgs.quickshell} kill --pid "$pid" || true
        done
        # Let the old shell release the notification service.
        sleep 1
        exec ${exe pkgs.quickshell} -p ${src} -d
      fi
      exec ${exe pkgs.quickshell} -p ${src} "$@"
    '';
  };
in
pkgs.symlinkJoin {
  name = "nyx-shell";
  paths = [ shell (pkgs.writeShellScriptBin "nyx-restart" ''exec ${lib.getExe shell} restart'') ];
  meta.mainProgram = "nyx-shell";
}
