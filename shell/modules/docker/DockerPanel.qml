// Docker containers: filterable list on the left, details and actions on the right.
//
// Keys: Enter starts, stops or unpauses, Ctrl+R restarts, Ctrl+L switches between
// the details and the live logs, Ctrl+E opens a shell in a terminal, Shift+Delete
// removes a stopped container (twice).

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
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
  readonly property string currentId: root.current?.id ?? ""
  readonly property var stats: DockerData.stats[root.currentId]
  readonly property var info: DockerData.detailId === root.currentId ? DockerData.detail : ({})
  property bool removeArmed: false
  property bool envShown: false
  // "details" or "logs".
  property string view: "details"

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
  rowSubtitle: c => `${c.project ? `${c.project}  •  ` : ""}${c.image}  •  ${c.status}`

  onActiveChanged: {
    DockerData.sampling = root.active;
    if (root.active) {
      DockerData.refresh();
      root.sync();
    } else {
      root.setView("details");
      DockerData.loadDetail(null);
    }
  }
  onCurrentChanged: root.removeArmed = false
  onCurrentIdChanged: {
    root.envShown = false;
    if (root.active) root.sync();
  }
  onCloseRequested: GlobalState.closeDocker()
  onAccepted: root.toggle()

  onKeyPressed: event => {
    const ctrl = event.modifiers & Qt.ControlModifier;
    if (ctrl && event.key === Qt.Key_R) root.act("restart");
    else if (ctrl && event.key === Qt.Key_L) root.toggleLogs();
    else if (ctrl && event.key === Qt.Key_E) root.shell();
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

  // Points the per-container streams at the selection.
  function sync() {
    DockerData.loadDetail(root.current);
    if (root.view === "logs") DockerData.followLogs(root.current);
  }

  function setView(view) {
    root.view = view;
    if (view === "logs") DockerData.followLogs(root.current);
    else DockerData.stopLogs();
  }

  function toggleLogs() {
    if (root.current) root.setView(root.view === "logs" ? "details" : "logs");
  }

  function act(action) {
    if (root.current) DockerData.act(action, root.current);
  }

  function toggle() {
    const state = root.current?.state;
    root.act(state === "running" ? "stop" : state === "paused" ? "unpause" : "start");
  }

  // A shell needs a real terminal; everything else stays in the panel.
  function shell() {
    if (!root.current || !root.running) return;
    DockerData.openTerminal("shell", root.current);
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

  function envLines() {
    return (root.info.env ?? []).join("\n");
  }

  function fields() {
    const c = root.current;
    if (!c) return [];
    const d = root.info;
    const rows = [
      { label: "Image", value: c.image },
      { label: "State", value: c.state, color: root.stateColor(c.state) },
    ];
    if (d.health) rows.push({ label: "Health", value: d.health, color: d.health === "healthy" ? Style.colors.green : Style.colors.red });
    if (root.running && root.stats) {
      rows.push({ label: "CPU", value: `${root.stats.cpu.toFixed(1)}%` });
      rows.push({ label: "Memory", value: `${root.stats.memory}  (${root.stats.memPercent.toFixed(1)}%)` });
    }
    rows.push({ label: "Ports", value: c.ports || "None" });
    for (const link of DockerData.portLinks(c.ports))
      rows.push({ label: "Open", value: `localhost:${link.port}`, open: link.url });
    rows.push({ label: "Project", value: c.project || "None" });
    rows.push({ label: "Created", value: c.created });
    if (d.restarts > 0) rows.push({ label: "Restarts", value: `${d.restarts}`, color: Style.colors.yellow });
    if (d.command) rows.push({ label: "Command", value: d.command, copy: d.command });
    if (d.networks?.length) rows.push({ label: "Networks", value: d.networks.join("\n") });
    if (d.mounts?.length) rows.push({ label: "Mounts", value: d.mounts.join("\n") });
    rows.push({ label: "ID", value: c.id, copy: c.id });
    return rows;
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
      tip: root.running ? "Stop (Enter)" : root.current?.state === "paused" ? "Unpause (Enter)" : "Start (Enter)"
      onActivated: root.toggle()
    },
    IconButton {
      visible: root.running
      glyph: "\u{F0709}"
      tip: "Restart (Ctrl+R)"
      onActivated: root.act("restart")
    },
    IconButton {
      visible: root.current !== null
      glyph: "\u{F09A8}"
      tip: root.view === "logs" ? "Back to details (Ctrl+L)" : "Live logs (Ctrl+L)"
      checked: root.view === "logs"
      onActivated: root.toggleLogs()
    },
    IconButton {
      visible: root.running
      glyph: "\u{F018D}"
      tip: "Shell in a terminal (Ctrl+E)"
      onActivated: root.shell()
    },
    IconButton {
      visible: root.current !== null && !root.running
      glyph: "\u{F01B4}"
      label: root.removeArmed ? "Remove?" : ""
      tip: "Remove, press twice (Shift+Del)"
      danger: true
      checked: root.removeArmed
      onActivated: root.remove()
    }
  ]

  Item {
    anchors.fill: parent
    visible: root.current !== null

    Flickable {
      id: details
      anchors.fill: parent
      visible: root.view === "details"
      clip: true
      contentWidth: width
      contentHeight: detailColumn.implicitHeight
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      ColumnLayout {
        id: detailColumn
        width: details.width
        spacing: Style.spacing.p3

        FieldList {
          Layout.fillWidth: true
          fields: root.fields()
          onCopied: text => Quickshell.clipboardText = text
          onOpened: url => Qt.openUrlExternally(url)
        }

        Sparkline {
          Layout.fillWidth: true
          Layout.preferredHeight: Style.system.sparkHeight * 2
          visible: root.running && (DockerData.cpuHistory[root.currentId]?.length ?? 0) > 1
          values: DockerData.cpuHistory[root.currentId] ?? []
          maxValue: 100
          maxSamples: DockerData.historyLength
          tint: Style.colors.accent
        }

        // Project-wide actions, for containers started by compose.
        RowLayout {
          Layout.fillWidth: true
          visible: (root.current?.project ?? "") !== ""
          spacing: Style.spacing.p2

          Text {
            text: `Project ${root.current?.project ?? ""}`
            color: Style.colors.brightBlack
            font.family: Style.font.main
            font.pointSize: Style.font.large
          }
          IconButton {
            glyph: "\u{F040A}"
            label: "Start all"
            tip: "Start every container in this project"
            onActivated: DockerData.actProject("start", root.current.project)
          }
          IconButton {
            glyph: "\u{F04DB}"
            label: "Stop all"
            tip: "Stop every container in this project"
            onActivated: DockerData.actProject("stop", root.current.project)
          }
          IconButton {
            glyph: "\u{F0709}"
            label: "Restart all"
            tip: "Restart every container in this project"
            onActivated: DockerData.actProject("restart", root.current.project)
          }
        }

        // Environment values are often secrets, so they stay hidden until asked for.
        Text {
          Layout.fillWidth: true
          visible: (root.info.env?.length ?? 0) > 0
          text: `${root.envShown ? "▾" : "▸"} Environment (${root.info.env?.length ?? 0})`
          color: envArea.containsMouse ? Style.colors.accent : Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.large

          MouseArea {
            id: envArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: root.envShown = !root.envShown
          }
          Tip {
            text: root.envShown ? "Hide environment variables" : "Show environment variables"
            hovered: envArea.containsMouse
          }
        }
        Text {
          Layout.fillWidth: true
          visible: root.envShown
          text: root.envLines()
          textFormat: Text.PlainText
          wrapMode: Text.WrapAnywhere
          color: Style.colors.white
          font.family: Style.font.main
          font.pointSize: Style.font.normal
        }

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

    // Live output of the selected container.
    Rectangle {
      anchors.fill: parent
      visible: root.view === "logs"
      color: Style.colors.gray1
      border.width: Style.bar.borderWidth
      border.color: Style.colors.gray3

      Flickable {
        id: logs
        anchors.fill: parent
        anchors.margins: Style.spacing.p2
        clip: true
        contentWidth: width
        contentHeight: logText.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        // Follows the newest line until the user scrolls up.
        property bool follow: true
        onMovingChanged: if (!moving) logs.follow = logs.atYEnd
        onContentHeightChanged: if (logs.follow) logs.contentY = Math.max(0, logs.contentHeight - logs.height)

        TextEdit {
          id: logText
          width: logs.width
          readOnly: true
          selectByMouse: true
          text: DockerData.logText
          wrapMode: TextEdit.WrapAnywhere
          color: Style.colors.white
          selectionColor: Style.colors.accent
          selectedTextColor: Style.colors.onAccent
          font.family: Style.font.main
          font.pointSize: Style.font.small
        }
      }

      Text {
        anchors.centerIn: parent
        visible: DockerData.logText === ""
        text: "No output yet"
        color: Style.colors.brightBlack
        font.family: Style.font.main
        font.pointSize: Style.font.large
      }
    }
  }
}
