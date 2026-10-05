// ┌────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░▀▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                       ├┤
// ││ Repo    : https://github.com/roosta/dotfiles                 ││
// ││ Site    : https://www.roosta.sh                              ││
// ├┤ License : GNU General Public License v3                      ├┤
// ┆└──────────────────────────────────────────────────────────────┘┆

import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick.Layouts
import qs.services
import qs.config
import qs.components
pragma ComponentBehavior: Bound

BorderRect {
  id: root
  leftBorder: Style.bar.borderWidth
  rightBorder: Style.bar.borderWidth
  borderColor: Style.colors.gray3
  color: Style.colors.black
  required property string monitorId
  // Latest data from Hyprland, replaced on every event burst.
  readonly property var current: HyprlandData.workspacesByMonitor[monitorId] ?? []
  readonly property var occupied: current.reduce((acc, ws) => {
    acc[ws.address] = ws?.windows > 0;
    return acc;
  }, {})

  // The Repeater model. Only reassigned when the set of workspaces changes:
  // handing it a new (if identical) array destroys and rebuilds every button,
  // and `current` is replaced on every Hyprland event.
  property var workspaces: []
  function syncWorkspaces(): void {
    const key = ws => ws.map(w => `${w.address}:${w.type}`).join(",")
    if (key(root.current) !== key(root.workspaces))
      root.workspaces = root.current
  }
  onCurrentChanged: syncWorkspaces()
  readonly property HyprlandMonitor monitor: Hyprland
    .monitorFor(root.QsWindow.window?.screen)
  readonly property string activeWorkspaceAddress: HyprlandData
    .activeWorkspaceAddressFor(monitorId)

  Behavior on implicitWidth {
    NumberAnimation {
      duration: Style.durations.small
      easing.type: Easing.OutCubic
    }
  }
  implicitWidth: layout.implicitWidth + Style.spacing.p3 + Style.bar.borderWidth * 2
  implicitHeight: Style.bar.height - Style.bar.borderWidth
  Layout.bottomMargin: Style.bar.borderWidth
  radius: Style.bar.radius

  Item {
    id: inner
    anchors.fill: parent

    // Moving active workspace indicator rectangle
    GradientRect {
      id: activeIndicator
      z: 3
      height: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2
      property Gradient activeGradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 1; color: Style.colors.magenta }
        GradientStop { position: 0; color: Style.colors.blue }
      }
      gradientAngle: 45
      borderColor: Style.colors.brightBlack
      gradient: activeGradient
      gradientActive: (root.monitor?.focused ?? false) && !HyprlandData.specialActive
      property real targetX: 0
      property real targetWidth: 0

      function updateIndicator() {
        let x = 0
        let targetIdx = root.workspaces.findIndex(w => {
          return w.address === root.activeWorkspaceAddress
        });

        for (let i = 0; i < targetIdx && i < workspaceRepeater.count; i++) {
          let item = workspaceRepeater.itemAt(i);
          if (item) {
            x += item.calculatedWidth + layout.spacing;
          }
        }

        let activeItem = workspaceRepeater.itemAt(targetIdx);

        if (activeItem) {
          targetX = x;
          targetWidth = activeItem.calculatedWidth;
        }
      }

      // Only the offset within the row animates; the row's own position is
      // added live. The row is centred in a container that resizes on its own
      // timeline, so animating an absolute x drifted off the buttons mid-resize.
      Behavior on targetX {
        NumberAnimation {
          duration: Style.animationCurves.expressiveFastSpatialDuration
          easing.type: Easing.BezierSpline
          easing.bezierCurve: Style.animationCurves.standardDecel
        }
      }

      Behavior on targetWidth {
        NumberAnimation {
          duration: Style.animationCurves.expressiveFastSpatialDuration
          easing.type: Easing.BezierSpline
          easing.bezierCurve: Style.animationCurves.standardDecel
        }
      }

      anchors.verticalCenter: parent.verticalCenter
      x: layout.x + targetX
      width: targetWidth
    }
    RowLayout {
      id: layout
      spacing: Style.spacing.p1
      z: 2
      anchors.centerIn: parent
      Repeater {
        model: root.workspaces
        id: workspaceRepeater

        Workspace {
          monitorId: root.monitorId
          isOccupied: root.occupied[modelData?.address] ?? false
          activeWorkspaceAddress: root.activeWorkspaceAddress;
          workspaceAddress: modelData?.address ?? "";
          onCalculatedWidthChanged: activeIndicator.updateIndicator()
        }
      }
    }

  }

  onActiveWorkspaceAddressChanged: activeIndicator.updateIndicator()
  onWorkspacesChanged: activeIndicator.updateIndicator()
  Component.onCompleted: {
    root.syncWorkspaces();
    activeIndicator.updateIndicator();
  }

}
