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
// Opens the notification list. A triangle, flipped while anything is stored, with the
// count beside it and one short pulse per new arrival.

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
  implicitWidth: Math.max(implicitHeight, row.implicitWidth + Style.spacing.p2 * 2)
  implicitHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2

  Layout.rightMargin: Style.spacing.p1
  readonly property int count: Notifications?.list.length ?? 0
  property bool active: root.count > 0
  property bool menuOpen: GlobalState.launcherOpen
    && GlobalState.launcherMode === "notifications"
  required property string monitorId

  MouseArea {
    id: mouseArea
    acceptedButtons: Qt.LeftButton
    cursorShape: Qt.PointingHandCursor
    hoverEnabled: true

    x: -Style.spacing.p1
    y: -Style.spacing.p1
    implicitWidth: parent.width + (Style.spacing.p1 * 2) + Style.bar.borderWidth
    implicitHeight: parent.height + (Style.spacing.p1 * 2)  + Style.bar.borderWidth

    onClicked: GlobalState.toggleLauncher({
      id: root.monitorId, mode: "notifications",
      direction: Qt.RightToLeft,
    })
  }

  background: GradientRect {
    color: Style.colors.black
    borderColor: {
      if (mouseArea.containsMouse) return Style.colors.brightWhite;
      if (root.menuOpen) return Style.colors.accent;
      return root.active ? Style.colors.lineStrong : Style.colors.line;
    }
    borderWidth: Style.bar.borderWidth
    anchors.fill: parent

    Behavior on borderColor { ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad } }
  }

  contentItem: Row {
    id: row
    spacing: Style.spacing.p1

    // The triangle flips and its dot rises while anything is stored.
    Item {
      id: bell
      objectName: "bell"
      anchors.verticalCenter: parent.verticalCenter
      implicitWidth: quad.width
      implicitHeight: quad.height
      readonly property bool lit: root.active

      Quad {
        id: quad
        width: 20
        height: 18
        gradientEnabled: true
        strokeColor: Style.colors.brightBlack
        gradientStart: Style.colors.yellow
        gradientEnd: Style.colors.cyan
        gradientRotation: 90
        topLeft:     bell.lit ? Qt.point(0, 0) : Qt.point(0.5, 0)
        topRight:    bell.lit ? Qt.point(1, 0) : Qt.point(0.5, 0)
        bottomLeft:  bell.lit ? Qt.point(0.5, 1) : Qt.point(0, 1)
        bottomRight: bell.lit ? Qt.point(0.5, 1) : Qt.point(1, 1)
        Behavior on topLeft     { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
        Behavior on topRight    { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
        Behavior on bottomLeft  { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }
        Behavior on bottomRight { PropertyAnimation { duration: Style.durations.small; easing.type: Easing.InOutQuad } }

        Rectangle {
          id: dot
          width: 4
          height: 4
          radius: 4
          anchors.horizontalCenter: parent.horizontalCenter
          y: bell.lit ? 5 : 10
          color: bell.lit ? Style.colors.brightWhite : Style.colors.brightBlack
          Behavior on y { NumberAnimation { duration: Style.durations.normal; easing.type: Easing.OutCubic } }
          Behavior on color { ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad } }
        }
      }

      // One pulse per arrival, not a loop: stored notifications survive
      // restarts, and a loop would repaint every bar window forever.
      SequentialAnimation {
        id: pulse
        NumberAnimation { target: dot; property: "scale"; to: 1.75; duration: Style.durations.small; easing.type: Easing.OutCubic }
        NumberAnimation { target: dot; property: "scale"; to: 1; duration: Style.durations.medium; easing.type: Easing.InOutCubic }
      }

      property int lastCount: 0
      Connections {
        target: root
        function onCountChanged() {
          if (root.count > bell.lastCount) pulse.restart()
          bell.lastCount = root.count
        }
      }
      Component.onCompleted: lastCount = root.count
    }

    Text {
      objectName: "badge"
      visible: root.active
      anchors.verticalCenter: parent.verticalCenter
      text: root.count > 99 ? "99+" : root.count
      font.family: Style.font.main
      font.pointSize: Style.font.small
      font.bold: true
      color: Style.colors.brightWhite
    }
  }

  Tip {
    text: "Notifications"
    hovered: mouseArea.containsMouse
  }
}
