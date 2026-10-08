// WallpaperPause.hiddenOutputs: which monitors have their wallpaper hidden.
import QtQuick
import Quickshell
import qs.services

ShellRoot {
  id: root

  function expect(actual, wanted, what) {
    if (JSON.stringify(actual) !== JSON.stringify(wanted)) {
      console.error(`FAIL ${what}: got ${JSON.stringify(actual)}, want ${JSON.stringify(wanted)}`);
      Qt.exit(1);
    }
  }

  Timer {
    interval: 300
    running: true
    onTriggered: root.run()
  }

  function run() {
    // 2160x1350 logical, a 40px bar on top.
    const mon = (name, ws, extra) => Object.assign({
      name, x: 0, y: 0, width: 2880, height: 1800, scale: 4 / 3,
      reserved: [0, 40, 0, 0], dpmsStatus: true, activeWorkspace: { address: ws }
    }, extra);
    const win = (ws, at, size, extra) => Object.assign({
      mapped: true, hidden: false, fullscreen: 0, at, size, workspace: { address: ws }
    }, extra);
    const hidden = (m, w) => WallpaperPause.hiddenOutputs(m, w);
    const mons = [mon("A", "1"), mon("B", "2", { x: 2160 })];

    root.expect(hidden(mons, []), [], "no windows");
    root.expect(hidden(mons, [win("1", [10, 50], [1000, 600])]), [], "small window");
    root.expect(hidden(mons, [win("1", [0, 74], [1080, 1273]), win("1", [1080, 74], [1080, 1273])]), ["A"], "two tiles cover it");
    root.expect(hidden(mons, [win("1", [3, 74], [2154, 1273])]), ["A"], "one tile with gaps");
    root.expect(hidden(mons, [win("1", [0, 40], [1500, 1310])]), [], "70% is not enough");
    root.expect(hidden(mons, [win("1", [0, 40], [1500, 1310]), win("1", [0, 40], [1500, 1310])]), [], "overlap counted once");
    root.expect(hidden(mons, [win("3", [0, 40], [2160, 1310])]), [], "inactive workspace");
    root.expect(hidden(mons, [win("1", [0, 40], [2160, 1310], { hidden: true })]), [], "hidden window");
    root.expect(hidden(mons, [win("2", [2160, 40], [2160, 1310], { mapped: false })]), [], "unmapped window");
    root.expect(hidden(mons, [win("1", [10, 50], [100, 100], { fullscreen: 2 })]), ["A"], "fullscreen");
    root.expect(hidden(mons, [win("2", [2160, 40], [2160, 1310])]), ["B"], "second monitor offset");
    root.expect(hidden([mon("A", "1", { dpmsStatus: false })], []), ["A"], "screen off");

    console.log("PASS");
    Qt.exit(0);
  }
}
