// ┌───────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░░█▀▀░█░░░█▀█░█▀▀░█░█░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░█░░░█░░░█░█░█░░░█▀▄░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀───────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>      ├┤
// ││ Repo    : https://github.com/roosta/dotfiles││
// ││ Site    : https://www.roosta.sh             ││
// ├┤ License : GNU General Public License v3     ├┤
// ┆└─────────────────────────────────────────────┘┆

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.config

Rectangle {
  id: root
  required property string monitorId

  readonly property bool calendarShown: GlobalState.calendarOpen
    && GlobalState.calendarMonitorId === root.monitorId

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
    onClicked: GlobalState.toggleCalendar(root.monitorId)
  }

  ColumnLayout {
    id: layout
    implicitHeight: Style.bar.height - Style.spacing.p1 * 2
    spacing: -2
    anchors.verticalCenter: parent.verticalCenter
    Text {
      Layout.alignment: Qt.AlignRight
      font {
        family: Style.font.light
        pointSize: Style.font.small
      }

      color: mouseArea.containsMouse || root.calendarShown
        ? Style.colors.accent
        : Style.colors.brightWhite
      text: Time.time

      Behavior on color {
        ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
      }
    }
    Text {
      Layout.alignment: Qt.AlignRight
      font {
        family: Style.font.light
        pointSize: Style.font.tiny
      }

      color: Style.colors.white
      text: Time.date
    }
  }


}

