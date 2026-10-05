// The shortcuts nyx binds, for the system panel's cheat sheet. The list is
// rendered by the home-manager module (programs.nyx.keybinds) next to the
// Hyprland binds it describes.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  // [{ keys, label }], in the order they are bound.
  property var entries: []

  readonly property var names: ({
    SUPER: "Super", ALT: "Alt", CTRL: "Ctrl", SHIFT: "Shift",
    BackSpace: "Backspace", period: ".", Space: "Space", Tab: "Tab"
  })

  // "SUPER + SHIFT + T" -> ["Super", "Shift", "T"]; media keys read as words.
  function parts(keys) {
    return keys.split(" + ").map(k => {
      if (root.names[k]) return root.names[k];
      return k.startsWith("XF86") ? k.slice(4).replace(/([a-z])([A-Z])/g, "$1 $2") : k;
    });
  }

  FileView {
    path: `${Quickshell.env("XDG_CONFIG_HOME") || `${Quickshell.env("HOME")}/.config`}/nyx/keybinds.json`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.entries = JSON.parse(text()).map(e => ({ keys: e.keys, label: e.label, parts: root.parts(e.keys) }));
      } catch (e) {
        console.warn(`nyx: ignoring malformed keybinds.json: ${e}`);
      }
    }
  }
}
