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

  Timer {
    id: refreshDebounce
    interval: 250
    onTriggered: root.refresh()
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
