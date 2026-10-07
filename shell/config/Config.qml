// Adapted from roosta/dotfiles (.config/quickshell/config/Config.qml, GPLv3).
// Host-specific values moved out to Host.qml; roosta's ~/scripts entries replaced
// with the helper binaries built in nix/_helpers/.

pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import qs.config
import QtQuick
import Quickshell.Hyprland
import Quickshell.Services.Pipewire

Singleton {
  id: root

  // Global UI scale factor.
  property real scale: 1.0

  // Default apps
  readonly property string terminal: Host.terminal
  readonly property string shell: "fish"
  readonly property string menuPrefix: "/"

  // Available displays, by role. Roles this host doesn't have are "".
  component Displays: QtObject {
    readonly property string left: Host.left
    readonly property string right: Host.right
    readonly property string center: root.primaryDisplay
  }
  readonly property Displays displays: Displays { }

  // Primary display: the configured one, or else whichever output has focus --
  // a docking laptop has no fixed "primary", so toasts follow the user instead.
  readonly property string primaryDisplay: Host.primary || (Hyprland.focusedMonitor?.name ?? "")

  // default menu mode
  readonly property string defaultMode: "apps"

  // Menu modes, defaults to apps
  readonly property var launcherMenus: [
    {
      id: "nyx-mode-apps",
      name: "Applications",
      comment: "Browse and launch desktop applications",
      mode: "apps",
      genericName: "Menu",
      categories: ["AppLauncher"],
      iconId: "applications-all"
    },
    {
      id: "nyx-mode-utils",
      name: "Utilities",
      comment: "Screenshots, colour picking and system monitoring",
      mode: "utils",
      genericName: "Menu",
      categories: ["Utility", "FileTools"],
      iconId: "applications-utilities"
    },
    {
      id: "nyx-mode-calc",
      name: "Calculator",
      comment: "Evaluate maths, unit and currency conversions",
      mode: "calc",
      genericName: "Menu",
      categories: ["Calculator", "Utility"],
      iconId: "accessories-calculator"
    },
    {
      id: "nyx-mode-audio",
      name: "Audio",
      comment: "Switch the default audio output",
      mode: "audio",
      genericName: "Menu",
      categories: ["Audio", "Configuration"],
      iconId: "audio-x-generic"
    },
    {
      id: "nyx-mode-display",
      name: "Display",
      comment: "Arrange monitors and toggle mirroring",
      mode: "display",
      genericName: "Menu",
      categories: ["Display", "Configuration"],
      iconId: "preferences-desktop-display"
    },
    {
      id: "nyx-mode-wallpaper",
      name: "Wallpaper",
      comment: "Set the wallpaper on every monitor, still or animated",
      mode: "wallpaper",
      genericName: "Menu",
      categories: ["Wallpaper", "Configuration"],
      iconId: "preferences-desktop-wallpaper"
    },
    {
      id: "nyx-mode-theme",
      name: "Theme",
      comment: "Pick a colour scheme, or follow the wallpaper",
      mode: "theme",
      genericName: "Menu",
      categories: ["Appearance", "Configuration"],
      iconId: "preferences-desktop-theme"
    },
    {
      id: "nyx-mode-tailnet",
      name: "Tailscale",
      comment: "Peers, exit nodes and the connection",
      panel: "tailnet",
      genericName: "Menu",
      categories: ["Network", "Utility"],
      iconId: "preferences-system-network"
    },
    {
      id: "nyx-mode-bitwarden",
      name: "Bitwarden",
      comment: "Copy or type passwords, usernames and TOTP codes from the vault",
      panel: "bitwarden",
      genericName: "Menu",
      categories: ["Security", "Utility"],
      iconId: "bitwarden"
    },
    {
      id: "nyx-mode-emoji",
      name: "Emoji",
      comment: "Search emoji and copy one to the clipboard",
      mode: "emoji",
      genericName: "Menu",
      categories: ["Utility", "Text"],
      iconId: "accessories-character-map"
    },
    {
      id: "nyx-mode-power",
      name: "Power",
      comment: "Power options for system (shutdown, restart, logout etc)",
      mode: "power",
      genericName: "Menu",
      categories: ["System", "Power"],
      iconId: "preferences-system"
    },
    {
      id: "nyx-mode-notifications",
      name: "Notifications",
      comment: "Notification control menu",
      mode: "notifications",
      genericName: "Menu",
      categories: ["System"],
      iconId: "notifications"
    }
  ]

  readonly property var powerScripts: [
    {
      id: "nyx-power-shutdown",
      name: "Shutdown",
      comment: "Power down system",
      genericName: "Power",
      categories: ["System", "Shutdown"],
      script: [Host.power, "shutdown"],
      iconId: "system-shutdown"
    },
    {
      id: "nyx-power-reboot",
      name: "Reboot",
      comment: "Restart system",
      genericName: "Power",
      categories: ["System", "Restart"],
      script: [Host.power, "reboot"],
      iconId: "system-reboot"
    },
    {
      id: "nyx-power-logout",
      name: "Log out",
      comment: "Log out current user",
      genericName: "Power",
      categories: ["System", "LogOut"],
      script: [Host.power, "logout"],
      iconId: "system-log-out"
    },
    {
      id: "nyx-power-lock",
      name: "Lock",
      comment: "Lock current session",
      genericName: "Power",
      categories: ["System", "Lock"],
      script: [Host.power, "lock"],
      iconId: "system-lock-screen"
    },
    {
      id: "nyx-power-suspend",
      name: "Suspend",
      comment: "Suspend to RAM",
      genericName: "Power",
      categories: ["System", "Suspend"],
      script: [Host.power, "suspend"],
      iconId: "system-suspend"
    },
    {
      id: "nyx-power-hibernate",
      name: "Hibernate",
      comment: "Suspend to disk",
      genericName: "Power",
      categories: ["System", "Hibernate"],
      script: [Host.power, "hibernate"],
      iconId: "system-hibernate"
    }
  ]

  readonly property var utilities: [
    {
      id: "nyx-utils-screenshot",
      name: "Screenshot",
      comment: "Select a region, then annotate it",
      genericName: "Utility",
      categories: ["Utility", "ImageProcessing"],
      script: [Host.screenshot, "region"],
      iconId: "accessories-screenshot"
    },
    {
      id: "nyx-utils-screenshot-output",
      name: "Screenshot (monitor)",
      comment: "Capture the focused monitor, then annotate it",
      genericName: "Utility",
      categories: ["Utility", "ImageProcessing"],
      script: [Host.screenshot, "output"],
      iconId: "accessories-screenshot"
    },
    {
      id: "nyx-utils-colorpicker",
      name: "Colour picker",
      comment: "Pick a hex colour from the screen into the clipboard",
      genericName: "Utility",
      categories: ["Utility", "ImageProcessing"],
      script: [Host.colorpicker],
      iconId: "color-picker"
    },
    {
      id: "nyx-utils-monitor",
      name: "System Monitor",
      comment: "Monitor system resource usage",
      genericName: "Utility",
      categories: ["Utility", "Monitor"],
      script: [Config.terminal, "-e", Host.sysmon],
      iconId: "utilities-system-monitor"
    }
  ]

  // Display actions, all driven by the nyx-monitors helper.
  readonly property var displayLayouts: [
    {
      id: "nyx-display-mirror",
      name: "Mirror displays",
      comment: "Show one output's picture on another, or stop mirroring",
      panel: "mirror",
      genericName: "Display",
      categories: ["Display", "Mirror"],
      iconId: "preferences-desktop-remote-desktop"
    },
    {
      id: "nyx-display-arrange",
      name: "Arrange displays",
      comment: "Open the graphical display arranger (wdisplays)",
      genericName: "Display",
      categories: ["Display", "Configuration"],
      script: [Host.monitors, "arrange"],
      iconId: "preferences-desktop-display"
    },
    {
      id: "nyx-display-save",
      name: "Save monitor layout",
      comment: "Remember this arrangement for this set of monitors (changes already save themselves)",
      genericName: "Display",
      categories: ["Display", "Configuration"],
      script: [Host.monitors, "save"],
      iconId: "drive-harddisk"
    }
  ]

  // Audio output sinks, read live from PipeWire rather than a hard-coded list,
  // so a new headset or a bluetooth device shows up without a rebuild. `sink`
  // is matched against the node name to pick the bar icon; `script` makes it
  // the default sink.
  function sinkIcon(n) {
    const d = `${n.name} ${n.description}`.toLowerCase();
    if (/headset|chat/.test(d)) return ["󰋎", "audio-headset"];
    if (/headphone|bluez/.test(d)) return ["󰋋", "audio-headphones"];
    if (/hdmi|displayport/.test(d)) return ["󰍹", "video-display"];
    return ["󰓃", "audio-speakers"];
  }
  readonly property var outputs: Pipewire.nodes.values
    .filter(n => n.isSink && !n.isStream && n.audio)
    .map((n, i) => {
      const [icon, iconId] = sinkIcon(n);
      return {
        id: i,
        sink: n.name,
        icon: icon,
        comment: `Switch audio output to ${n.description || n.name}`,
        genericName: "Audio",
        categories: ["Audio"],
        iconId: iconId,
        name: n.nickname || n.description || n.name,
        script: [Host.audio, "set-default", `${n.id}`]
      };
    })

  readonly property var audioOptions: [
    {
      id: 0,
      genericName: "Audio",
      categories: ["Audio", "Mute", "Output"],
      comment: "Toggle mute on default output sink",
      iconId: "audio-volume-muted",
      name: "Toggle output mute",
      script: [Host.audio, "mute-output"]
    },
    {
      id: 1,
      genericName: "Audio",
      categories: ["Audio", "Mute", "Input"],
      comment: "Toggle mute on default input microphone",
      iconId: "microphone-sensitivity-muted",
      name: "Toggle input mute",
      script: [Host.audio, "mute-input"]
    }
  ]

  // icon aliases, if a class/appid matches key, use value
  // in cases where there isn't a good icon match
  readonly property var aliases: [
    [/.*spotify.*/i, "spotify"],
    [/^steam_app_(\d+)$/, "steam_icon_$1"],
    [/.*ghostty.*/i, "terminal"],
    [/kitty/i, "terminal"],
    [/.*pavucontrol.*/, "gnome-volume-control"],
    [/org.satty.satty/i, "image"],
    [/.*code.*/i, "vscode"],
    [/firefox-devedition/i, "firefox-developer-edition"]
  ]

  // Move to something interactive via the menu, but this'll do for now
  property var favorites: [
    "firefox-devedition",
    "com.mitchellh.ghostty",
    "code",
    "discord",
    "spotify",
    "steam",
    "org.gnome.Nautilus",
    "obsidian",
    "org.prismlauncher.PrismLauncher"
  ]
}
