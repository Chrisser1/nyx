// ┌────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░░░█▀█░█░█░█▀█░█▀▀░█░█░█▀▀░█▀▄░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█░░░█▀█░█░█░█░█░█░░░█▀█░█▀▀░█▀▄░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>               ├┤
// ││ Repo    : https://github.com/roosta/dotfiles         ││
// ││ Site    : https://www.roosta.sh                      ││
// ├┤ License : GNU General Public License v3              ├┤
// ┆└──────────────────────────────────────────────────────┘┆

pragma ComponentBehavior: Bound
import qs.config
import qs.utils
import qs.components
import qs
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
  required property string monitorId
  id: root

  signal decrementCurrentIndex()
  signal incrementCurrentIndex()
  signal openDrawer()
  signal drawerNext()
  signal drawerPrev()
  signal drawerActivate()
  signal closeDrawer()
  signal accepted()

  property bool active: GlobalState.launcherOpen
  && GlobalState.launcherMonitorId === root.monitorId

  Layout.leftMargin: monitorId === Config.displays.center ? Style.spacing.p1 : 0
  Layout.rightMargin: monitorId === Config.displays.left ? Style.spacing.p1 : 0
  Loader {
    active: root.active
    sourceComponent: fieldComponent
    anchors.fill: parent
    id: fieldLoader
  }

  Loader {
    active: !root.active
    sourceComponent: buttonComponent
    anchors.fill: parent
    id: buttonLoader
  }

  Layout.bottomMargin: Style.bar.borderWidth
  implicitWidth: root.active ? 300 : implicitHeight
  implicitHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Style.durations.small
      easing.type: Easing.OutCubic
    }
  }

  Component {
    id: buttonComponent
    Button {
      property bool visualActive: false
      opacity: visualActive ? 1 : 0
      id: button
      Component.onCompleted: visualActive = true
      Connections {
        target: root
        function onActiveChanged() { button.visualActive = !root.active }
      }
      anchors.fill: parent
      MouseArea {
        id: mouseArea
        acceptedButtons: Qt.LeftButton | Qt.RightButton
        z: 99
        cursorShape: Qt.PointingHandCursor
        hoverEnabled: true
        x: -Style.spacing.p1
        y: -Style.spacing.p1
        implicitWidth: parent.width + (Style.spacing.p1 * 2) + Style.bar.borderWidth
        implicitHeight: parent.height + (Style.spacing.p1 * 2)  + Style.bar.borderWidth

        onClicked: (mouse) => {
          if (mouse.button === Qt.RightButton) {
            GlobalState.toggleLauncher({id: root.monitorId, mode: "menu"})
          } else if (mouse.button === Qt.LeftButton) {
            GlobalState.toggleLauncher({id: root.monitorId })
          }
        }
      }

      background: BorderRect {
        id: outerRect
        anchors.fill: parent
        borderColor: Style.colors.gray3
        borderWidth: Style.bar.borderWidth
        GradientRect {
          id: innerRect

          implicitWidth: button.visualActive ? parent.height - Style.spacing.p1 * 2 : Style.spacing.p1
          implicitHeight: parent.height - Style.spacing.p1 * 2
          // implicitHeight: parent.height - Style.spacing.p1 * 2

          Behavior on rotation {
            NumberAnimation {
              duration: Style.durations.medium
              easing.type: Easing.InOutCubic
            }
          }
          Behavior on implicitWidth {
            NumberAnimation {
              duration: Style.durations.medium
              easing.type: Easing.Linear
            }
          }
          Behavior on implicitHeight {
            NumberAnimation {
              duration: Style.durations.medium
              easing.type: Easing.Linear
            }
          }
          gradientAngle: 45
          rotation: button.visualActive ? 45 : 0
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 1; color: Style.colors.green }
            GradientStop { position: 0; color: Style.colors.blue }
          }
          Rectangle {
            implicitWidth: button.visualActive ? 4 : parent.implicitWidth
            implicitHeight: button.visualActive ? 4 : parent.implicitHeight
            anchors.centerIn: parent
            radius: 4
            color: Style.colors.brightWhite

            Behavior on implicitWidth {
              NumberAnimation {
                duration: Style.durations.medium
                easing.type: Easing.Linear
              }
            }
            Behavior on implicitHeight {
              NumberAnimation {
                duration: Style.durations.medium
                easing.type: Easing.Linear
              }
            }
          }
          anchors.margins: Style.spacing.p1
          anchors.top: parent.top
          anchors.bottom: parent.bottom
          anchors.left: parent.left
          borderWidth: Style.bar.borderWidth
          color: Style.colors.black
          // rotation: 45
          borderColor: Style.colors.white
        }
      }

      NumberAnimation {
        target: innerRect
        running: mouseArea.containsMouse && !root.active
        property: "gradientAngle"
        duration: 1000
        to: 405
        loops: Animation.Infinite;
        easing.type: Easing.Linear
      }

      states: [

        // State {
        //   name: "active"
        //   when: root.active && !hover.hovered
        //   PropertyChanges {
        //     // innerRect.rotation: 0
        //     innerRect.implicitWidth: Style.spacing.p1
        //     innerRect.color: Style.colors.brightWhite
        //     innerRect.borderColor: Style.colors.brightWhite
        //   }
        //   // PropertyChanges { outerRect.borderColor: Style.colors.brightBlack }
        //   // PropertyChanges { innerRect.borderColor: Style.colors.brightWhite }
        // },

        State {
          name: "hovered"
          when: mouseArea.containsMouse && !root.active
          PropertyChanges { outerRect.borderColor: Style.colors.brightBlack }
          PropertyChanges { innerRect.gradientAngle: 360 }
        },

        // State {
        //   name: "activeHovered"
        //   when: hover.hovered && root.active
        //   PropertyChanges { outerRect.borderColor: Style.colors.brightWhite }
        //   PropertyChanges { innerRect.borderColor: Style.colors.brightWhite }
        //   // PropertyChanges { innerRect.rotation: 0 }
        // }
      ]

      transitions: [
        Transition {
          NumberAnimation {
            properties: "implicitWidth,implicitHeight"
            duration: Style.durations.small
            easing.type: Easing.OutCubic
          }
          ColorAnimation {
            duration: Style.durations.medium
            easing.type: Easing.OutCubic
          }
        }
      ]

    }
  }
  Component {
    id: fieldComponent
    TextField {

      Connections {
        target: GlobalState

        function onLauncherOpenChanged() {
          if (GlobalState.launcherOpen && GlobalState.launcherMonitorId === root.monitorId) {
            field.forceActiveFocus();
          }
        }
      }

      color: Style.colors.brightWhite
      id: field
      leftPadding: Style.spacing.p1
      renderType: TextField.NativeRendering
      cursorVisible: !readOnly
      implicitWidth: 200
      placeholderTextColor: Style.colors.gray6
      font.family: Style.font.light
      font.pointSize: Style.font.normal
      placeholderText: "  Search (/ for modes)"
      text: GlobalState.searchQuery
      onTextChanged: {
        if (text === Config.menuPrefix) {
          GlobalState.launcherMode = "menu"
        }
        const m = Config.launcherMenus.find(m => {
          return text.startsWith(`${Config.menuPrefix}/${m.mode}`)
        })
        if (m) {
          GlobalState.launcherMode = m[0]
          GlobalState.searchQuery = ""
        }
        GlobalState.searchQuery = text
      }
      background: Rectangle {
        color: "transparent"
        border.color: Style.colors.gray3
      }

      function goPrevious() {
        if (GlobalState.itemDrawerActive) {
          root.drawerPrev()
        } else if (GlobalState.menuDirection === Qt.LeftToRight) {
          return root.decrementCurrentIndex()
        } else if (GlobalState.menuDirection === Qt.RightToLeft) {
          return root.incrementCurrentIndex()
        }
      }

      function goNext() {
        if (GlobalState.itemDrawerActive) {
          root.drawerNext()
        } else if (GlobalState.menuDirection === Qt.LeftToRight) {
          return root.incrementCurrentIndex()
        } else if (GlobalState.menuDirection === Qt.RightToLeft) {
          return root.decrementCurrentIndex()
        }
      }

      Keys.onEscapePressed: GlobalState.closeLauncher()
      Keys.onRightPressed: goNext()
      Keys.onLeftPressed: goPrevious()
      Keys.onUpPressed: root.openDrawer()
      Keys.onDownPressed: root.closeDrawer()
      Component.onCompleted: forceActiveFocus()
      onAccepted: GlobalState.itemDrawerActive ? root.drawerActivate() : root.accepted()

      // https://github.com/caelestia-dots/shell/blob/fe4ebb79b6162d7e5e4e9a00d8a39ff10876fb8c/modules/launcher/Content.qml#L109
      Keys.onPressed: event => {
        if (event.modifiers & Qt.ControlModifier) {
          if (event.key === Qt.Key_L) {
            goNext();
            event.accepted = true;
          } else if (event.key === Qt.Key_H) {
            goPrevious()
            event.accepted = true;
          } else if (event.key === Qt.Key_K) {
            root.openDrawer()
            event.accepted = true;
          } else if (event.key === Qt.Key_J) {
            root.closeDrawer()
            event.accepted = true;
          }
        } else if (event.key === Qt.Key_Tab && GlobalState.matchCount === 1) {
          root.accepted()
          event.accepted = true;
        } else if (event.key === Qt.Key_Tab) {
          root.incrementCurrentIndex();
          event.accepted = true;
        } else if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && (event.modifiers & Qt.ShiftModifier))) {
          root.decrementCurrentIndex();
          event.accepted = true;
        } else if (event.key == Qt.Key_Backspace && text === "" && GlobalState.launcherMode !== Config.defaultMode) {
          GlobalState.launcherMode = Config.defaultMode
          event.accepted = true
        } else if (event.key == Qt.Key_Backspace && text === "/" && GlobalState.launcherMode === "menu") {
          GlobalState.launcherMode = Config.defaultMode
          field.text = ""
          event.accepted = true
        }
      }

      cursorDelegate: GradientRect {
        id: cursor
        property bool disableBlink
        property bool visualActive: false

        gradientAngle: 45
        rotation: visualActive ? 0 : 45

        property Gradient activeGradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 1; color: Style.colors.green }
          GradientStop { position: 0; color: Style.colors.blue }
        }

        property Gradient cursorGradient: Gradient {
          orientation: Gradient.Horizontal
          GradientStop { position: 1; color: Style.colors.brightWhite }
        }
        gradient: visualActive ? cursorGradient : activeGradient
        implicitWidth: visualActive ? Style.spacing.p1 : parent.height - Style.spacing.p1 * 2
        implicitHeight: parent.height - Style.spacing.p1 * 2

        Rectangle {
          implicitWidth: cursor.visualActive ? parent.implicitWidth : 4
          implicitHeight: cursor.visualActive ? parent.implicitHeight : 4
          // opacity: cursor.visualActive ? 0 : 1
          anchors.centerIn: parent
          radius: cursor.visualActive ? 0 : 4
          color: Style.colors.brightWhite

          Behavior on implicitWidth {
            NumberAnimation {
              duration: Style.durations.medium
              easing.type: Easing.Linear
            }
          }
          Behavior on implicitHeight {
            NumberAnimation {
              duration: Style.durations.medium
              easing.type: Easing.Linear
            }
          }
        }
        Component.onCompleted: visualActive = true

        Connections {
          target: root
          function onActiveChanged() { cursor.visualActive = root.active }
        }

        Connections {
          target: field

          function onCursorPositionChanged(): void {
            if (field.activeFocus && field.cursorVisible) {
              cursor.opacity = 1;
              cursor.disableBlink = true;
              enableBlink.restart();
            }
          }
        }

        Timer {
          running: field.activeFocus && field.cursorVisible && !cursor.disableBlink
          repeat: true
          triggeredOnStart: true
          interval: 500
          onTriggered: parent.opacity = parent.opacity === 1 ? 0 : 1
        }
        Binding {
          when: !field.activeFocus || !field.cursorVisible
          cursor.opacity: 0
        }
        Timer {
          id: enableBlink

          interval: 100
          onTriggered: cursor.disableBlink = false
        }

        Behavior on opacity {
          NumberAnimation {
            duration: Style.durations.medium
            easing.type: Easing.InOutCubic
          }
        }
        Behavior on implicitWidth {
          NumberAnimation {
            duration: Style.durations.medium
            easing.type: Easing.InOutCubic
          }
        }

        Behavior on rotation {
          NumberAnimation {
            duration: Style.durations.medium
            easing.type: Easing.InOutCubic
          }
        }

        Behavior on color {
          ColorAnimation {
            duration: Style.durations.normal
            easing.type: Easing.OutQuad
          }
        }
      }

      Behavior on color {
        ColorAnimation {
          duration: Style.durations.tiny
          easing.type: Easing.OutQuad
        }
      }
      Behavior on placeholderTextColor {
        ColorAnimation {
          duration: Style.durations.tiny
          easing.type: Easing.OutQuad
        }
      }

    }
  }

}
