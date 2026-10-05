// Bluetooth, via services/BluetoothData.qml. Hidden when the host has no adapter.
//
// The lazily-populated-ObjectModel workaround this used to carry now lives in
// BluetoothData, so the bar and the system panel share one set of trackers.

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config

Rectangle {
  id: root

  visible: BluetoothData.hasAdapter
  // Sized off the layout, not childrenRect: childrenRect.width depends on this
  // item's own width, which is a binding loop (Qt warns at every startup).
  implicitWidth: BluetoothData.hasAdapter ? layout.implicitWidth : 0
  implicitHeight: parent.height
  color: "transparent"

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p0

    Text {
      text: BluetoothData.enabled
        ? (BluetoothData.connectedDevices.length > 0 ? "" : "")
        : ""
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      color: {
        if (!BluetoothData.enabled) return Style.colors.brightBlack;
        return BluetoothData.connectedDevices.length > 0 ? Style.colors.brightBlue : Style.colors.white;
      }
      Layout.alignment: Qt.AlignVCenter
    }
    Text {
      visible: BluetoothData.connectedDevices.length > 1
      text: BluetoothData.connectedDevices.length
      font.family: Style.font.main
      font.pointSize: Style.font.tiny
      color: Style.colors.white
      Layout.alignment: Qt.AlignVCenter
    }
  }
}
