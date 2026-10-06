// Running-container count; hidden while nothing runs or fails, red while a container is
// restarting or unhealthy. Opens the Docker panel.

import QtQuick
import QtQuick.Layouts
import qs
import qs.config
import qs.components
import qs.services

Rectangle {
  id: root
  required property string monitorId

  visible: DockerData.running > 0 || DockerData.troubled.length > 0
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
      color: area.containsMouse ? Style.colors.brightWhite
        : DockerData.troubled.length > 0 ? Style.colors.red : Style.colors.brightBlue
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

  Tip {
    text: [`Docker: ${DockerData.running} running`,
      ...DockerData.troubled.map(c => `${c.name}: ${c.state === "running" ? "unhealthy" : c.state}`)].join("\n")
    hovered: area.containsMouse
  }
}
