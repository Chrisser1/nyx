// ┌───────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░░█▀█░█░█░█▀▄░▀█▀░█▀█░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░█▀█░█░█░█░█░░█░░█░█░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░▀░▀░▀▀▀░▀▀░░▀▀▀░▀▀▀░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀───────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>      ├┤
// ││ Repo    : https://github.com/roosta/dotfiles││
// ││ Site    : https://www.roosta.sh             ││
// ├┤ License : GNU General Public License v3     ├┤
// ┆└─────────────────────────────────────────────┘┆

pragma ComponentBehavior: Bound
import qs.config
import qs.services
import qs.components
import qs
import QtQuick
import QtQuick.Layouts

import QtQuick.Controls

ExpandingButton {
  id: root

  property bool muted: AudioData.ready && AudioData.sink.audio.muted
  property string mutedIcon: ""

  // Falls back to a generic speaker rather than "" — an empty label collapses
  // both this button and srcBtn to zero width, which is how the output picker
  // ended up unclickable. Any sink sinkIcon() does not recognise
  // lands here.
  readonly property string fallbackIcon: "󰓃"

  function getSinkIcon(sink) {
    if (!sink) { return root.fallbackIcon }
    const obj = Config.outputs.find(o => o.sink === sink.name);
    return (obj && obj.icon) ? obj.icon : root.fallbackIcon
  }
  buttonLabel: muted ? mutedIcon : getSinkIcon(AudioData.sink)
  // Green while sound can come out, red once muted.
  tint: root.muted ? Style.colors.red : Style.colors.green

  // Expands when scrolled, not on every volume change: volume keys already get
  // the Osd, and expanding here re-laid out the bar on every monitor per tap.
  function peek() {
    root.active = true
    timer.restart()
  }

  Timer {
    id: timer
    running: false
    interval: 1000 * 10
    onTriggered: {
      root.active = false
    }
  }

  onRightClick: () => GlobalState.toggleAudio(root.monitorId)

  wheelHandler: (event) => {
    root.peek()
    if (event.angleDelta.y > 0) {
      AudioData.incrementVolume()
    } else if (event.angleDelta.y < 0) {
      AudioData.decrementVolume()
    }
  }

  BorderRect {
    id: srcBtn
    visible: root.active
    implicitWidth: srcBtnText.implicitWidth + Style.spacing.p2 * 2
    implicitHeight: srcBtnText.implicitHeight
    color: Style.colors.black
    states: [
      State {
        name: "hovered"
        when: srcMouse.containsMouse
        PropertyChanges { srcBtnText.color: Style.colors.brightWhite }
        PropertyChanges { srcMouse.cursorShape: Qt.PointingHandCursor }
      }
    ]
    MouseArea {
      id: srcMouse
      hoverEnabled: true
      anchors.fill: parent
      onClicked: GlobalState.toggleAudio(root.monitorId)
    }

    transitions: [
      Transition {
        ColorAnimation {
          duration: Style.durations.small
          easing.type: Easing.OutQuad
        }
      }
    ]
    Text {
      anchors.centerIn: parent
      id: srcBtnText
      text: root.buttonLabel
      color: root.tint
      font {
        family: Style.font.light
        pixelSize: Style.font.size3
      }
    }
  }
  BorderRect {
    id: inputBtn
    visible: root.active
    implicitWidth: inputBtnText.implicitWidth + Style.spacing.p2 * 2
    implicitHeight: inputBtnText.implicitHeight
    color: Style.colors.black
    states: [
      State {
        name: "hovered"
        when: inputMouse.containsMouse
        PropertyChanges { inputBtnText.color: Style.colors.brightWhite }
        PropertyChanges { inputMouse.cursorShape: Qt.PointingHandCursor }
      }
    ]
    MouseArea {
      id: inputMouse
      hoverEnabled: true
      anchors.fill: parent
      onClicked: AudioData.toggleSourceMute()
    }

    transitions: [
      Transition {
        ColorAnimation {
          duration: Style.durations.small
          easing.type: Easing.OutQuad
        }
      }
    ]
    Text {
      anchors.centerIn: parent
      id: inputBtnText
      color: AudioData.source?.audio?.muted ? Style.colors.red : Style.colors.green
      text: {
        if (AudioData.source?.audio?.muted) {
          return "󰍭"
        } else {
          return ""
        }
      }
      font {
        family: Style.font.light
        pixelSize: Style.font.size3
      }
    }
  }

  Slider {
    id: volumeSlider
    visible: root.active
    implicitWidth: Style.bar.sliderWidth
    from: 0.0
    value: AudioData.sink?.audio.volume ?? 0
    onMoved: AudioData.sink.audio.volume = value
    to: 1.0
    HoverHandler {
      cursorShape: Qt.PointingHandCursor
    }
    background: Rectangle {
      x: volumeSlider.leftPadding
      y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
      implicitWidth: 200
      implicitHeight: Style.spacing.p3
      width: volumeSlider.availableWidth
      height: implicitHeight
      color: Style.colors.line

      Rectangle {
        width: volumeSlider.visualPosition * parent.width
        height: parent.height
        gradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 1; color: Style.colors.magenta }
          GradientStop { position: 0; color: Style.colors.blue }
        }
      }
    }
    handle: Rectangle {
      x: volumeSlider.leftPadding + volumeSlider.visualPosition * (volumeSlider.availableWidth - width)
      y: volumeSlider.topPadding + volumeSlider.availableHeight / 2 - height / 2
      implicitWidth: Style.spacing.p4
      implicitHeight: Style.spacing.p3
      radius: 0
      color: volumeSlider.pressed ? Style.colors.brightMagenta : Style.colors.magenta
      // border.color: Style.colors.magenta
    }
  }
}
