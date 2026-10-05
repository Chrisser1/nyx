// Backlight, via brightnessctl. Desktops have no /sys/class/backlight at all, so
// `available` stays false there and the OSD simply never fires for brightness.

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
  signal changed()

  function refresh() { getProc.running = true }

  function set(fraction) {
    const pct = Math.max(1, Math.min(100, Math.round(fraction * 100)));
    if (!root.available) return;
    setProc.command = [Host.brightnessctl, "-c", "backlight", "-m", "set", `${pct}%`];
    setProc.running = true;
  }

  function step(delta) {
    if (!root.available) return;
    root.set(root.value + delta);
  }

  // -m gives machine-readable "device,class,current,percent%,max".
  // -c backlight is essential: without it brightnessctl falls back to whatever
  // device it finds first, which on a desktop with no panel is the capslock LED
  // -- so `set` would toggle the keyboard light instead of screen brightness.
  Process {
    id: getProc
    command: [Host.brightnessctl, "-c", "backlight", "-m", "info"]
    running: true
    stdout: StdioCollector {
      onStreamFinished: {
        const line = this.text.split("\n").find(l => l.length > 0);
        if (!line) { root.available = false; return; }
        const f = line.split(",");
        if (f.length < 5 || f[1] !== "backlight") { root.available = false; return; }
        const cur = parseInt(f[2]);
        const max = parseInt(f[4]);
        if (!isFinite(cur) || !isFinite(max) || max <= 0) { root.available = false; return; }
        root.available = true;
        root.value = cur / max;
        root.changed();
      }
    }
  }

  Process {
    id: setProc
    running: false
    onExited: root.refresh()
  }

  // Hyprland runs nyx-brightness on the key, not this service, so that the
  // panel still dims with the shell dead; the helper dispatches this global
  // afterwards. Without it `value` would only ever hold its startup reading and
  // the OSD would never fire.
  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "brightnessChanged"
    description: "Re-read the panel backlight after nyx-brightness stepped it"
    onPressed: root.refresh()
  }
}
