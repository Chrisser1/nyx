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
  // As wide as the label needs, so what follows sits right after it.
  implicitWidth: rowLayout.implicitWidth
  implicitHeight: rowLayout.implicitHeight
  RowLayout {
    id: rowLayout
    anchors.fill: parent
    spacing: Style.spacing.p1
    BorderRect {
      color: "transparent"
      borderColor: Style.colors.line
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
        objectName: "title"
        Layout.fillWidth: true
        elide: Text.ElideRight
        font {
          family: Style.font.light
          pointSize: Style.font.small
        }

        color: Style.colors.brightWhite
        text: ContextData.data.title
      }
      Text {
        id: window
        objectName: "desc"
        elide: Text.ElideRight
        Layout.fillWidth: true
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
