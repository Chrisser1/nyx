// Hover hint. Parent it to a button and bind `hovered` to its MouseArea; it
// shows after a short rest, and stays hidden while `text` is empty.

import QtQuick
import QtQuick.Controls
import qs.config

ToolTip {
  id: root

  property bool hovered: false

  delay: 500
  font.family: Style.font.main
  font.pointSize: Style.font.normal
  visible: root.hovered && root.text !== ""

  contentItem: Text {
    text: root.text
    font: root.font
    color: Style.colors.brightWhite
  }
  background: BorderRect {
    color: Style.colors.gray1
  }
}
