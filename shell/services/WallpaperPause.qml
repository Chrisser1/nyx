// Pauses the video wallpaper on a monitor while windows cover it or the
// screen is off, so nothing decodes frames nobody can see.
// Tiled windows leave gaps, so "hidden" means fullscreen or nearly covered.

pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import QtQuick
import qs.config
import qs.services

Singleton {
  id: root

  // Share of the monitor's usable area that windows cover; sampled on a grid,
  // so overlapping windows are not counted twice.
  function coverage(m, rects) {
    const scale = m.scale || 1;
    const r = m.reserved ?? [0, 0, 0, 0];
    const x0 = m.x + r[0], y0 = m.y + r[1];
    const w = m.width / scale - r[0] - r[2], h = m.height / scale - r[1] - r[3];
    const cols = 48, rows = 27;
    let hit = 0;
    for (let i = 0; i < cols; i++) {
      for (let j = 0; j < rows; j++) {
        const px = x0 + (i + 0.5) * w / cols, py = y0 + (j + 0.5) * h / rows;
        if (rects.some(a => px >= a.at[0] && px < a.at[0] + a.size[0]
            && py >= a.at[1] && py < a.at[1] + a.size[1])) hit++;
      }
    }
    return hit / (cols * rows);
  }

  // At least this much covered and the sliver left is not worth decoding for.
  readonly property real coveredShare: 0.9

  // Names of the monitors whose wallpaper cannot be seen.
  function hiddenOutputs(monitors, windows) {
    return monitors.filter(m => {
      if (m.dpmsStatus === false) return true;
      const ws = m.activeWorkspace?.address ?? "";
      const shown = windows.filter(w => w.mapped && !w.hidden && w.workspace?.address === ws);
      if (shown.some(w => w.fullscreen > 0)) return true;
      return root.coverage(m, shown) >= root.coveredShare;
    }).map(m => m.name);
  }

  property var hidden: root.hiddenOutputs(HyprlandData.monitors, HyprlandData.windowList)
  property var paused: []

  // Only monitors whose state changed get a message.
  onHiddenChanged: {
    for (const name of root.hidden) {
      if (!root.paused.includes(name)) Quickshell.execDetached([Host.wallpaper, "pause", name]);
    }
    for (const name of root.paused) {
      if (!root.hidden.includes(name)) Quickshell.execDetached([Host.wallpaper, "resume", name]);
    }
    root.paused = root.hidden;
  }

  // Referenced once from shell.qml so the singleton exists. A previous shell may
  // have died with a wallpaper paused; hidden outputs are paused again as the
  // monitor data arrives.
  function init() { Quickshell.execDetached([Host.wallpaper, "resume", "all"]); }
}
