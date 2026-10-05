// CPU and RAM readout, from the ResourceUsage service.

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config

Rectangle {
  id: root
  implicitWidth: childrenRect.width
  implicitHeight: parent.height
  color: "transparent"

  component Stat: RowLayout {
    id: stat
    required property string glyph
    required property real value      // 0.0 - 1.0, drives the tint only
    required property string label    // what actually gets rendered
    required property color tint
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
      color: Style.colors.white
      font.family: Style.font.main
      font.pointSize: Style.font.small
      Layout.alignment: Qt.AlignVCenter
    }
  }

  RowLayout {
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p2

    Stat {
      glyph: ""   // cpu
      value: ResourceUsage.cpuUsage
      // Fixed width so the bar doesn't reflow as the number changes width.
      label: `${Math.round(ResourceUsage.cpuUsage * 100)}%`.padStart(4, " ")
      tint: ResourceUsage.cpuUsage > 0.8 ? Style.colors.brightRed : Style.colors.brightBlue
    }
    Stat {
      glyph: "󰍛"   // memory
      value: ResourceUsage.memoryUsedPercentage
      // Used out of total, e.g. "12.4/31.3G". Padded for the same reason.
      label: `${ResourceUsage.memoryUsedGb.padStart(4, " ")}/${ResourceUsage.memoryTotalGb}G`
      tint: ResourceUsage.memoryUsedPercentage > 0.9 ? Style.colors.brightRed : Style.colors.brightGreen
    }
  }
}
