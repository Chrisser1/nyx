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
  // This monitor's numbered workspaces in order. With split-monitor-workspaces
  // each monitor owns its own range (1-9, 10-18, ...), so "next" is the next
  // one in this list, not the active number plus one.
  readonly property var numbered: (HyprlandData.workspacesByMonitor[monitorId] ?? [])
    .filter(w => w.type !== "special" && /^\d+$/.test(w.address))

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
        triangle.strokeColor: Style.colors.white
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
    property string window: ""
    command: [Host.hyprctl, "eval", `hl.config({cursor = { no_warps = true }}); hl.dispatch(hl.dsp.window.move({ workspace = "${wsAddress}", window = 'address:${window}', follow = true })); hl.config({cursor = { no_warps = false }})`]
  }

  onPressed: {
    root.active = true
    pressFlash.restart()

    // The window that last had focus on this bar's monitor, which is not
    // necessarily the focused window when another monitor has focus.
    const index = root.numbered.findIndex(w => w.address === root.activeWorkspaceAddress)
    const target = root.numbered[index + root.direction]
    const window = root.numbered[index]?.lastwindow ?? ""
    if (index < 0 || !target || window === "" || /^0x0+$/.test(window)) { return }

    moveWindow.wsAddress = target.address
    moveWindow.window = window
    moveWindow.running = true
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
      strokeColor: Style.colors.lineStrong
      height: 20

      anchors.right: root.direction > 0 ? parent.right : undefined
      width: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2
      rotation: root.direction > 0 ? 90 : 270
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
