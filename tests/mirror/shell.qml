// Mirror panel: outputs listed, a source picked, the mirror command run and
// the stop button once the output mirrors. Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.mirror

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0
  property string evals: ""

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function find(item, name) {
    if (item.objectName === name) return item;
    for (const c of item.children) {
      const found = root.find(c, name);
      if (found) return found;
    }
    return null;
  }

  function stub(file) { return `${Quickshell.env("STUB_DIR")}/${file}` }

  Process {
    id: reader
    command: ["cat", root.stub("evals")]
    stdout: StdioCollector { onStreamFinished: root.evals = text }
  }

  readonly property var steps: [
    { what: "open", ready: () => true,
      act: () => GlobalState.openMirror("TEST") },
    { what: "outputs listed", settle: 5, ready: () => panel.entries.length === 2,
      act: () => {
        if (panel.current.name !== "HDMI-A-1") root.fail(`first output: ${panel.current?.name}`);
        if (panel.sources.map(s => s.name).join() !== "DP-1") root.fail(`sources: ${panel.sources.map(s => s.name)}`);
        if (root.find(panel, "stop")?.visible) root.fail("stop button without a mirror");
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/mirror.png`));
        root.find(panel, "source").activated();
      } },
    { what: "mirror command run", settle: 3, ready: () => true,
      act: () => reader.running = true },
    { what: "evals read", settle: 3, ready: () => root.evals !== "",
      act: () => {
        if (!root.evals.includes('output = "HDMI-A-1"') || !root.evals.includes('mirror = "DP-1"')) root.fail(`mirror eval: ${root.evals}`);
        Quickshell.execDetached(["cp", "-f", root.stub("mirrored.json"), root.stub("monitors.json")]);
        MonitorData.refresh();
      } },
    { what: "mirrored", settle: 3, ready: () => panel.mirrored,
      act: () => {
        if (!root.find(panel, "stop").visible) root.fail("no stop button while mirrored");
        panel.accepted(panel.current);
      } },
    { what: "stop command run", settle: 3, ready: () => true,
      act: () => { root.evals = ""; reader.running = true } },
    { what: "evals read again", settle: 3, ready: () => root.evals !== "",
      act: () => {
        if (!root.evals.includes('mirror = "none"')) root.fail(`unmirror eval: ${root.evals}`);
        GlobalState.closeAll();
        if (GlobalState.mirrorOpen) root.fail("closeAll left the panel open");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1440
    implicitHeight: 600
    color: "black"

    MirrorPanel {
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
