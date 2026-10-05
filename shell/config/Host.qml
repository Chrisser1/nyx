// Host-specific values: monitor roles and the helper binaries the shell shells
// out to.
//
// This checked-in copy uses bare binary names so `qs -p shell` works straight
// from `nix develop`. The home-manager module overwrites it with a generated copy
// that pins absolute store paths and the configured outputs -- see nix/package.nix.

pragma Singleton
import Quickshell

Singleton {
  id: root

  // Outputs, by role. Empty string = this host has no monitor in that role.
  readonly property string primary: ""
  readonly property string left: ""
  readonly property string right: ""

  readonly property string terminal: "kitty"

  // Helper binaries. Nix replaces each with an absolute store path.
  readonly property string power: "nyx-power"
  readonly property string screenshot: "nyx-screenshot"
  readonly property string colorpicker: "nyx-colorpicker"
  readonly property string audio: "nyx-audio"
  readonly property string monitors: "nyx-monitors"
  readonly property string clipboard: "nyx-clipboard"
  readonly property string wallpaper: "nyx-wallpaper"
  readonly property string theme: "nyx-theme"
  readonly property string calendar: "nyx-calendar"
  readonly property string calc: "nyx-calc"
  readonly property string emoji: "nyx-emoji"
  readonly property string docker: "nyx-docker"
  readonly property string tailnet: "nyx-tailnet"
  readonly property string brightnessctl: "brightnessctl"
  readonly property string kbdBacklight: "nyx-kbd-backlight"
  readonly property string sysmon: "btop"
  readonly property string cava: "cava"
  readonly property string hyprctl: "hyprctl"
  readonly property string hcitool: "hcitool"
}
