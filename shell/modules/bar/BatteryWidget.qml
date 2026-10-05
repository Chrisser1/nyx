// Battery, via Quickshell.Services.UPower. Hides itself entirely on machines
// with no battery, so the same bar config works on pc and asusLaptop.

import QtQuick
import QtQuick.Layouts
import Quickshell.Services.UPower
import qs.config

Rectangle {
  id: root

  readonly property var dev: UPower.displayDevice
  readonly property bool present: dev?.isPresent ?? false
  readonly property real pct: dev?.percentage ?? 0
  readonly property bool charging: (dev?.state ?? UPowerDeviceState.Unknown) === UPowerDeviceState.Charging
  readonly property bool full: (dev?.state ?? UPowerDeviceState.Unknown) === UPowerDeviceState.FullyCharged

  visible: present
  // Sized off the layout, not childrenRect: childrenRect.width depends on this
  // item.s own width, which is a binding loop (Qt warns at every startup).
  implicitWidth: present ? layout.implicitWidth : 0
  implicitHeight: parent.height
  color: "transparent"

  // Nerd Font battery ramp, empty -> full.
  readonly property var ramp: ["", "", "", "", ""]

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p0

    Text {
      text: root.charging || root.full ? "" : root.ramp[Math.min(4, Math.floor(root.pct * 5))]
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      color: {
        if (root.charging || root.full) return Style.colors.brightGreen;
        if (root.pct <= 0.15) return Style.colors.brightRed;
        if (root.pct <= 0.30) return Style.colors.brightYellow;
        return Style.colors.white;
      }
      Layout.alignment: Qt.AlignVCenter
    }
    Text {
      text: `${Math.round(root.pct * 100)}%`
      font.family: Style.font.main
      font.pointSize: Style.font.small
      color: Style.colors.white
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
