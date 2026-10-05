// Tailscale: this device and its peers on the left, details and actions on the right.
//
// Keys: Enter opens ssh to an online peer, Ctrl+C copies its IPv4, Ctrl+E
// toggles it as the exit node. Clicking an address copies it.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.services

SplitPanel {
  id: root
  required property string monitorId

  readonly property bool remote: root.current !== null && !root.current.self
  readonly property bool reachable: root.remote && root.current.online

  active: GlobalState.tailnetOpen && GlobalState.tailnetMonitorId === root.monitorId
  title: "Tailnet"
  placeholder: "Filter devices…"
  emptyText: !TailnetData.available ? "Tailscale is not running"
    : !TailnetData.running ? `Tailscale is ${TailnetData.state.toLowerCase() || "off"}`
    : "No devices"
  entries: TailnetData.running ? TailnetData.filter(root.query) : []
  detailTitle: root.current?.name ?? ""
  detailSubtitle: root.current?.dns ?? ""

  rowGlyph: n => root.osGlyph(n.os)
  rowGlyphColor: n => n.exitNode ? Style.colors.accent : n.online ? Style.colors.green : Style.colors.brightBlack
  rowTitle: n => n.self ? `${n.name} (this device)` : n.name
  rowSubtitle: n => `${n.ips[0] ?? ""}  •  ${root.presence(n)}`

  onActiveChanged: if (root.active) TailnetData.refresh()
  onCloseRequested: GlobalState.closeTailnet()
  onAccepted: node => {
    if (root.reachable) root.ssh();
    else root.copyIp();
  }

  onKeyPressed: event => {
    if (!(event.modifiers & Qt.ControlModifier)) return;
    if (event.key === Qt.Key_C && !event.isAutoRepeat) root.copyIp();
    else if (event.key === Qt.Key_E) root.toggleExitNode();
    else return;
    event.accepted = true;
  }

  function osGlyph(os) {
    switch (os) {
    case "linux": return "\u{F033D}";
    case "android": return "\u{F0032}";
    case "macOS":
    case "iOS": return "\u{F0035}";
    case "windows": return "\u{F05B3}";
    default: return "\u{F0379}";
    }
  }

  function presence(node) {
    if (node.self || node.online) return node.exitNode ? "Online, exit node" : "Online";
    if (!node.lastSeen) return "Offline";
    return `Last seen ${Qt.formatDateTime(new Date(node.lastSeen), "d MMM, HH:mm")}`;
  }

  function connection(node) {
    if (node.self || !node.online) return "—";
    return node.direct ? "Direct" : `Relayed via ${node.relay || "DERP"}`;
  }

  function copyIp() {
    if (root.current?.ips.length) TailnetData.copy(root.current.ips[0]);
  }

  function ssh() {
    if (!root.reachable) return;
    TailnetData.ssh(root.current);
    GlobalState.closeTailnet();
  }

  function toggleExitNode() {
    if (!root.remote || !root.current.exitNodeOption) return;
    TailnetData.useExitNode(root.current.exitNode ? null : root.current);
  }

  headerActions: [
    IconButton {
      visible: TailnetData.available
      glyph: "\u{F0425}"
      label: TailnetData.running ? "On" : "Off"
      checked: TailnetData.running
      onActivated: TailnetData.setRunning(!TailnetData.running)
    }
  ]

  actions: [
    IconButton {
      visible: root.current !== null
      glyph: "\u{F018F}"
      onActivated: root.copyIp()
    },
    IconButton {
      visible: root.reachable
      glyph: "\u{F018D}"
      onActivated: root.ssh()
    },
    IconButton {
      visible: root.remote && root.current.exitNodeOption
      glyph: "\u{F0207}"
      label: root.current?.exitNode ? "Stop exit node" : "Use as exit node"
      checked: root.current?.exitNode ?? false
      onActivated: root.toggleExitNode()
    }
  ]

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.p3
    visible: root.current !== null

    FieldList {
      Layout.fillWidth: true
      fields: {
        const n = root.current;
        if (!n) return [];
        return [
          { label: "Status", value: root.presence(n), color: n.online ? Style.colors.green : Style.colors.brightBlack },
          { label: "Link", value: root.connection(n) },
          ...n.ips.map(ip => ({ label: ip.includes(":") ? "IPv6" : "IPv4", value: ip, copy: ip })),
          { label: "Host", value: n.host, copy: n.host },
          { label: "OS", value: n.os },
          { label: "Exit node", value: n.exitNode ? "In use" : n.exitNodeOption ? "Available" : "No" }
        ];
      }
      onCopied: text => TailnetData.copy(text)
    }

    Item { Layout.fillHeight: true }

    Text {
      Layout.fillWidth: true
      visible: TailnetData.error !== ""
      text: TailnetData.error
      wrapMode: Text.Wrap
      color: Style.colors.red
      font.family: Style.font.main
      font.pointSize: Style.font.normal
    }
  }
}
