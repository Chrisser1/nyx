// Tailscale: this device and its peers on the left, details and actions on the right.
//
// Keys: Enter opens ssh to an online peer, Ctrl+T tests whether ssh gets in,
// Ctrl+P pings it, Ctrl+C copies its IPv4, Ctrl+E toggles it as the exit node.
// Clicking an address copies it. This device also lists what it shares, with a
// field to share a local port (to the tailnet, or to the internet with Funnel).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Dialogs
import QtQuick.Layouts
import Quickshell
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
    else if (event.key === Qt.Key_T) root.testSsh();
    else if (event.key === Qt.Key_P) root.ping();
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

  readonly property var sshCheck: TailnetData.sshChecks[root.current?.id ?? ""]

  property bool funnelArmed: false

  function ping() {
    if (root.reachable) TailnetData.ping(root.current);
  }

  // Sharing a port: the number typed in the field, if it is one.
  function shareablePort() {
    const port = parseInt(portField.text);
    return port >= 1 && port <= 65535 ? port : 0;
  }

  function shareLocal() {
    const port = root.shareablePort();
    if (port) TailnetData.share(port);
    portField.text = "";
  }

  // Funnel puts the port on the public internet, so it takes two presses.
  function funnelLocal() {
    const port = root.shareablePort();
    if (!port) return;
    if (!root.funnelArmed) {
      root.funnelArmed = true;
      funnelDisarm.restart();
      return;
    }
    root.funnelArmed = false;
    TailnetData.funnel(port);
    portField.text = "";
  }

  Timer {
    id: funnelDisarm
    interval: 3000
    onTriggered: root.funnelArmed = false
  }

  FileDialog {
    id: picker
    title: `Send to ${root.current?.name ?? ""}`
    fileMode: FileDialog.OpenFiles
    onAccepted: TailnetData.send(root.current, picker.selectedFiles.map(u => decodeURIComponent(u.toString().replace("file://", ""))))
  }

  function testSsh() {
    if (root.reachable) TailnetData.checkSsh(root.current);
  }

  function pingRows(node) {
    if (TailnetData.pinging === node.id) return [{ label: "Ping", value: "Pinging…" }];
    const r = TailnetData.pings[node.id];
    if (!r || !node.online) return [];
    if (!r.ok) return [{ label: "Ping", value: r.error, color: Style.colors.red }];
    return [{
      label: "Ping",
      value: `${r.avg.toFixed(0)} ms, ${r.direct ? "direct" : `relayed via ${r.via}`}`,
      color: r.direct ? Style.colors.green : Style.colors.yellow
    }];
  }

  // What "Test SSH" found: the login that gets in, or why none does.
  function sshRows(node) {
    if (TailnetData.checking === node.id) return [{ label: "SSH test", value: "Testing…" }];
    const r = root.sshCheck;
    if (!r || !node.online) return [];
    if (r.ok) return [{ label: "SSH test", value: `Works as ${r.login}`, color: Style.colors.green }];
    return r.errors.map(e => ({ label: "SSH test", value: e, color: Style.colors.red }));
  }

  function toggleExitNode() {
    if (!root.remote || !root.current.exitNodeOption) return;
    TailnetData.useExitNode(root.current.exitNode ? null : root.current);
  }

  headerActions: [
    IconButton {
      visible: TailnetData.running
      glyph: "\u{F01DA}"
      tip: "Receive files sent to this device (into Downloads)"
      onActivated: TailnetData.receive()
    },
    IconButton {
      visible: TailnetData.available
      glyph: "\u{F0425}"
      label: TailnetData.running ? "On" : "Off"
      checked: TailnetData.running
      tip: "Turn Tailscale on or off"
      onActivated: TailnetData.setRunning(!TailnetData.running)
    }
  ]

  actions: [
    IconButton {
      visible: root.current !== null
      glyph: "\u{F018F}"
      tip: "Copy IP (Ctrl+C)"
      onActivated: root.copyIp()
    },
    IconButton {
      visible: root.reachable
      glyph: "\u{F018D}"
      tip: "SSH in a terminal (Enter)"
      onActivated: root.ssh()
    },
    IconButton {
      visible: root.reachable
      glyph: "\u{F012C}"
      checked: TailnetData.checking === root.current?.id
      tip: "Test whether ssh gets in (Ctrl+T)"
      onActivated: root.testSsh()
    },
    IconButton {
      visible: root.reachable
      glyph: "\u{F04C5}"
      checked: TailnetData.pinging === root.current?.id
      tip: "Ping (Ctrl+P)"
      onActivated: root.ping()
    },
    IconButton {
      visible: root.reachable
      glyph: "\u{F048A}"
      tip: "Send files (Taildrop)"
      onActivated: picker.open()
    },
    IconButton {
      visible: root.remote && root.current.exitNodeOption
      glyph: "\u{F0207}"
      label: root.current?.exitNode ? "Stop exit node" : "Use as exit node"
      checked: root.current?.exitNode ?? false
      tip: "Route traffic through this node (Ctrl+E)"
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
          { label: "SSH", value: n.tailscaleSsh ? "Tailscale SSH offered" : "No Tailscale SSH", color: n.tailscaleSsh ? Style.colors.green : Style.colors.brightBlack },
          ...root.sshRows(n),
          ...root.pingRows(n),
          { label: "Exit node", value: n.exitNode ? "In use" : n.exitNodeOption ? "Available" : "No" }
        ];
      }
      onCopied: text => TailnetData.copy(text)
    }

    // What this device shares through Tailscale Serve and Funnel.
    ColumnLayout {
      Layout.fillWidth: true
      visible: root.current?.self === true
      spacing: Style.spacing.p2

      Text {
        text: TailnetData.shares.length ? "Shared from this device" : "Nothing shared"
        color: Style.colors.brightBlack
        font.family: Style.font.main
        font.pointSize: Style.font.large
      }

      Repeater {
        model: TailnetData.shares

        delegate: RowLayout {
          id: share
          required property var modelData
          Layout.fillWidth: true
          spacing: Style.spacing.p2

          ColumnLayout {
            Layout.fillWidth: true
            spacing: 0

            Text {
              Layout.fillWidth: true
              text: share.modelData.url
              elide: Text.ElideMiddle
              color: urlArea.containsMouse ? Style.colors.accent : Style.colors.brightWhite
              font.family: Style.font.main
              font.pointSize: Style.font.large

              MouseArea {
                id: urlArea
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: Qt.openUrlExternally(share.modelData.url)
              }
              Tip {
                text: "Open in the browser"
                hovered: urlArea.containsMouse
              }
            }
            Text {
              Layout.fillWidth: true
              text: `${share.modelData.funnel ? "Public on the internet" : "Tailnet only"}  •  ${share.modelData.mounts.map(m => m.target).join(", ")}`
              elide: Text.ElideRight
              color: share.modelData.funnel ? Style.colors.red : Style.colors.white
              font.family: Style.font.main
              font.pointSize: Style.font.normal
            }
          }

          IconButton {
            glyph: "\u{F01B4}"
            danger: true
            tip: share.modelData.funnel ? "Stop the public Funnel" : "Stop sharing"
            onActivated: TailnetData.unshare(share.modelData)
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p2

        TextField {
          id: portField
          Layout.fillWidth: true
          implicitHeight: Style.font.size4 + Style.spacing.p2 * 2
          leftPadding: Style.spacing.p3
          placeholderText: "Local port to share…"
          inputMethodHints: Qt.ImhDigitsOnly
          validator: IntValidator { bottom: 1; top: 65535 }
          renderType: TextField.NativeRendering
          color: Style.colors.brightWhite
          placeholderTextColor: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.normal
          background: Rectangle {
            color: Style.colors.gray1
            border.width: Style.bar.borderWidth
            border.color: portField.activeFocus ? Style.colors.accent : Style.colors.gray3
          }
          onAccepted: root.shareLocal()
        }
        IconButton {
          glyph: "\u{F0A89}"
          label: "Share"
          tip: "Share the port with your tailnet (http)"
          onActivated: root.shareLocal()
        }
        IconButton {
          glyph: "\u{F059F}"
          label: root.funnelArmed ? "Public?" : "Funnel"
          danger: true
          checked: root.funnelArmed
          tip: "Put the port on the public internet, press twice"
          onActivated: root.funnelLocal()
        }
      }
    }

    Text {
      Layout.fillWidth: true
      visible: TailnetData.notice !== ""
      text: TailnetData.notice
      wrapMode: Text.Wrap
      color: Style.colors.green
      font.family: Style.font.main
      font.pointSize: Style.font.normal
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
