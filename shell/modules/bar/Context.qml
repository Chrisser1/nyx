// ┌────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀▀░█▀█░█▀█░▀█▀░█▀▀░█░█░▀█▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█░░░█░█░█░█░░█░░█▀▀░▄▀▄░░█░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀▀▀░▀▀▀░▀░▀░░▀░░▀▀▀░▀░▀░░▀░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>           ├┤
// ││ Repo    : https://github.com/roosta/dotfiles     ││
// ││ Site    : https://www.roosta.sh                  ││
// ├┤ License : GNU General Public License v3          ├┤
// ┆└──────────────────────────────────────────────────┘┆

import qs.services
import qs.config
import qs.components
import QtQuick
import QtQuick.Layouts
import Quickshell.Widgets

Item {
  id: root
  implicitWidth: 200
  RowLayout {
    id: rowLayout
    anchors.fill: parent
    spacing: Style.spacing.p1
    BorderRect {
      color: "transparent"
      borderColor: Style.colors.gray3
      borderWidth: Style.bar.borderWidth
      implicitHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2
      implicitWidth: implicitHeight
      IconImage {
        id: windowIcon
        anchors.fill: parent
        anchors.centerIn: parent
        anchors.margins: 4
        source: ContextData.data.icon
        // implicitSize: parent.height - Style.spacing.p3
      }
    }
    ColumnLayout {
      id: colLayout
      Layout.fillWidth: true
      spacing: -2
      Text {

        font {
          family: Style.font.light
          pointSize: Style.font.small
        }

        color: Style.colors.brightWhite
        text: ContextData.data.title
      }
      Text {
        id: window
        elide: Text.ElideRight
        Layout.fillWidth: true
        Layout.rightMargin: Style.spacing.p5
        font {
          family: Style.font.light
          pointSize: Style.font.tiny
        }

        color: Style.colors.white
        text: ContextData.data.desc
      }
    }
  }
}
