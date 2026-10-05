// ┌──────────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀▄░▀█▀░▀█▀░█░█░█▀█░█░░░░░█▀▀░█░█░█▀▀░█░░░█░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▀▄░░█░░░█░░█░█░█▀█░█░░░░░▀▀█░█▀█░█▀▀░█░░░█░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░░▀░░▀▀▀░▀░▀░▀▀▀░░░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀──────────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                             ├┤
// ││ Repo    : https://github.com/roosta/dotfiles                       ││
// ││ Site    : https://www.roosta.sh                                    ││
// ├┤ License : GNU General Public License v3                            ├┤
// ┆└────────────────────────────────────────────────────────────────────┘┆
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma UseQApplication
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic

pragma ComponentBehavior: Bound
import Quickshell
import qs.modules.bar
import qs.modules.launcher
import qs.modules.calendar
import qs.modules.network
import qs.modules.media
import qs.modules.system
import qs.modules.tray
import QtQuick
import Quickshell.Wayland
import Quickshell.Hyprland
import qs.components
import qs.utils
import qs.config
import qs.services
import qs

ShellRoot {
  // Registered here, outside the Variants, so it exists once rather than once
  // per monitor. The panel itself is per-monitor; the shortcut only has to pick
  // which one, which is what GlobalState.toggleWifi takes.
  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleWifi"
    description: "Toggles the wifi panel"
    onPressed: GlobalState.toggleWifi(Hyprland.focusedMonitor?.name ?? Config.primaryDisplay)
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleSystem"
    description: "Toggles the system panel"
    onPressed: GlobalState.toggleSys(Hyprland.focusedMonitor?.name ?? Config.primaryDisplay)
  }

  Variants {
    model: Quickshell.screens
    delegate: Scope {
      id: scope
      required property ShellScreen modelData
      property string monitorId: modelData?.name ?? ""
      readonly property string activeWorkspaceAddress: HyprlandData
        .activeWorkspaceAddressFor(monitorId)
      property var windows: HyprlandData.windowsByWorkspace[activeWorkspaceAddress] ?? []

      NamedPanel {
        id: exclusion
        WlrLayershell.layer: WlrLayer.Bottom
        name: "exclusion"
        screen: scope.modelData
        anchors.top: true
        anchors.left: true
        anchors.right: true

        // One commit on open, one on close — Hyprland animates the windows.
        // Animating this would relayout every window on the monitor per frame.
        exclusiveZone: GlobalState.launcherOpen && GlobalState.launcherMonitorId === scope.monitorId
          ? Style.bar.height + Style.launcher.height
          : Style.bar.height
      }

      NamedPanel {
        id: main
        name: "main"
        screen: scope.modelData

        WlrLayershell.exclusionMode: ExclusionMode.Ignore
        // OnDemand, not Exclusive, and for every overlay: the focus grab below
        // hands this window the keyboard while one is open, which is what lets
        // the Escape shortcut reach it. Text fields still take it on click.
        WlrLayershell.keyboardFocus: GlobalState.overlayOpen
        ? WlrKeyboardFocus.OnDemand
        : WlrKeyboardFocus.None

        // Window-wide, so it wins over whichever field has focus: Escape in the
        // launcher or the wifi password box closes everything too.
        Shortcut {
          sequence: "Escape"
          enabled: GlobalState.overlayOpen
          onActivated: GlobalState.closeAll()
        }

        HyprlandFocusGrab {
          id: grab
          windows: [main]
          active: (GlobalState.launcherOpen && GlobalState.launcherMonitorId === scope.monitorId)
            || (GlobalState.calendarOpen && GlobalState.calendarMonitorId === scope.monitorId)
            || (GlobalState.wifiOpen && GlobalState.wifiMonitorId === scope.monitorId)
            || (GlobalState.sysOpen && GlobalState.sysMonitorId === scope.monitorId)
            || (GlobalState.mediaOpen && GlobalState.mediaMonitorId === scope.monitorId)
          // Deliberately empty, for every overlay. Hyprland fires `cleared`
          // immediately after the grab activates, so closing from here shuts
          // the panel the moment it opens. Click-outside is handled instead by
          // the MouseArea on `content` below: this window is fullscreen and
          // holds the grab, so every click is "inside" it and reaches that.
          onCleared: {
          }
        }

        // Pass through clicks unless overlay is open
        mask: Region {
          id: mask
          x: 0
          y: 0
          width: main.width
          height: main.height

          intersection: {
            if (GlobalState.overlayOpen) {
              Intersection.Combine
            } else {
              Intersection.Xor
            }
          }
          regions: [

            // Lets the bar be usable when overlay is open
            Region {
              x: bar.x
              y: bar.y
              width: bar.width
              height: bar.height
              intersection: {
                if (GlobalState.overlayOpen) {
                  Intersection.Combine
                } else {
                  Intersection.Subtract
                }
              }
            },

            // Lets the toast message be usable with overlay open
            Region {
              x: toast.x
              y: toast.y
              width: toast.implicitWidth
              height: toast.implicitHeight
              intersection: {
                if (Notifications.popupList.length) {
                  Intersection.Subtract
                } else {
                  Intersection.Combine
                }
              }

            }
          ]
        }

        anchors {
          bottom: true
          left: true
          right: true
          top: true
        }
        Rectangle {
          id: content
          color: "transparent"
          anchors.fill: parent
          transitions: [
            Transition {
              ColorAnimation {
                duration: Style.durations.medium
                easing.type: Easing.OutQuad
              }
            }
          ]
          MouseArea {
            anchors.fill: parent
            onClicked: GlobalState.closeAll()
          }
          states: [
            State {
              name: "open"
              // Only the monitor the launcher/tray menu is actually on dims.
              when: ((GlobalState.launcherOpen && GlobalState.launcherMonitorId === scope.monitorId)
                  || (GlobalState.trayMenuOpen && Hyprland.focusedMonitor?.name === scope.monitorId))
                && scope.windows.length > 0
              PropertyChanges { content.color: Functions.transparentize("#000", 0.7) }
            }
          ]

        }
        Bar {
          id: bar
          monitorId: scope.monitorId
          onDecrementCurrentIndex: launcher.decrementCurrentIndex()
          onIncrementCurrentIndex: launcher.incrementCurrentIndex()
          onOpenDrawer: launcher.openDrawer()
          onCloseDrawer: launcher.closeDrawer()
          onDrawerNext: launcher.drawerNext()
          onDrawerPrev: launcher.drawerPrev()
          onDrawerActivate: launcher.drawerActivate()
          onAccepted: launcher.accepted()
        }

        Launcher {
          id: launcher
          monitorId: scope.monitorId
        }

        CalendarPanel {
          monitorId: scope.monitorId
        }

        WifiPanel {
          monitorId: scope.monitorId
        }

        SysPanel {
          monitorId: scope.monitorId
        }

        MediaPanel {
          monitorId: scope.monitorId
        }

        Osd {
          monitorId: scope.monitorId
        }

        Toast {
          id: toast
          monitorId: scope.monitorId
          menuRect: trayMenu.item ? trayMenu.item.menuRect : Qt.rect(0,0,0,0)

        }

        Loader {
          id: trayMenu
          anchors.fill: parent
          active: GlobalState.trayMenuOpen

          sourceComponent: TrayMenu {
            Component.onCompleted: this.open();
            trayItemMenuHandle: GlobalState.activeMenu
            onMenuClosed: GlobalState.closeTrayMenu()
            monitorId: scope.monitorId
          }
        }
      }
    }
  }
}
