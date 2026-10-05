// Audio dropdown from the bar's speaker: outputs, inputs and per-app volumes.
// Clicking a device makes it the default; the sliders and mute buttons act on
// the device or app they sit beside.

pragma ComponentBehavior: Bound

import qs
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  id: root
  required property string monitorId

  anchors.top: parent.top
  anchors.topMargin: Style.bar.height
  anchors.right: parent.right
  anchors.rightMargin: Style.spacing.p1

  implicitWidth: Style.audio.width
  implicitHeight: Style.audio.height

  // The slide happens inside these bounds.
  clip: true

  readonly property bool active: GlobalState.audioOpen
    && GlobalState.audioMonitorId === root.monitorId

  // Only render while on-screen or mid-transition.
  visible: panel.y > -Style.audio.height

  component SectionTitle: Text {
    Layout.fillWidth: true
    Layout.topMargin: Style.spacing.p1
    color: Style.colors.brightWhite
    font.family: Style.font.main
    font.pointSize: Style.font.small
    font.bold: true
  }

  component MuteButton: Rectangle {
    id: mute
    property bool muted: false
    signal activated()

    implicitWidth: Style.font.size4 + Style.spacing.p1 * 2
    implicitHeight: Style.audio.rowHeight
    color: area.containsMouse ? Style.colors.gray2 : "transparent"

    Text {
      anchors.centerIn: parent
      text: mute.muted ? "\u{F075F}" : "\u{F057E}"
      color: mute.muted ? Style.colors.red : area.containsMouse ? Style.colors.brightWhite : Style.colors.white
      font.family: Style.font.symbols
      font.pixelSize: Style.font.size2
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mute.activated()
    }
  }

  // A device row: picks the default, and carries its volume and mute.
  component DeviceRow: ColumnLayout {
    id: device
    objectName: "device"
    required property var node
    required property bool isDefault
    signal chosen()

    Layout.fillWidth: true
    spacing: 0

    Rectangle {
      Layout.fillWidth: true
      implicitHeight: Style.audio.rowHeight
      color: rowArea.containsMouse ? Style.colors.gray1 : "transparent"

      MouseArea {
        id: rowArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        onClicked: device.chosen()
      }

      RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Style.spacing.p1
        spacing: Style.spacing.p1

        Text {
          text: device.isDefault ? "\u{F0126}" : "\u{F043D}"
          color: device.isDefault ? Style.colors.accent : Style.colors.brightBlack
          font.family: Style.font.symbols
          font.pixelSize: Style.font.size2
        }
        Text {
          Layout.fillWidth: true
          text: AudioData.deviceLabel(device.node)
          elide: Text.ElideRight
          color: device.isDefault ? Style.colors.brightWhite : Style.colors.white
          font.family: Style.font.main
          font.pointSize: Style.font.small
        }
        MuteButton {
          visible: device.node.audio !== null
          muted: device.node.audio?.muted ?? false
          onActivated: device.node.audio.muted = !device.node.audio.muted
        }
      }
    }

    VolumeSlider {
      visible: device.isDefault && device.node.audio !== null
      Layout.fillWidth: true
      Layout.leftMargin: Style.spacing.p1
      Layout.rightMargin: Style.spacing.p1
      value: device.node.audio?.volume ?? 0
      onMoved: v => device.node.audio.volume = v
    }
  }

  component VolumeSlider: Slider {
    id: slider
    signal moved(real v)
    from: 0
    to: 1
    implicitHeight: Style.spacing.p4
    onMoved: slider.moved(slider.value)

    HoverHandler { cursorShape: Qt.PointingHandCursor }

    background: Rectangle {
      x: slider.leftPadding
      y: slider.topPadding + slider.availableHeight / 2 - height / 2
      width: slider.availableWidth
      height: Style.spacing.p2
      color: Style.colors.line

      Rectangle {
        width: slider.visualPosition * parent.width
        height: parent.height
        color: Style.colors.accent
      }
    }
    handle: Rectangle {
      x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
      y: slider.topPadding + slider.availableHeight / 2 - height / 2
      implicitWidth: Style.spacing.p3
      implicitHeight: Style.spacing.p4
      color: slider.pressed ? Style.colors.brightWhite : Style.colors.white
    }
  }

  BorderRect {
    id: panel

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: Style.audio.height

    // 0 == fully open, -Style.audio.height == fully hidden behind the bar.
    y: root.active ? 0 : -Style.audio.height

    color: Style.colors.black
    borderColor: Style.colors.line
    borderWidth: Style.bar.borderWidth

    Behavior on y {
      NumberAnimation {
        duration: Style.durations.small
        easing.type: Easing.InOutCubic
      }
    }

    // Swallow clicks so they don't reach shell.qml's close-on-click-outside.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    Flickable {
      anchors.fill: parent
      anchors.margins: Style.spacing.p2
      contentHeight: body.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      ColumnLayout {
        id: body
        width: parent.width
        spacing: Style.spacing.p1

        SectionTitle { text: "Output" }
        Repeater {
          model: AudioData.sinks
          delegate: DeviceRow {
            required property var modelData
            node: modelData
            isDefault: modelData === AudioData.sink
            onChosen: AudioData.setDefaultSink(modelData)
          }
        }
        Text {
          visible: AudioData.sinks.length === 0
          text: "No output devices"
          color: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }

        SectionTitle { text: "Input" }
        Repeater {
          model: AudioData.sources
          delegate: DeviceRow {
            required property var modelData
            node: modelData
            isDefault: modelData === AudioData.source
            onChosen: AudioData.setDefaultSource(modelData)
          }
        }
        Text {
          visible: AudioData.sources.length === 0
          text: "No input devices"
          color: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }

        SectionTitle { text: "Apps" }
        Repeater {
          model: AudioData.appStreams
          delegate: ColumnLayout {
            id: app
            objectName: "app"
            required property var modelData
            Layout.fillWidth: true
            spacing: 0

            RowLayout {
              Layout.fillWidth: true
              Layout.leftMargin: Style.spacing.p1
              spacing: Style.spacing.p1

              Text {
                Layout.fillWidth: true
                text: AudioData.appLabel(app.modelData)
                elide: Text.ElideRight
                color: Style.colors.white
                font.family: Style.font.main
                font.pointSize: Style.font.small
              }
              MuteButton {
                visible: app.modelData.audio !== null
                muted: app.modelData.audio?.muted ?? false
                onActivated: app.modelData.audio.muted = !app.modelData.audio.muted
              }
            }
            VolumeSlider {
              visible: app.modelData.audio !== null
              Layout.fillWidth: true
              Layout.leftMargin: Style.spacing.p1
              Layout.rightMargin: Style.spacing.p1
              value: app.modelData.audio?.volume ?? 0
              onMoved: v => app.modelData.audio.volume = v
            }
          }
        }
        Text {
          visible: AudioData.appStreams.length === 0
          text: "Nothing is playing"
          color: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
      }
    }
  }
}
