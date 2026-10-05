// ┌───────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░░░░▀█▀░█▀▄░█▀█░█░█░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░░░█░░█▀▄░█▀█░░█░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░░░▀░░▀░▀░▀░▀░░▀░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀───────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>      ├┤
// ││ Repo    : https://github.com/roosta/dotfiles││
// ││ Site    : https://www.roosta.sh             ││
// ├┤ License : GNU General Public License v3     ├┤
// ┆└─────────────────────────────────────────────┘┆

pragma ComponentBehavior: Bound
import qs.components
import qs.modules.tray
import QtQuick
import Quickshell.Services.SystemTray
import qs


ExpandingButton {
  id: root
  buttonLabel: SystemTray.items.values.length
  preventAutoClose: GlobalState.trayMenuOpen
  isEmpty: SystemTray.items.values.length === 0
  Repeater {
    id: items
    model: root.active ? SystemTray.items : null
    visible: root.active
    TrayItem { monitorId: root.monitorId }
  }
}
