// Launcher display mode: monitor cards that follow the
// monitors' state. Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.launcher

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function names() { return LauncherData.monitorEntries.map(e => e.name) }

  readonly property var steps: [
    { what: "open display mode", ready: () => true,
      act: () => GlobalState.openLauncher({ id: "TEST", mode: "display" }) },
    { what: "monitors listed", settle: 3, ready: () => LauncherData.monitorEntries.length > 0,
      act: () => {
        const n = root.names();
        if (n.slice(0, 2).join() !== "HDMI-A-1,DP-1") root.fail(`monitor cards: ${n}`);
        if (n.some(x => x.startsWith("Mirror ") || x.startsWith("Stop mirroring"))) root.fail(`mirror cards are back: ${n}`);
        const mirror = LauncherData.displayData.find(d => d.entry.name === "Mirror displays");
        if (mirror?.entry.panel !== "mirror") root.fail("the Mirror displays card does not open the panel");
        const hdmi = LauncherData.monitorEntries[0];
        if (hdmi.actions.some(a => a.name.startsWith("Stop mirroring"))) root.fail("stop action without a mirror");
        if (!hdmi.actions.some(a => a.command.slice(-3).join() === "mirror,DP-1,HDMI-A-1")) root.fail("show-here action");
        Quickshell.execDetached(["cp", "-f", `${Quickshell.env("STUB_DIR")}/mirrored.json`, `${Quickshell.env("STUB_DIR")}/monitors.json`]);
      } },
    { what: "mirror applied", settle: 3, ready: () => true,
      act: () => LauncherData.refreshMonitors() },
    { what: "mirrored", settle: 3, ready: () => LauncherData.monitorEntries.some(e => e.comment.includes("mirroring")),
      act: () => {
        const hdmi = LauncherData.monitorEntries.find(e => e.name === "HDMI-A-1");
        if (!hdmi.comment.includes("mirroring DP-1")) root.fail(`mirror source shown by name: ${hdmi.comment}`);
        const stop = hdmi.actions.find(a => a.name.startsWith("Stop mirroring"));
        if (stop?.command.slice(-2).join() !== "unmirror,HDMI-A-1") root.fail(`unmirror action: ${stop?.command}`);
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1440
    implicitHeight: 400
    color: "black"

    Launcher {
      monitorId: "TEST"
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      const s = root.steps[root.step];
      if (s.ready() && root.waited >= (s.settle ?? 0)) {
        root.waited = 0;
        root.step++;
        s.act();
      } else if (++root.waited > 150) {
        root.fail(`timed out waiting for: ${s.what}`);
      }
    }
  }
}
