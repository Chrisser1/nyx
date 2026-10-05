// Mirror displays: pick the output that should show another one's picture, then
// which output it copies. Enter takes the first source (or stops a mirror).

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

  readonly property var sources: root.current ? MonitorData.sources(root.current.name) : []
  readonly property bool mirrored: root.current?.mirrorOf !== undefined && root.current.mirrorOf !== "none"

  active: GlobalState.mirrorOpen && GlobalState.mirrorMonitorId === root.monitorId
  title: "Mirror displays"
  placeholder: "Filter outputs…"
  emptyText: "No outputs found"
  entries: MonitorData.rows.filter(m => m.enabled && m.name.toLowerCase().includes(root.query.toLowerCase()))
  detailTitle: root.current?.name ?? ""
  detailSubtitle: root.current?.desc ?? ""

  rowGlyph: e => "\u{F0379}"
  rowGlyphColor: e => e.mirrorOf !== "none" ? Style.colors.green : Style.colors.brightBlack
  rowTitle: e => e.name
  rowSubtitle: e => e.mirrorOf !== "none" ? `Showing ${e.mirrorOf}` : e.mode

  onActiveChanged: if (root.active) MonitorData.refresh()
  onCloseRequested: GlobalState.closeMirror()
  onAccepted: root.apply(root.mirrored ? "" : root.sources[0]?.name ?? "")

  // An empty source stops the mirror.
  function apply(source) {
    if (!root.current) return;
    if (source === "") MonitorData.unmirror(root.current.name);
    else MonitorData.mirror(source, root.current.name);
  }

  actions: [
    Repeater {
      model: root.mirrored ? [] : root.sources
      IconButton {
        required property var modelData
        objectName: "source"
        glyph: "\u{F0379}"
        label: `Show ${modelData.name}`
        onActivated: root.apply(modelData.name)
      }
    },
    IconButton {
      objectName: "stop"
      visible: root.mirrored
      glyph: "\u{F0156}"
      label: "Stop mirroring"
      danger: true
      onActivated: root.apply("")
    }
  ]

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.p3
    visible: root.current !== null

    FieldList {
      Layout.fillWidth: true
      fields: root.current ? [
        { label: "Output", value: root.current.name },
        { label: "Mode", value: root.current.mode },
        { label: "Position", value: root.current.pos },
        { label: "Showing", value: root.mirrored ? root.current.mirrorOf : "its own picture" }
      ] : []
    }

    Item { Layout.fillHeight: true }

    Text {
      Layout.fillWidth: true
      text: root.mirrored
        ? "Enter stops mirroring on this output"
        : root.sources.length === 0
          ? "No other output to copy"
          : "Choose which output this one should copy · Enter takes " + root.sources[0].name
      wrapMode: Text.Wrap
      color: Style.colors.brightBlack
      font.family: Style.font.main
      font.pointSize: Style.font.small
    }
  }
}
