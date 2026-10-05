// Keyboard backlight, via nyx-kbd-backlight. The helper owns the LED name
// (asus::kbd_backlight here, absent entirely on a desktop), so this service only
// parses "<current> <max>" and never touches sysfs itself.
//
// Nothing here presses the key: Hyprland runs the helper directly so the light
// still steps with the shell dead. The helper then dispatches
// quickshell:kbdBacklightChanged, which is the only reason this service knows a
// step happened -- sysfs has no change signal to watch.

pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import qs.config

Singleton {
  id: root

  property bool available: false
  property real value: 0        // 0.0 - 1.0
  property int level: 0         // raw step, 0 - max
  property int max: 0
  signal changed()

  function refresh() { getProc.running = true }

  Process {
    id: getProc
    command: [Host.kbdBacklight, "status"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        // No LED (any desktop) means the helper prints nothing and exits 0.
        const f = this.text.trim().split(/\s+/);
        if (f.length < 2) { root.available = false; return; }
        const cur = parseInt(f[0]);
        const max = parseInt(f[1]);
        if (!isFinite(cur) || !isFinite(max) || max <= 0) { root.available = false; return; }
        root.available = true;
        root.level = cur;
        root.max = max;
        root.value = cur / max;
        root.changed();
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "kbdBacklightChanged"
    description: "Re-read the keyboard backlight after nyx-kbd-backlight stepped it"
    onPressed: root.refresh()
  }
}
