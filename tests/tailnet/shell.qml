// Tailnet panel: status, ordering, filtering, actions and the stopped state.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.tailnet

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  FileView {
    id: calls
    path: `${Quickshell.env("STUB_DIR")}/calls`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  readonly property var steps: [
    { what: "status loaded", ready: () => TailnetData.nodes.length === 4,
      act: () => {
        if (TailnetData.nodes.map(n => n.host).join() !== "laptop,pc-1,server,pixel") root.fail("order");
        if (TailnetData.exitNode?.host !== "server") root.fail("exit node");
        if (TailnetData.online !== 2) root.fail("online count");
        if (TailnetData.filter("android").map(n => n.host).join() !== "pixel") root.fail("filter by os");
        if (TailnetData.filter("100.64.0.3").length !== 1) root.fail("filter by ip");
        GlobalState.openTailnet("TEST");
      } },
    { what: "panel open", settle: 5, ready: () => panel.current?.self === true,
      act: () => {
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/tailnet.png`));
        panel.toggleExitNode();
        TailnetData.useExitNode(TailnetData.exitNode ? null : TailnetData.peers[1]);
        TailnetData.setRunning(false);
      } },
    { what: "actions run", ready: () => calls.text().trim() === "set --exit-node=\ndown",
      act: () => {
        GlobalState.closeAll();
        if (GlobalState.tailnetOpen) root.fail("closeAll left it open");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1200
    implicitHeight: 720
    color: "black"

    TailnetPanel {
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
