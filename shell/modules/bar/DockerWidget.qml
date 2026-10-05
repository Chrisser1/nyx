// Running-container count; hidden while nothing runs. Opens the Docker panel.

import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.services

Rectangle {
  id: root
  required property string monitorId

  visible: DockerData.running > 0
  implicitWidth: root.visible ? layout.implicitWidth : 0
  implicitHeight: parent.height
  color: "transparent"

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p0

    Text {
      text: "\u{F0868}"
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      color: area.containsMouse ? Style.colors.brightWhite : Style.colors.brightBlue
      Layout.alignment: Qt.AlignVCenter
    }
    Text {
      text: DockerData.running
      font.family: Style.font.main
      font.pointSize: Style.font.tiny
      color: Style.colors.white
      Layout.alignment: Qt.AlignVCenter
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: GlobalState.toggleDocker(root.monitorId)
  }
}
