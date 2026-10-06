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
  // [{ id, name, host, dns, ips, os, online, direct, relay, exitNode, exitNodeOption, tailscaleSsh, lastSeen, self }]
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
    if (GlobalState.tailnetOpen) root.refreshShares();
  }

  function setRunning(on) { actions.run([Host.tailnet, on ? "up" : "down"]); }
  function useExitNode(node) { actions.run([Host.tailnet, "exit-node", node ? node.ips[0] : "none"]); }
  function copy(text) { Quickshell.clipboardText = text; }

  // The terminal runs the helper, which picks a login the node accepts and keeps
  // the window open if ssh fails. The full DNS name, since a short name can be
  // this device's own (two machines called "pc").
  function ssh(node) {
    Quickshell.execDetached([Config.terminal, "-e", Host.tailnet, "ssh", node.dns, ...node.ips]);
  }

  // { [node id]: { ok, login, errors } }, from "Test SSH".
  property var sshChecks: ({})
  property string checking: ""

  function checkSsh(node) {
    if (checkProc.running) return;
    root.checking = node.id;
    checkProc.command = [Host.tailnet, "ssh-check", node.dns, ...node.ips];
    checkProc.running = true;
  }

  Process {
    id: checkProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const result = JSON.parse(this.text);
          const checks = Object.assign({}, root.sshChecks);
          checks[root.checking] = result;
          root.sshChecks = checks;
        } catch (e) {
          console.warn(`nyx: bad ssh check: ${e}`);
        }
        root.checking = "";
      }
    }
  }

  // --- Ping: three pings at the Tailscale layer; { ok, avg, direct, via, error }.
  property var pings: ({})
  property string pinging: ""

  function ping(node) {
    if (pingProc.running) return;
    root.pinging = node.id;
    pingProc.command = [Host.tailnet, "ping", node.ips[0]];
    pingProc.running = true;
  }

  Process {
    id: pingProc
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          const next = Object.assign({}, root.pings);
          next[root.pinging] = JSON.parse(this.text);
          root.pings = next;
        } catch (e) {
          console.warn(`nyx: bad ping: ${e}`);
        }
        root.pinging = "";
      }
    }
  }

  // --- Taildrop. What the last transfer did, shown under the details.
  property string notice: ""
  readonly property string downloads: `${Quickshell.env("HOME")}/Downloads`

  function send(node, paths) {
    if (!paths.length) return;
    root.notice = `Sending ${paths.length === 1 ? "1 file" : `${paths.length} files`} to ${node.name}…`;
    actions.run([Host.tailnet, "send", node.ips[0], ...paths]);
  }

  // Moves whatever other devices have sent into Downloads.
  function receive() {
    if (receiveProc.running) return;
    root.notice = "Checking for files…";
    receiveProc.running = true;
  }

  Process {
    id: receiveProc
    command: [Host.tailnet, "receive", root.downloads]
    stdout: StdioCollector {
      onStreamFinished: root.notice = this.text.trim().split("\n").pop() || "Nothing waiting"
    }
  }

  // --- Serve and Funnel entries on this device.
  // [{ port, scheme, funnel, url, mounts: [{ path, target }] }]
  property list<var> shares: []

  function refreshShares() {
    if (!sharesProc.running) sharesProc.running = true;
  }

  function share(port) { actions.run([Host.tailnet, "share", `${port}`]); }
  function funnel(port) { actions.run([Host.tailnet, "funnel", `${port}`]); }
  function unshare(entry) {
    actions.run(entry.funnel ? [Host.tailnet, "unfunnel", `${entry.port}`]
      : [Host.tailnet, "unshare", entry.scheme, `${entry.port}`]);
  }

  Process {
    id: sharesProc
    command: [Host.tailnet, "shares"]
    stdout: StdioCollector {
      onStreamFinished: {
        try { root.shares = JSON.parse(this.text); } catch (e) { root.shares = []; }
      }
    }
  }

  readonly property CommandQueue actions: CommandQueue {
    onDrained: {
      root.refresh();
      root.refreshShares();
      if (root.error) root.notice = "";
      else if (root.notice.startsWith("Sending")) root.notice = "Sent";
    }
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
