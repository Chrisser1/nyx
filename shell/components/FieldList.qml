// Label/value rows for detail panes. Fields are { label, value, color?, copy? };
// clicking a field with `copy` emits copied() with that text, and one with
// `open` (a URL) emits opened().

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.config

ColumnLayout {
  id: root

  property var fields: []
  signal copied(string text)
  signal opened(string url)

  spacing: Style.spacing.p2

  Repeater {
    model: root.fields

    delegate: Item {
      id: field
      required property var modelData
      Layout.fillWidth: true
      implicitHeight: value.implicitHeight

      Text {
        id: label
        width: Style.clipboard.rowHeight * 2
        text: field.modelData.label
        color: Style.colors.brightBlack
        font.family: Style.font.main
        font.pointSize: Style.font.large
      }
      Text {
        id: value
        anchors.left: label.right
        anchors.right: parent.right
        text: field.modelData.value
        wrapMode: Text.WrapAnywhere
        color: area.containsMouse ? Style.colors.accent : (field.modelData.color ?? Style.colors.brightWhite)
        font.family: Style.font.main
        font.pointSize: Style.font.large
      }
      MouseArea {
        id: area
        anchors.fill: value
        enabled: field.modelData.copy !== undefined || field.modelData.open !== undefined
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: {
          if (field.modelData.open !== undefined) root.opened(field.modelData.open);
          else root.copied(field.modelData.copy);
        }
      }
    }
  }
}
