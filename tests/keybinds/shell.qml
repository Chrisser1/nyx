// Keybind cheat sheet: the list loads from keybinds.json and the system panel
// shows it in place of the process list. Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.system

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function count(item, name) {
    let n = item.objectName === name ? 1 : 0;
    for (const c of item.children) n += root.count(c, name);
    return n;
  }

  readonly property var steps: [
    { what: "list loaded", ready: () => Keybinds.entries.length > 0,
      act: () => {
        const sys = Keybinds.entries.find(e => e.keys === "SUPER + T");
        if (sys?.label !== "System panel") root.fail("system panel entry");
        if (Keybinds.entries.some(e => e.keys === "ALT + ALT_L")) root.fail("hidden bind listed");
        if (sys.parts.join() !== "Super,T") root.fail(`parts: ${sys.parts}`);
        if (Keybinds.parts("SUPER + SHIFT + period").join() !== "Super,Shift,.") root.fail("named keys");
        if (Keybinds.parts("XF86AudioLowerVolume").join() !== "Audio Lower Volume") root.fail("media keys");
        GlobalState.openSys("TEST");
      } },
    { what: "processes first", settle: 5, ready: () => panel.visible,
      act: () => {
        if (root.count(panel, "bind") !== 0) root.fail("keybinds shown before asking");
        panel.showKeys = true;
      } },
    { what: "keybinds shown", settle: 5, ready: () => true,
      act: () => {
        if (root.count(panel, "bind") < 3) root.fail(`keybind rows: ${root.count(panel, "bind")}`);
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/keybinds.png`));
      } },
    { what: "screenshot", settle: 5, ready: () => true,
      act: () => {
        GlobalState.closeAll();
        if (panel.showKeys) root.fail("closing left the cheat sheet open");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 700
    implicitHeight: 900
    color: "black"

    SysPanel {
      id: panel
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
