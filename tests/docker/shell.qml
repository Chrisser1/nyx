// Docker panel: list, running count, filtering, actions and error reporting.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.docker

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
    { what: "containers loaded", ready: () => DockerData.containers.length === 3,
      act: () => {
        if (!DockerData.available) root.fail("available");
        if (DockerData.running !== 1) root.fail(`running count ${DockerData.running}`);
        if (DockerData.filter("postgres").map(c => c.name).join() !== "db") root.fail("filter by image");
        if (DockerData.filter("site web").length !== 1) root.fail("filter by project and name");
        GlobalState.openDocker("TEST");
      } },
    { what: "panel open", settle: 5, ready: () => panel.current?.name === "db",
      act: () => {
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/docker.png`));
        panel.remove();
        panel.toggle();
      } },
    { what: "stop called", ready: () => calls.text().trim() === "stop bbbbbbbbbbbb",
      act: () => DockerData.act("restart", { id: "broken" }) },
    { what: "error shown", ready: () => DockerData.error.includes("restart failed"),
      act: () => {
        GlobalState.closeAll();
        if (GlobalState.dockerOpen) root.fail("closeAll left it open");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1200
    implicitHeight: 720
    color: "black"

    DockerPanel {
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
