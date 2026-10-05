// Docker containers: filterable list on the left, details and actions on the right.
//
// Keys: Enter starts, stops or unpauses, Ctrl+R restarts, Ctrl+L follows the logs,
// Ctrl+E opens a shell, Shift+Delete removes a stopped container (twice).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.config
import qs.services

SplitPanel {
  id: root
  required property string monitorId

  readonly property bool running: root.current?.state === "running"
  property bool removeArmed: false

  active: GlobalState.dockerOpen && GlobalState.dockerMonitorId === root.monitorId
  title: "Docker"
  placeholder: "Filter containers…"
  emptyText: DockerData.available ? "No containers" : "Docker is not running"
  entries: DockerData.filter(root.query)
  detailTitle: root.current?.name ?? ""
  detailSubtitle: root.current?.status ?? ""

  rowGlyph: _ => "\u{F0868}"
  rowGlyphColor: c => root.stateColor(c.state)
  rowTitle: c => c.name
  rowSubtitle: c => `${c.image}  •  ${c.status}`

  onActiveChanged: if (root.active) DockerData.refresh()
  onCurrentChanged: root.removeArmed = false
  onCloseRequested: GlobalState.closeDocker()
  onAccepted: root.toggle()

  onKeyPressed: event => {
    const ctrl = event.modifiers & Qt.ControlModifier;
    if (ctrl && event.key === Qt.Key_R) root.act("restart");
    else if (ctrl && event.key === Qt.Key_L) root.terminal("logs");
    else if (ctrl && event.key === Qt.Key_E) root.terminal("shell");
    else if (event.key === Qt.Key_Delete && (event.modifiers & Qt.ShiftModifier)) root.remove();
    else return;
    event.accepted = true;
  }

  function stateColor(state) {
    if (state === "running") return Style.colors.green;
    if (state === "paused" || state === "restarting") return Style.colors.yellow;
    if (state === "dead") return Style.colors.red;
    return Style.colors.brightBlack;
  }

  function act(action) {
    if (root.current) DockerData.act(action, root.current);
  }

  function toggle() {
    const state = root.current?.state;
    root.act(state === "running" ? "stop" : state === "paused" ? "unpause" : "start");
  }

  function terminal(action) {
    if (!root.current || (action === "shell" && !root.running)) return;
    DockerData.openTerminal(action, root.current);
    GlobalState.closeDocker();
  }

  function remove() {
    if (!root.current || root.running) return;
    if (!root.removeArmed) {
      root.removeArmed = true;
      disarm.restart();
      return;
    }
    root.removeArmed = false;
    root.act("remove");
  }

  Timer {
    id: disarm
    interval: 3000
    onTriggered: root.removeArmed = false
  }

  actions: [
    IconButton {
      visible: root.current !== null
      glyph: root.running ? "\u{F04DB}" : "\u{F040A}"
      onActivated: root.toggle()
    },
    IconButton {
      visible: root.running
      glyph: "\u{F0709}"
      onActivated: root.act("restart")
    },
    IconButton {
      visible: root.current !== null
      glyph: "\u{F09A8}"
      onActivated: root.terminal("logs")
    },
    IconButton {
      visible: root.running
      glyph: "\u{F018D}"
      onActivated: root.terminal("shell")
    },
    IconButton {
      visible: root.current !== null && !root.running
      glyph: "\u{F01B4}"
      label: root.removeArmed ? "Remove?" : ""
      danger: true
      checked: root.removeArmed
      onActivated: root.remove()
    }
  ]

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.p3
    visible: root.current !== null

    FieldList {
      Layout.fillWidth: true
      fields: root.current ? [
        { label: "Image", value: root.current.image },
        { label: "State", value: root.current.state, color: root.stateColor(root.current.state) },
        { label: "Ports", value: root.current.ports || "None" },
        { label: "Project", value: root.current.project || "None" },
        { label: "Created", value: root.current.created },
        { label: "ID", value: root.current.id, copy: root.current.id }
      ] : []
      onCopied: text => Quickshell.clipboardText = text
    }

    Item { Layout.fillHeight: true }

    Text {
      Layout.fillWidth: true
      visible: DockerData.error !== ""
      text: DockerData.error
      wrapMode: Text.Wrap
      color: Style.colors.red
      font.family: Style.font.main
      font.pointSize: Style.font.normal
    }
  }
}
