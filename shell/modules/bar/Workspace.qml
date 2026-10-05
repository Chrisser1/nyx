// ┌────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░█░█▀█░█▀▄░█░█░█▀▀░█▀█░█▀█░█▀▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▄█░█░█░█▀▄░█▀▄░▀▀█░█▀▀░█▀█░█░░░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░▀░▀░▀░▀░▀▀▀░▀░░░▀░▀░▀▀▀░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                   ├┤
// ││ Repo    : https://github.com/roosta/dotfiles             ││
// ││ Site    : https://www.roosta.sh                          ││
// ├┤ License : GNU General Public License v3                  ├┤
// ┆└──────────────────────────────────────────────────────────┘┆

pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects

import QtQuick.Controls
import Quickshell.Widgets
import Quickshell.Hyprland
import qs.services
import qs.config
import qs.components
import qs.utils

Button {
  id: root
  required property bool isOccupied
  required property string workspaceAddress
  required property string activeWorkspaceAddress
  required property var modelData
  required property string monitorId
  property bool active: activeWorkspaceAddress === workspaceAddress
  property bool urgent: {
    return HyprlandData.urgentWindows.some(win => {
      return win.workspace.address === root.workspaceAddress
    })
  }
  property bool isSpecial: modelData?.type === "special"
  property bool specialActive: HyprlandData.monitors.some(m => {
    return m.name === root.monitorId
      && (m?.specialWorkspace?.address ?? "") === root.workspaceAddress
  })

  // Icon list for this workspace. Only reassigned when it actually changes:
  // windowList is replaced on every Hyprland event, and handing the Repeater a
  // fresh (if identical) array would rebuild every icon each time.
  property var wsIcons: []
  function refreshIcons(): void {
    const next = Icons.getWsIcons(root.workspaceAddress)
    if (JSON.stringify(next) !== JSON.stringify(root.wsIcons))
      root.wsIcons = next
  }
  onWorkspaceAddressChanged: refreshIcons()
  Component.onCompleted: refreshIcons()
  Connections {
    target: HyprlandData
    function onWindowListChanged() { root.refreshIcons() }
  }

  property int buttonSize: 26 * Config.scale
  property int iconSize: 16 * Config.scale
  property int calculatedWidth: {
    if (root.isOccupied) {
      let iconCount = root.wsIcons.length;
      return iconCount * (root.iconSize + Style.spacing.p3);
    } else {
      return root.iconSize + Style.spacing.p3;
    }
  }

  onPressed: {
    if (isSpecial) {
      const n = root.workspaceAddress.split(":")[1] ?? ""
      Hyprland.dispatch(`hl.dsp.workspace.toggle_special("${n}")`)
    } else if (workspaceAddress !== activeWorkspaceAddress) {
      const sel = HyprlandData.selectorFor(root.workspaceAddress)
      Hyprland.dispatch(`hl.dsp.focus({ workspace = "${sel}" })`)
    }
  }
  HoverHandler {
    id: hover
    cursorShape: root.active ? Qt.ArrowCursor : Qt.PointingHandCursor
  }

  background: GradientRect {
    id: wsBackground
    implicitWidth: root.calculatedWidth
    implicitHeight: childrenRect.height
    radius: Style.bar.radius
    color: "transparent"
    borderColor: {
      if (!root.isOccupied)
        return Style.colors.black
      if (root.urgent)
        return (hover.hovered && !root.active) ? Style.colors.gray6 : Style.colors.gray2
      return (root.active || hover.hovered) ? Style.colors.brightBlack : Style.colors.gray2
    }

    // gradientAngle: 45
    property Gradient activeGradient: Gradient {
      orientation: Gradient.Horizontal
      GradientStop { position: 1; color: Style.colors.cyan }
      GradientStop { position: 0; color: Style.colors.white }
    }
    gradient: activeGradient
    gradientActive: root.isSpecial && root.specialActive
    dashed: root.isSpecial
    borderWidth: Style.bar.borderWidth

    Behavior on borderColor {
      ColorAnimation {
        duration: Style.durations.hover
        easing.type: Easing.OutQuad
      }
    }

    Loader {
      active: !root.isOccupied
      sourceComponent: indicator
    }
    Component {
      id: indicator
      Item {
        implicitWidth: root.iconSize + Style.spacing.p3
        implicitHeight: Style.bar.height - Style.bar.borderWidth
        - Style.spacing.p1 * 2

        Rectangle {
          id: circle
          anchors.centerIn: parent
          width: root.buttonSize * 0.25
          height: width
          radius: width / 2
          color: (root.hovered || root.active) ? Style.colors.brightWhite : Style.colors.gray6
          Behavior on color {
            ColorAnimation {
              duration: Style.durations.small
              easing.type: Easing.OutQuad
            }
          }
        }
      }
    }

    Loader {
      active: root.isOccupied
      sourceComponent: iconGroup
    }
    Component {
      id: iconGroup
      RowLayout {
        spacing: 0
        Repeater {
          model: root.wsIcons
          Item {
            required property var modelData
            property bool urgent:  {
              return HyprlandData.urgentWindows.some(win => {
                return root.urgent && win.class === modelData.class
              })
            }

            id: appIcon
            Layout.preferredWidth: root.iconSize + Style.spacing.p3
            Layout.preferredHeight: Style.bar.height - Style.bar.borderWidth - Style.spacing.p1 * 2

            SequentialAnimation {
              id: blinkAnimation
              running: appIcon.urgent
              loops: Animation.Infinite
              onRunningChanged: if (!running) desaturatedIcon.opacity = 1.0

              PropertyAnimation {
                target: desaturatedIcon
                property: "opacity"
                from: 1.0
                to: 0.3
                duration: Style.durations.normal
                easing.type: Easing.InOutQuad
              }
              PropertyAnimation {
                target: desaturatedIcon
                property: "opacity"
                from: 0.3
                to: 1.0
                duration: Style.durations.normal
                easing.type: Easing.InOutQuad
              }
            }

            // Blink target for both variants below.
            Item {
              id: desaturatedIcon
              implicitWidth: root.iconSize
              implicitHeight: root.iconSize
              anchors.centerIn: parent

              // Regular workspaces draw the icon directly. Only scratch icons
              // need the MultiEffect (greyed out unless the scratch is shown),
              // and an effect pass per icon on every bar is not free.
              IconImage {
                visible: !root.isSpecial
                anchors.fill: parent
                source: appIcon.modelData.icon
                implicitSize: root.iconSize
              }

              Loader {
                active: root.isSpecial
                anchors.fill: parent
                sourceComponent: MultiEffect {
                  saturation: root.specialActive ? 0.0 : -1.0
                  Behavior on saturation {
                    NumberAnimation {
                      duration: Style.durations.small
                      easing.type: Easing.OutCubic
                    }
                  }
                  source: IconImage {
                    source: appIcon.modelData.icon
                    implicitSize: root.iconSize
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
