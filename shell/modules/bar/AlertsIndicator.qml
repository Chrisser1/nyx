// ┌────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀█░█░░░█▀▀░█▀▄░▀█▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▀█░█░░░█▀▀░█▀▄░░█░░▀▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░▀▀▀░▀░▀░░▀░░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>       ├┤
// ││ Repo    : https://github.com/roosta/dotfiles ││
// ││ Site    : https://www.roosta.sh              ││
// ├┤ License : GNU General Public License v3      ├┤
// ┆└──────────────────────────────────────────────┘┆

pragma ComponentBehavior: Bound
import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

import QtQuick.Controls

BorderRect {
  id: root
  color: Style.colors.black
  borderColor: Style.colors.gray3
  borderWidth: Style.bar.borderWidth
  Layout.bottomMargin: Style.bar.borderWidth
  // Fade rather than pop; `visible` only drops once the fade has finished,
  // so the row reflows once instead of at both ends of the animation.
  opacity: Alerts.hasAlerts ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Style.durations.small; easing.type: Easing.OutCubic } }

  required property string monitorId

  implicitWidth: layout.implicitWidth + Style.spacing.p1 * 2
  implicitHeight: Style.bar.height - Style.spacing.p3
  MouseArea {
    id: mouseArea
    // Hover styling only -- the individual icons own the click handlers, so
    // don't advertise the whole strip as clickable.
    hoverEnabled: true
    anchors.fill: parent
  }
  Behavior on implicitWidth {
    NumberAnimation {
      duration: Style.durations.small
      easing.type: Easing.OutCubic
    }
  }
  states: [
    State {
      name: "hovered"
      when: mouseArea.containsMouse && !mouseArea.pressed
      PropertyChanges { root.borderColor: Style.colors.gray4 }
    },
    State {
      name: "pressed"
      when: mouseArea.pressed && mouseArea.containsMouse
      PropertyChanges { root.borderColor: Style.colors.gray6 }
    }
  ]
  transitions: Transition {
    ColorAnimation { duration: Style.durations.hover; easing.type: Easing.OutQuad }
  }
  RowLayout {
    id: layout
    spacing: Style.spacing.p1
    anchors.fill: parent
    anchors.leftMargin: Style.spacing.p1
    anchors.rightMargin: Style.spacing.p1

    Rectangle {
      id: audioIn
      visible: Alerts.audioIn
      color: "transparent"
      Layout.preferredWidth: Style.font.size3
      Layout.preferredHeight: Style.font.size3
      MouseArea {
        id: audioArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: AudioData.toggleSourceMute()
      }
      ToolTip {
        id: audioControl
        font.family: Style.font.main
        delay: 600
        text: `${Alerts.audioInTooltip}\n\nClick to ${AudioData.source?.audio?.muted ? "unmute" : "mute"} the microphone`
        visible: audioArea.containsMouse
        contentItem: Text {
          text: audioControl.text
          font: audioControl.font
          color: Style.colors.brightWhite
        }

        background: BorderRect {
          color: Style.colors.gray1
        }
      }
      Text {
        // Same glyph pair AudioButton's mic toggle uses.
        text: AudioData.source?.audio?.muted ? "󰍭" : ""
        anchors.centerIn: parent
        color: AudioData.source?.audio?.muted ? Style.colors.brightRed : Style.colors.brightYellow
        font {
          family: Style.font.light
          pixelSize: Style.font.size3
        }
      }
    }
    Rectangle {
      id: cpu
      color: "transparent"
      visible: Alerts.cpuUsage
      Layout.preferredWidth: Style.font.size3
      Layout.preferredHeight: Style.font.size3
      MouseArea {
        id: cpuArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor

      }
      ToolTip {
        id: cpuControl
        font.family: Style.font.main
        delay: 600
        text: ResourceUsage.cpuTooltip
        visible: cpuArea.containsMouse
        contentItem: Text {
          text: cpuControl.text
          font: cpuControl.font
          color: Style.colors.brightWhite
        }

        Timer {
          interval: 1000
          running: cpuControl.visible
          repeat: cpuControl.visible
          onTriggered: {
            ResourceUsage.refreshTooltip()
          }
        }
        background: BorderRect {
          color: Style.colors.gray1
        }
      }
      Text {
        text: ""
        anchors.centerIn: parent
        color: Style.colors.yellow
        font {
          family: Style.font.light
          pixelSize: Style.font.size3
        }
      }
    }
  }
}
