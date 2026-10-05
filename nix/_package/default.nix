# shell/ with a generated Host.qml, run from the store as `nyx-shell`.
{ pkgs, lib, helpers, hyprland, outputs, terminal, iconTheme }:
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

      readonly property string power: "${exe helpers.power}"
      readonly property string screenshot: "${exe helpers.screenshot}"
      readonly property string colorpicker: "${exe helpers.colorpicker}"
      readonly property string audio: "${exe helpers.audio}"
      readonly property string monitors: "${exe helpers.monitors}"
      readonly property string clipboard: "${exe helpers.clipboard}"
      readonly property string wallpaper: "${exe helpers.wallpaper}"
      readonly property string calendar: "${exe helpers.calendar}"
      readonly property string calc: "${exe helpers.calc}"
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
pkgs.writeShellApplication {
  name = "nyx-shell";
  # qt6ct for Qt styling; icons come from QS_ICON_THEME.
  runtimeEnv = {
    QT_QPA_PLATFORMTHEME = "qt6ct";
    QS_ICON_THEME = iconTheme;
  };
  text = ''exec ${exe pkgs.quickshell} -p ${src} "$@"'';
}
