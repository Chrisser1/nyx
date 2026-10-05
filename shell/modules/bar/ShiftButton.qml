import QtQuick
import Quickshell.Wayland
import qs.services
import qs.components
import Quickshell.Hyprland
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
import Quickshell.Io
pragma ComponentBehavior: Bound

Button {
  id: root
  property int direction: -1

  // Manual press feedback so it survives window-focus grab changes
  property bool active: false

  Timer {
    id: pressFlash
    interval: 100
    onTriggered: root.active = false
  }

  required property string monitorId

  readonly property string activeWorkspaceAddress: HyprlandData
    .activeWorkspaceAddressFor(monitorId)
  property var workspaces: HyprlandData.workspacesByMonitor[monitorId] ?? []
  property var persistent: workspaces.filter(w => w.ispersistent)

  HoverHandler {
    id: hover
    cursorShape: Qt.PointingHandCursor
  }
  states: [
    State {
      name: "pressed"
      when: root.active

      PropertyChanges {
        triangle.strokeColor: Style.colors.brightWhite
      }
    },
    State {
      name: "hovered"
      when: hover.hovered
      PropertyChanges {
        triangle.strokeColor: Style.colors.brightBlack
      }
    }
  ]


  // Custom move window dispatcher, I need to disable mouse warp while doing
  // workspace moves via this button, otherwise the mouse cursor snaps to middle
  // of active window on every button press, but I want it enabled otherwise
  Process {
    id: moveWindow
    running: false
    property string wsAddress: ""
    command: [Host.hyprctl, "eval", `hl.config({cursor = { no_warps = true }}); hl.dispatch(hl.dsp.window.move({ workspace = "${wsAddress}", window = 'activewindow', follow = true })); hl.config({cursor = { no_warps = false }})
    `]
  }

  onPressed: {
    root.active = true
    pressFlash.restart()

    // Only numbered workspaces shift; their address is the number as a string.
    const current = /^\d+$/.test(root.activeWorkspaceAddress)
      ? Number(root.activeWorkspaceAddress) : 0
    if (current === 0) { return }
    let move = current + root.direction
    let focusedMonitor = Hyprland.focusedMonitor?.name ?? ""
    if (focusedMonitor !== Config.displays.center) { return }

    if (move > persistent.length) {
      if (direction < 0) {
        move = persistent.length
      } else { return }
    }
    if (move > 0) {
      moveWindow.wsAddress = String(move)
      moveWindow.running = true
    }
  }

  transitions: [
    Transition {
      ColorAnimation {
        duration: Style.durations.hover
        easing.type: Easing.OutQuad
      }
    }
  ]

  Layout.preferredHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2
  Layout.preferredWidth: 23
  background: Rectangle {
    anchors.fill: parent
    color: "transparent"
    Triangle {
      id: triangle
      height: 20

      anchors.right: root.direction > 0 ? parent.right : undefined
      width: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2
      rotation: root.direction > 0 ? 90 : 270
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
