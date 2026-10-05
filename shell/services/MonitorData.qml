// The outputs Hyprland knows about, from `nyx-monitors list`. Shared by the
// launcher's display cards and the mirror panel.
pragma Singleton

import Quickshell
import Quickshell.Io
import QtQuick
import qs.config

Singleton {
  id: root

  // name, desc, mode, pos, scale, enabled, mirrorOf (an output name or "none"), focused
  property var rows: []

  function refresh() { proc.running = true }

  // Outputs that can be mirrored from: on, and not mirroring something themselves.
  function sources(except) {
    return root.rows.filter(m => m.name !== except && m.enabled && m.mirrorOf === "none");
  }

  function mirror(source, target) {
    Quickshell.execDetached([Host.monitors, "mirror", source, target]);
    settle.restart();
  }

  function unmirror(target) {
    Quickshell.execDetached([Host.monitors, "unmirror", target]);
    settle.restart();
  }

  // Hyprland applies the change a moment after the command returns.
  Timer {
    id: settle
    interval: 700
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()

  Process {
    id: proc
    command: [Host.monitors, "list"]
    stderr: StdioCollector { id: err }
    onExited: code => { if (code !== 0) console.warn(`nyx: monitor list failed: ${err.text.trim()}`) }
    stdout: StdioCollector {
      onStreamFinished: {
        const rows = [];
        for (const line of this.text.split("\n")) {
          const f = line.split("\t");
          if (f.length < 8) continue;
          rows.push({
            name: f[0], desc: f[1], mode: f[2], pos: f[3],
            scale: f[4], enabled: f[5] === "enabled",
            mirrorOf: f[6], focused: f[7] === "focused"
          });
        }
        root.rows = rows;
      }
    }
  }
}
