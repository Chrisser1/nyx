// Network, via services/NetworkData.qml. Shows wifi signal strength when the
// active device is wireless, a plug when wired, and dims when there is no
// connectivity. The label next to it is the SSID on wifi and the interface on
// ethernet. Clicking drops modules/network/WifiPanel.qml out of the bar.
//
// The lazily-populated-ObjectModel workaround this used to carry now lives in
// NetworkData, so the panel and the bar share one set of trackers.

import QtQuick
import QtQuick.Layouts
import Quickshell.Networking
import qs
import qs.services
import qs.config

Rectangle {
  id: root
  required property string monitorId

  readonly property bool panelShown: GlobalState.wifiOpen
    && GlobalState.wifiMonitorId === root.monitorId

  readonly property bool online: Networking.connectivity === NetworkConnectivity.Full

  // Sized off the layout, not childrenRect: the MouseArea below fills the
  // parent, so childrenRect.width would be a binding loop.
  implicitWidth: layout.implicitWidth
  implicitHeight: parent.height
  color: "transparent"

  MouseArea {
    id: mouseArea
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: GlobalState.toggleWifi(root.monitorId)
  }

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p0

    Text {
      text: {
        if (NetworkData.activeDevice === null) return "󰤭";   // disconnected
        if (!NetworkData.isWifi) return "󰈁";                  // wired
        return NetworkData.signalIcon(NetworkData.strength);
      }
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      color: {
        if (mouseArea.containsMouse || root.panelShown) return Style.colors.accent;
        if (NetworkData.activeDevice === null) return Style.colors.brightBlack;
        if (!root.online) return Style.colors.brightYellow;   // portal / limited
        return Style.colors.white;
      }
      Layout.alignment: Qt.AlignVCenter

      Behavior on color {
        ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
      }
    }

    Text {
      // Nothing connected: the dimmed icon says it on its own, so stay silent
      // rather than reserving width for a placeholder.
      visible: NetworkData.label !== ""
      text: NetworkData.label
      font.family: Style.font.main
      font.pointSize: Style.font.small
      color: Style.colors.white
      // A long SSID must not push the clock around; 140px fits most of them.
      elide: Text.ElideRight
      Layout.maximumWidth: 140
      Layout.alignment: Qt.AlignVCenter
      Layout.leftMargin: Style.spacing.p1
    }
  }
}
