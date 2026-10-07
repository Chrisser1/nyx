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
import qs.config


ExpandingButton {
  id: root
  // What the tray shows: everything but the ids hidden in the config.
  readonly property var shown: SystemTray.items.values.filter(i => !Host.trayHidden.includes((i.id ?? "").toLowerCase()))
  buttonLabel: root.shown.length
  preventAutoClose: GlobalState.trayMenuOpen
  isEmpty: root.shown.length === 0
  tint: Style.colors.magenta
  tip: "System tray"
  Repeater {
    id: items
    model: root.active ? root.shown : null
    visible: root.active
    TrayItem { monitorId: root.monitorId }
  }
}
