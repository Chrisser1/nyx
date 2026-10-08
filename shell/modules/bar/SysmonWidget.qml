// CPU and RAM readout, from the ResourceUsage service. Each stat is tinted by
// load: muted while idle, then yellow, orange and red as it climbs, with a thin
// bar underneath showing the share. It has no Behaviors on purpose: any of
// them kept the bar redrawing at ~120 fps while idle.

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config

Rectangle {
  id: root
  implicitWidth: childrenRect.width
  implicitHeight: parent.height
  color: "transparent"

  // Load tint, shared by the glyph, the number past 60% and the bar.
  function loadTint(v) {
    if (v > 0.9) return Style.colors.red;
    if (v > 0.75) return Style.colors.orange;
    if (v > 0.6) return Style.colors.yellow;
    return Style.colors.green;
  }

  component Stat: ColumnLayout {
    id: stat
    objectName: "stat"
    required property string glyph
    required property real value      // 0.0 - 1.0
    required property string label    // what actually gets rendered
    readonly property color tint: root.loadTint(stat.value)
    spacing: 1

    RowLayout {
      spacing: Style.spacing.p0
      Text {
        text: stat.glyph
        color: stat.tint
        font.family: Style.font.symbols
        font.pointSize: Style.font.small
        Layout.alignment: Qt.AlignVCenter
      }
      Text {
        text: stat.label
        color: stat.value > 0.6 ? stat.tint : Style.colors.white
        font.family: Style.font.main
        font.pointSize: Style.font.small
        Layout.alignment: Qt.AlignVCenter
      }
    }

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: 2 * Config.scale
      color: Style.colors.gray3
      Rectangle {
        width: parent.width * Math.min(1, Math.max(0, stat.value))
        height: parent.height
        color: stat.tint
      }
    }
  }

  RowLayout {
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p3

    Separator {}
    Stat {
      glyph: "󰻠"   // cpu
      value: ResourceUsage.cpuUsage
      // Fixed width so the bar doesn't reflow as the number changes width.
      label: `${Math.round(ResourceUsage.cpuUsage * 100)}%`.padStart(4, " ")
    }
    Stat {
      glyph: "󰍛"   // memory
      value: ResourceUsage.memoryUsedPercentage
      // Used out of total, e.g. "12.4/31.3G". Padded for the same reason.
      label: `${ResourceUsage.memoryUsedGb.padStart(4, " ")}/${ResourceUsage.memoryTotalGb}G`
    }
  }
}
