// Square glyph button.
import QtQuick
import qs.config

Rectangle {
  id: root

  required property string glyph
  property string label: ""
  property bool danger: false
  property bool checked: false
  signal activated()

  readonly property color tint: root.danger ? Style.colors.red : Style.colors.accent

  implicitWidth: Math.max(implicitHeight, content.implicitWidth + Style.spacing.p2 * 2)
  implicitHeight: Style.font.size4 + Style.spacing.p2 * 2
  color: area.containsMouse || root.checked ? root.tint : Style.colors.gray2

  Behavior on color {
    ColorAnimation { duration: Style.durations.hover; easing.type: Easing.OutQuad }
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.spacing.p1

    Text {
      text: root.glyph
      color: area.containsMouse || root.checked ? Style.colors.onAccent : Style.colors.brightWhite
      font.family: Style.font.symbols
      font.pixelSize: Style.font.size3
      anchors.verticalCenter: parent.verticalCenter
    }
    Text {
      visible: root.label !== ""
      text: root.label
      color: area.containsMouse || root.checked ? Style.colors.onAccent : Style.colors.brightWhite
      font.family: Style.font.main
      font.pointSize: Style.font.normal
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: root.activated()
  }
}
