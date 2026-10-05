// ┌────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀█░█▀█░▀█▀░▀█▀░█▀▀░█░█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█░█░█░█░░█░░░█░░█▀▀░░█░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░░▀░░▀▀▀░▀░░░░▀░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>       ├┤
// ││ Repo    : https://github.com/roosta/dotfiles ││
// ││ Site    : https://www.roosta.sh              ││
// ├┤ License : GNU General Public License v3      ├┤
// ┆└──────────────────────────────────────────────┘┆

import qs.components
import qs.config
import qs.services
import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Button {
  id: root
  Layout.bottomMargin: Style.bar.borderWidth
  implicitWidth: implicitHeight
  implicitHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2

  Layout.rightMargin: Style.spacing.p1
  property bool active: Notifications?.list.length > 0 ?? false
  property bool menuOpen: GlobalState.launcherOpen
    && GlobalState.launcherMode === "notifications"
  required property string monitorId

  MouseArea {
    id: mouseArea
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    x: -Style.spacing.p1
    y: -Style.spacing.p1
    implicitWidth: parent.width + (Style.spacing.p1 * 2) + Style.bar.borderWidth
    implicitHeight: parent.height + (Style.spacing.p1 * 2)  + Style.bar.borderWidth

    onClicked: (mouse) => {
      if (mouse.button === Qt.RightButton) {
      } else if (mouse.button === Qt.LeftButton) {
        GlobalState.toggleLauncher({
          id: root.monitorId, mode: "notifications",
          direction: Qt.RightToLeft,
        })
      }
    }
  }
  states: [
    State {
      name: "open"
      when: root.menuOpen && !mouseArea.containsMouse && !root.active
      PropertyChanges {
        rect.borderColor: Style.colors.brightBlack
      }

    },
    State {
      name: "openActive"
      when: root.menuOpen && !mouseArea.containsMouse && root.active
      PropertyChanges {
        quad.bottomLeft:  Qt.point(0.5, 1)
        quad.bottomRight: Qt.point(0.5, 1)
        quad.topLeft:     Qt.point(0, 0)
        quad.topRight:    Qt.point(1, 0)
        quad.gradientEnabled: true
        dot.y: 5
      }
      PropertyChanges { rect.borderColor: Style.colors.brightBlack }
    },
    State {
      name: "openActiveHovered"
      when: root.menuOpen && mouseArea.containsMouse && root.active
      PropertyChanges {
        quad.gradientEnabled: true

        quad.bottomLeft:  Qt.point(0.5, 1)
        quad.bottomRight: Qt.point(0.5, 1)
        quad.topLeft:     Qt.point(0, 0)
        quad.topRight:    Qt.point(1, 0)
        dot.y: 5
      }
      PropertyChanges { rect.borderColor: Style.colors.brightWhite }
    },
    State {
      name: "openHovered"
      when: root.menuOpen && mouseArea.containsMouse && !root.active
      PropertyChanges {
        rect.borderColor: Style.colors.brightWhite
      }
    },
    State {
      name: "active"
      when: root.active && !mouseArea.containsMouse && !root.menuOpen
      PropertyChanges {
      }
      PropertyChanges {
        rect.borderColor: Style.colors.gray5
        quad.bottomLeft:  Qt.point(0.5, 1)
        quad.bottomRight: Qt.point(0.5, 1)
        quad.topLeft:     Qt.point(0, 0)
        quad.topRight:    Qt.point(1, 0)
        dot.y: 5
      }
    },
    State {
      name: "activeHovered"
      when: root.active && mouseArea.containsMouse && !root.menuOpen
      PropertyChanges {
        quad.gradientEnabled: true
        quad.bottomLeft:  Qt.point(0.5, 1)
        quad.bottomRight: Qt.point(0.5, 1)
        quad.topLeft:     Qt.point(0, 0)
        quad.topRight:    Qt.point(1, 0)
        dot.y: 5
      }
      PropertyChanges { rect.borderColor: Style.colors.brightBlack }
    },
    State {
      name: "hovered"
      when: mouseArea.containsMouse && !root.active && !root.menuOpen
      PropertyChanges { rect.borderColor: Style.colors.gray6 }

    }
  ]

  transitions: [
    Transition {
      NumberAnimation {
        properties: "y"
        duration: Style.durations.normal
        easing.type: Easing.OutCubic
      }
      ColorAnimation {
        duration: Style.durations.small
        easing.type: Easing.OutQuad
      }
    }
  ]
  background: GradientRect {
    id: rect
    color: Style.colors.black
    borderColor: Style.colors.gray3
    borderWidth: Style.bar.borderWidth
    anchors.fill: parent

    Quad {
      id: quad
      width: 20
      height: 18
      topLeft:  Qt.point(0.5, 0)
      topRight: Qt.point(0.5, 0)
      anchors.centerIn: parent
      gradientEnabled: true
      strokeColor: Style.colors.brightBlack
      gradientStart: Style.colors.yellow
      gradientEnd: Style.colors.cyan
      gradientRotation: 90
      Behavior on bottomLeft  { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
      Behavior on bottomRight { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
      Behavior on topLeft  { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
      Behavior on topRight { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
      Rectangle {
        id: dot
        width: 4
        height: 4
        radius: 4
        y: 10
        // Lit while anything is stored, with one short pulse per new arrival.
        // Not an endless loop: stored notifications survive restarts, so a
        // loop would keep every bar window repainting at 60fps indefinitely.
        color: root.active ? Style.colors.brightWhite : Style.colors.brightBlack
        Behavior on color { ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad } }
        anchors.horizontalCenter: parent.horizontalCenter

        SequentialAnimation {
          id: pulse
          NumberAnimation { target: dot; property: "scale"; to: 1.75; duration: Style.durations.small; easing.type: Easing.OutCubic }
          NumberAnimation { target: dot; property: "scale"; to: 1; duration: Style.durations.medium; easing.type: Easing.InOutCubic }
        }

        property int count: Notifications.list.length
        property int lastCount: 0
        onCountChanged: {
          if (count > lastCount) pulse.restart()
          lastCount = count
        }
        Component.onCompleted: lastCount = count
      }
    }
  }
}
