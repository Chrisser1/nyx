// Tailscale state for modules/tailnet, polled through the nyx-tailnet helper;
// faster while the panel is open.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config
import qs.utils

Singleton {
  id: root

  property bool available: false
  property bool running: false
  property string state: ""
  property string tailnet: ""
  property var self: null
  // [{ id, name, host, dns, ips, os, online, direct, relay, exitNode, exitNodeOption, lastSeen, self }]
  property list<var> peers: []
  readonly property var nodes: root.self ? [root.self, ...root.peers] : root.peers
  readonly property var exitNode: root.peers.find(p => p.exitNode) ?? null
  readonly property int online: root.peers.filter(p => p.online).length
  readonly property string error: actions.error
  readonly property bool busy: actions.busy

  function filter(query) {
    const words = query.trim().toLowerCase().split(/\s+/).filter(Boolean);
    return root.nodes.filter(n => {
      const haystack = `${n.name} ${n.host} ${n.os} ${n.ips.join(" ")}`.toLowerCase();
      return words.every(word => haystack.includes(word));
    });
  }

  function refresh() {
    if (!statusProc.running) statusProc.running = true;
  }

  function setRunning(on) { actions.run([Host.tailnet, on ? "up" : "down"]); }
  function useExitNode(node) { actions.run([Host.tailnet, "exit-node", node ? node.ips[0] : "none"]); }
  function copy(text) { Quickshell.clipboardText = text; }

  function ssh(node) {
    Quickshell.execDetached([Config.terminal, "-e", "ssh", node.host]);
  }

  readonly property CommandQueue actions: CommandQueue {
    onDrained: root.refresh()
  }

  Process {
    id: statusProc
    command: [Host.tailnet, "status"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const data = JSON.parse(this.text);
          root.available = data.available;
          root.running = data.running;
          root.state = data.state ?? "";
          root.tailnet = data.tailnet ?? "";
          root.self = data.self ?? null;
          root.peers = data.peers;
        } catch (e) {
          console.warn(`nyx: bad tailnet status: ${e}`);
        }
      }
    }
  }

  Timer {
    interval: GlobalState.tailnetOpen ? 3000 : 15000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }
}
