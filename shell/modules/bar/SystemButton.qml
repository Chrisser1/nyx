// Opens the system panel (modules/system/SysPanel.qml). Took over the slot the
// keyboard-layout button used to hold: hyprland.nix declares a single kb_layout,
// so there was never a second layout for it to cycle to.
//
// Same BorderRect chrome as AlertsIndicator next to it; the open-state tint is
// the idiom NetworkWidget uses for the wifi dropdown.

pragma ComponentBehavior: Bound
import qs
import qs.config
import qs.services
import qs.components
import QtQuick
import QtQuick.Layouts

BorderRect {
  id: root
  color: Style.colors.black
  borderColor: Style.colors.gray3
  borderWidth: Style.bar.borderWidth
  Layout.bottomMargin: Style.bar.borderWidth

  required property string monitorId

  readonly property bool panelShown: GlobalState.sysOpen
    && GlobalState.sysMonitorId === root.monitorId

  implicitWidth: layout.implicitWidth + Style.spacing.p1 * 2
  implicitHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2

  MouseArea {
    id: button
    hoverEnabled: true
    anchors.fill: parent
    onClicked: GlobalState.toggleSys(root.monitorId)
  }

  states: [
    State {
      name: "hovered"
      when: button.containsMouse && !button.pressed
      PropertyChanges { root.borderColor: Style.colors.gray6 }
      PropertyChanges { button.cursorShape: Qt.PointingHandCursor }
    },
    State {
      name: "pressed"
      when: button.pressed && button.containsMouse
      PropertyChanges { root.borderColor: Style.colors.gray6 }
      PropertyChanges { button.cursorShape: Qt.PointingHandCursor }
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
      Layout.preferredWidth: Style.font.size3
      Layout.preferredHeight: Style.font.size3
      color: "transparent"

      Text {
        anchors.centerIn: parent
        // The same gauge the panel's header carries, so the button and what it
        // opens read as one thing.
        text: "󰊚"
        color: {
          if (root.panelShown) return Style.colors.accent;
          // Match the bar's own warning: the strip is the quickest way to see
          // what is eating the machine, so say so before it is clicked.
          if (ResourceUsage.cpuUsage > 0.8) return Style.colors.brightRed;
          return Style.colors.white;
        }
        font {
          family: Style.font.symbols
          pixelSize: Style.font.size3
        }

        Behavior on color {
          ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
        }
      }
    }
  }
}
