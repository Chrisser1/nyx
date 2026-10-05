// Launcher display mode: monitor cards plus mirror cards that follow the
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
        if (!n.includes("Mirror HDMI-A-1 onto DP-1") || !n.includes("Mirror DP-1 onto HDMI-A-1")) root.fail(`mirror cards: ${n}`);
        if (n.some(x => x.startsWith("Stop mirroring"))) root.fail("stop card without a mirror");
        if (LauncherData.displayData.some(d => d.entry.name === "Mirror displays")) root.fail("the argument-less mirror card is back");
        const mirror = LauncherData.monitorEntries.find(e => e.name === "Mirror HDMI-A-1 onto DP-1");
        if (mirror.script.slice(-3).join() !== "mirror,HDMI-A-1,DP-1") root.fail(`mirror command: ${mirror.script}`);
        Quickshell.execDetached(["cp", "-f", `${Quickshell.env("STUB_DIR")}/mirrored.json`, `${Quickshell.env("STUB_DIR")}/monitors.json`]);
      } },
    { what: "mirror applied", settle: 3, ready: () => true,
      act: () => LauncherData.refreshMonitors() },
    { what: "stop card", settle: 3, ready: () => LauncherData.monitorEntries.some(e => e.name.startsWith("Stop mirroring")),
      act: () => {
        const n = root.names();
        if (n.some(x => x.startsWith("Mirror "))) root.fail(`mirror cards while mirrored: ${n}`);
        const stop = LauncherData.monitorEntries.find(e => e.name === "Stop mirroring on HDMI-A-1");
        if (stop.script.slice(-2).join() !== "unmirror,HDMI-A-1") root.fail(`unmirror command: ${stop.script}`);
        if (stop.comment !== "HDMI-A-1 shows DP-1") root.fail(`mirror source shown by name: ${stop.comment}`);
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
