// Tailscale state: dim when stopped, accent while routing through an exit node.
// Opens the Tailnet panel.

import QtQuick
import qs
import qs.config
import qs.services

Rectangle {
  id: root
  required property string monitorId

  visible: TailnetData.available
  implicitWidth: root.visible ? glyph.implicitWidth : 0
  implicitHeight: parent.height
  color: "transparent"

  Text {
    id: glyph
    anchors.verticalCenter: parent.verticalCenter
    text: "\u{F0582}"
    font.family: Style.font.symbols
    font.pointSize: Style.font.small
    color: {
      if (area.containsMouse) return Style.colors.brightWhite;
      if (!TailnetData.running) return Style.colors.brightBlack;
      return TailnetData.exitNode ? Style.colors.accent : Style.colors.brightBlue;
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: GlobalState.toggleTailnet(root.monitorId)
  }
}
