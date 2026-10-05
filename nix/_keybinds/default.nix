# The keybinds nyx owns. One list renders both the Hyprland binds and the
# cheat sheet in the system panel, so the two cannot drift apart.
{ lib }:
let
  # A global shortcut the shell registers (shell.qml and the panels).
  shortcut = keys: name: label: { inherit keys label; shortcut = name; };
  command = keys: cmd: label: { inherit keys label; command = cmd; };
in {
  # MOD stands for the configured modifier.
  defaults = [
    (command "MOD + SHIFT + S" "nyx-screenshot region" "Screenshot a region")
    (shortcut "MOD + R" "toggleLauncher" "Launcher")
    (shortcut "ALT + Space" "toggleLauncher" "Launcher")
    (shortcut "MOD + U" "togglePower" "Power menu")
    (shortcut "MOD + V" "toggleClipboard" "Clipboard history")
    (shortcut "MOD + T" "toggleSystem" "System panel")
    (shortcut "ALT + Tab" "windowSwitcher" "Switch windows")
    (shortcut "ALT + SHIFT + Tab" "windowSwitcherBack" "Switch windows backwards")
    # Releasing Alt picks the window; it is plumbing, not something to press.
    ((shortcut "ALT + ALT_L" "windowSwitcherCommit" "Pick the window") // { release = true; nonConsuming = true; hidden = true; })
    (shortcut "MOD + W" "toggleWallpaper" "Wallpapers")
    (shortcut "MOD + SHIFT + W" "toggleTheme" "Themes")
    (shortcut "MOD + M" "toggleDisplays" "Displays")
    (shortcut "MOD + SHIFT + D" "toggleDocker" "Docker")
    (shortcut "MOD + SHIFT + T" "toggleTailnet" "Tailscale")
    (shortcut "MOD + B" "toggleBitwarden" "Bitwarden")
    (shortcut "MOD + N" "toggleNotifications" "Notifications")
    (shortcut "MOD + BackSpace" "discardLastNotification" "Dismiss the last notification")
    # Fn+F8 sends SUPER + period, the Windows emoji shortcut.
    (shortcut "MOD + period" "toggleEmoji" "Emoji picker")
    ((command "XF86KbdBrightnessUp" "nyx-kbd-backlight cycle" "Keyboard backlight") // { locked = true; })
    ((command "XF86KbdBrightnessDown" "nyx-kbd-backlight cycle" "Keyboard backlight") // { locked = true; })
    ((command "XF86MonBrightnessUp" "nyx-brightness up" "Screen brightness up") // { locked = true; repeating = true; })
    ((command "XF86MonBrightnessDown" "nyx-brightness down" "Screen brightness down") // { locked = true; repeating = true; })
    ((shortcut "XF86AudioMute" "toggleMute" "Mute") // { locked = true; })
    ((shortcut "XF86AudioLowerVolume" "decrementVolume" "Volume down") // { locked = true; repeating = true; })
    ((shortcut "XF86AudioRaiseVolume" "incrementVolume" "Volume up") // { locked = true; repeating = true; })
  ];

  # Lua for hyprland.lua; the binds come in order.
  lua = { modifier, binds }:
  let
    str = builtins.toJSON;
    keys = b: lib.replaceStrings [ "MOD" ] [ modifier ] b.keys;
    action = b:
      if b.shortcut != null then "nyx(${str b.shortcut})" else "hl.dsp.exec_cmd(${str b.command})";
    flags = b: lib.filter (f: b.${f.attr}) [
      { attr = "release"; lua = "release"; }
      { attr = "nonConsuming"; lua = "non_consuming"; }
      { attr = "locked"; lua = "locked"; }
      { attr = "repeating"; lua = "repeating"; }
    ];
    opts = b:
      let f = flags b;
      in lib.optionalString (f != [ ]) ", { ${lib.concatMapStringsSep ", " (x: "${x.lua} = true") f} }";
  in ''
    local function nyx(name) return hl.dsp.global("nyx:" .. name) end

    ${lib.concatMapStringsSep "\n" (b: "hl.bind(${str (keys b)}, ${action b}${opts b})") binds}
  '';

  # What the shell shows: every bind that is not plumbing.
  json = { modifier, binds }:
    builtins.toJSON (map (b: { keys = lib.replaceStrings [ "MOD" ] [ modifier ] b.keys; inherit (b) label; })
      (lib.filter (b: !b.hidden) binds));
}
