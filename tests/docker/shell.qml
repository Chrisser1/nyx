// Docker panel: list, running count, filtering, port links, actions and error reporting.
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
        const links = DockerData.portLinks("0.0.0.0:8080->80/tcp, [::]:8080->80/tcp, 0.0.0.0:9000-9002->9000-9002/tcp, 53/udp, 0.0.0.0:53->53/udp, 443/tcp");
        if (links.map(l => l.url).join() !== "http://localhost:8080,http://localhost:9000") root.fail(`port links: ${JSON.stringify(links)}`);
        if (DockerData.portLinks("").length !== 0) root.fail("port links of nothing");
        GlobalState.openDocker("TEST");
      } },
    { what: "panel open", settle: 5, ready: () => panel.current?.name === "db",
      act: () => {
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/docker.png`));
      } },
    { what: "details and stats loaded", ready: () => panel.info.restarts === 2 && panel.stats?.cpu === 12.5,
      act: () => {
        const labels = panel.fields().map(f => f.label).join();
        for (const want of ["Health", "CPU", "Memory", "Open", "Restarts", "Command", "Networks", "Mounts"])
          if (!labels.split(",").includes(want)) root.fail(`field ${want} missing from ${labels}`);
        if (panel.fields().find(f => f.label === "Open").open !== "http://localhost:5432") root.fail("open url");
        if (DockerData.cpuHistory["bbbbbbbbbbbb"].length < 1) root.fail("cpu history");
        if (DockerData.troubled.length !== 0) root.fail("nothing is troubled");
        panel.toggleLogs();
      } },
    { what: "logs shown", ready: () => DockerData.logText.includes("red line"),
      act: () => {
        if (panel.view !== "logs") root.fail("log view not shown");
        if (DockerData.logText.includes("\x1b")) root.fail("colour codes kept");
        if (!DockerData.logText.startsWith("hello from db")) root.fail(`log text: ${DockerData.logText}`);
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/docker-logs.png`));
        panel.toggleLogs();
      } },
    { what: "logs closed", ready: () => DockerData.logId === "" && DockerData.logText === "",
      act: () => {
        if (panel.view !== "details") root.fail("details not restored");
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
