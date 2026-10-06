// Containers for modules/docker, backed by the nyx-docker helper. Refreshes
// on Docker events, so the bar count stays current without polling.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.utils

Singleton {
  id: root

  property bool available: false
  // [{ id, name, image, state, status, ports, created, project }], running first.
  property list<var> containers: []
  readonly property int running: root.containers.filter(c => c.state === "running").length
  readonly property string error: actions.error
  readonly property bool busy: actions.busy

  function filter(query) {
    const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
    return root.containers.filter(c => {
      const haystack = `${c.name} ${c.image} ${c.project} ${c.state}`.toLowerCase();
      return words.every(word => haystack.includes(word));
    });
  }

  // Published TCP ports as [{ port, url }], one per host port. Handles the
  // docker forms "0.0.0.0:8080->80/tcp", "[::]:8080->80/tcp" and ranges
  // ("8000-8002->8000-8002/tcp", linked at the first port).
  function portLinks(ports) {
    const seen = new Set();
    const links = [];
    for (const part of (ports ?? "").split(",")) {
      const m = part.trim().match(/:(\d+)(?:-\d+)?->\d+(?:-\d+)?\/tcp$/);
      if (!m || seen.has(m[1])) continue;
      seen.add(m[1]);
      links.push({ port: m[1], url: `http://localhost:${m[1]}` });
    }
    return links;
  }

  // Overlapping refreshes run one after another.
  property bool refreshPending: false

  function refresh() {
    if (listProc.running) root.refreshPending = true;
    else listProc.running = true;
  }

  function act(action, container) { actions.run([Host.docker, action, container.id]); }

  function openTerminal(action, container) {
    Quickshell.execDetached([Config.terminal, "-e", Host.docker, action, container.id]);
  }

  // Containers that need attention: crash-looping, dead or failing a health check.
  readonly property list<var> troubled: root.containers.filter(c =>
    c.state === "restarting" || c.state === "dead" || c.status.includes("(unhealthy)"))

  function actProject(action, project) { actions.run([Host.docker, "project", action, project]); }

  // --- Logs: the followed container's recent output, for the panel's log view.
  property string logId: ""
  property string logText: ""
  readonly property int logLines: 2000
  property var logBuffer: []

  property string wantedLogId: ""

  // A short delay between the old stream dying and the new one starting, so the
  // two never overlap.
  function followLogs(container) {
    if (root.wantedLogId === (container?.id ?? "")) return;
    root.stopLogs();
    root.wantedLogId = container?.id ?? "";
    if (container) startLogs.restart();
  }

  function stopLogs() {
    startLogs.stop();
    logsProc.running = false;
    root.wantedLogId = "";
    root.logId = "";
    root.logBuffer = [];
    root.logText = "";
  }

  Timer {
    id: startLogs
    interval: 80
    onTriggered: {
      root.logId = root.wantedLogId;
      logsProc.running = true;
    }
  }

  Process {
    id: logsProc
    command: [Host.docker, "logs", root.logId]
    stdout: SplitParser {
      onRead: line => {
        // Colour codes mean nothing in a plain text view.
        root.logBuffer.push(line.replace(/\x1b\[[0-9;]*[A-Za-z]/g, ""));
        if (root.logBuffer.length > root.logLines) root.logBuffer.splice(0, root.logBuffer.length - root.logLines);
        flush.start();
      }
    }
  }

  // Output arrives in bursts; the view is refreshed at most every 100 ms.
  Timer {
    id: flush
    interval: 100
    onTriggered: root.logText = root.logBuffer.join("\n")
  }

  // --- Details: `docker inspect`, for the selected container only.
  property string detailId: ""
  property var detail: ({})

  function loadDetail(container) {
    if (root.detailId === (container?.id ?? "")) return;
    inspectProc.running = false;
    root.detailId = container?.id ?? "";
    root.detail = ({});
    if (container) startInspect.restart();
  }

  Timer {
    id: startInspect
    interval: 120
    onTriggered: inspectProc.running = true
  }

  Process {
    id: inspectProc
    command: [Host.docker, "inspect", root.detailId]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.detail = JSON.parse(this.text); } catch (e) { root.detail = ({}); }
      }
    }
  }

  // --- Stats: CPU and memory of running containers, sampled while sampling is on.
  property bool sampling: false
  // { id: { cpu, memory, memPercent } } for the latest sample, and cpu history per id.
  property var stats: ({})
  property var cpuHistory: ({})
  readonly property int historyLength: 30

  function sample() {
    if (!statsProc.running && root.running > 0) statsProc.running = true;
  }

  onSamplingChanged: if (root.sampling) root.sample()

  Timer {
    interval: 3000
    running: root.sampling
    repeat: true
    onTriggered: root.sample()
  }

  Process {
    id: statsProc
    command: [Host.docker, "stats"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          const history = {};
          for (const id in data) history[id] = [...(root.cpuHistory[id] ?? []), data[id].cpu].slice(-root.historyLength);
          root.stats = data;
          root.cpuHistory = history;
        } catch (e) {
          console.warn(`nyx: bad docker stats: ${e}`);
        }
      }
    }
  }

  readonly property CommandQueue actions: CommandQueue {
    onDrained: root.refresh()
  }

  Process {
    id: listProc
    command: [Host.docker, "list"]
    running: true
    onExited: {
      if (!root.refreshPending) return;
      root.refreshPending = false;
      Qt.callLater(root.refresh);
    }
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          root.available = data.available;
          root.containers = data.containers;
        } catch (e) {
          console.warn(`nyx: bad docker list: ${e}`);
        }
      }
    }
  }

  // Events are coalesced for 250 ms, and a refresh is never started sooner than
  // `minGap` after the last one, so a container in a restart loop costs one
  // `docker ps` a second instead of one every few milliseconds.
  property bool eventPending: false

  function refreshFromEvent() {
    if (minGap.running) {
      root.eventPending = true;
      return;
    }
    root.refresh();
    minGap.start();
  }

  Timer {
    id: refreshDebounce
    interval: 250
    onTriggered: root.refreshFromEvent()
  }

  Timer {
    id: minGap
    interval: 1000
    onTriggered: {
      if (!root.eventPending) return;
      root.eventPending = false;
      root.refreshFromEvent();
    }
  }

  // Exits when the daemon is down or restarts; retried until it is back.
  Process {
    id: events
    command: [Host.docker, "events"]
    running: true
    stdout: SplitParser {
      onRead: refreshDebounce.restart()
    }
    onExited: retry.start()
  }

  Timer {
    id: retry
    interval: 15000
    onTriggered: {
      root.refresh();
      events.running = true;
    }
  }
}
