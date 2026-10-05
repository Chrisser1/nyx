// ┌──────────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀▀░█░░░█▀█░█▀▄░█▀█░█░░░░░█▀▀░▀█▀░█▀█░▀█▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█░█░█░░░█░█░█▀▄░█▀█░█░░░░░▀▀█░░█░░█▀█░░█░░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀▀▀░▀▀▀░▀▀▀░▀▀░░▀░▀░▀▀▀░░░▀▀▀░░▀░░▀░▀░░▀░░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀──────────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                             ├┤
// ││ Repo    : https://github.com/roosta/dotfiles                       ││
// ││ Site    : https://www.roosta.sh                                    ││
// ├┤ License : GNU General Public License v3                            ├┤
// ┆└────────────────────────────────────────────────────────────────────┘┆

pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import QtQuick
import qs.config

Singleton {
  id: root
  property bool launcherOpen: false
  property string launcherMonitorId: ""
  property string launcherMode: Config.defaultMode
  property bool calendarOpen: false
  property string calendarMonitorId: ""
  property bool wifiOpen: false
  property string wifiMonitorId: ""
  property bool sysOpen: false
  property string sysMonitorId: ""
  property bool mediaOpen: false
  property string mediaMonitorId: ""
  // Window x of the bar widget's centre; the panel hangs under it.
  property real mediaAnchorX: 0
  property bool overlayOpen: root.launcherOpen || root.trayMenuOpen || root.calendarOpen
    || root.wifiOpen || root.sysOpen || root.mediaOpen
  property QsMenuHandle activeMenu: null
  property bool trayMenuOpen: false
  property int menuDirection: Qt.LeftToRight
  property int menuIndex: 0
  property string searchQuery: ""
  property int matchCount: 0
  property bool itemDrawerActive: false

  Timer {
    id: timer
    interval: Style.durations.small
    onTriggered: {
      root.launcherMonitorId = ""
      root.launcherMode = Config.defaultMode
      root.menuDirection = Qt.LeftToRight
      root.menuIndex = 0
      root.searchQuery = ""
    }
  }

  // The menu positions itself off the tray item that opened it, so unlike the
  // other overlays this one does not need to be told which monitor.
  function openTrayMenu(menu) {
    if (!menu) {
      console.error("No provided menu, cant open menu")
      return
    }
    root.activeMenu = menu
    trayMenuOpen = true
  }

  function closeTrayMenu() {
    root.activeMenu = null
    trayMenuOpen = false
  }

  function openLauncher({
    id = Config.primaryDisplay,
    mode = null,
    direction = Qt.LeftToRight,
    index = 0
  }) {
    // The launcher takes over the keyboard and the top of the screen, so
    // nothing else stays open under it.
    root.closeCalendar()
    root.closeWifi()
    root.closeSys()
    root.closeMedia()
    if (root.trayMenuOpen) root.closeTrayMenu()
    launcherMonitorId = id
    if (index >= 0) {
      root.menuIndex = index
    }
    if (direction !== Qt.LeftToRight) {
      root.menuDirection = direction
    }
    if (mode) {
      root.launcherMode = mode
    }
    launcherOpen = true
  }

  // The calendar is a plain dropdown: unlike the launcher it takes no keyboard
  // focus and doesn't bump the exclusion zone, it just floats over the windows.
  function openCalendar(id = Config.primaryDisplay) {
    root.closeSys()
    root.closeWifi()
    root.calendarMonitorId = id
    root.calendarOpen = true
  }

  function closeCalendar() {
    root.calendarOpen = false
  }

  function toggleCalendar(id = Config.primaryDisplay) {
    if (root.calendarOpen && root.calendarMonitorId === id) {
      closeCalendar()
    } else {
      openCalendar(id)
    }
  }

  // The wifi dropdown behaves like the calendar -- floats over the windows,
  // no exclusion zone -- except that it does want the keyboard once a password
  // field is open. shell.qml handles that with OnDemand focus.
  function openWifi(id = Config.primaryDisplay) {
    root.closeSys()
    root.closeCalendar()
    root.wifiMonitorId = id
    root.wifiOpen = true
  }

  function closeWifi() {
    root.wifiOpen = false
  }

  function toggleWifi(id = Config.primaryDisplay) {
    if (root.wifiOpen && root.wifiMonitorId === id) {
      closeWifi()
    } else {
      openWifi(id)
    }
  }

  // The system panel drops out of the same top-right corner as the calendar and
  // the wifi dropdown, so the three close each other rather than stacking. Like
  // the calendar it never takes the keyboard -- nothing in it is typed into.
  function openSys(id = Config.primaryDisplay) {
    root.closeWifi()
    root.closeCalendar()
    root.sysMonitorId = id
    root.sysOpen = true
  }

  function closeSys() {
    root.sysOpen = false
  }

  function toggleSys(id = Config.primaryDisplay) {
    if (root.sysOpen && root.sysMonitorId === id) {
      closeSys()
    } else {
      openSys(id)
    }
  }

  // The media dropdown hangs off the left half of the bar, away from the
  // top-right corner, so it doesn't close the calendar/wifi/system panels.
  function openMedia(id = Config.primaryDisplay, x = 0) {
    root.mediaMonitorId = id
    root.mediaAnchorX = x
    root.mediaOpen = true
  }

  function closeMedia() {
    root.mediaOpen = false
  }

  function toggleMedia(id = Config.primaryDisplay, x = 0) {
    if (root.mediaOpen && root.mediaMonitorId === id) {
      closeMedia()
    } else {
      openMedia(id, x)
    }
  }

  // Escape and click-outside. The launcher is guarded because closing it
  // restarts the reset timer, which would clobber a launcher opened meanwhile.
  function closeAll() {
    root.closeCalendar()
    root.closeWifi()
    root.closeSys()
    root.closeMedia()
    if (root.trayMenuOpen) root.closeTrayMenu()
    if (root.launcherOpen) root.closeLauncher()
  }

  function closeLauncher() {
    launcherOpen = false
    timer.restart()
  }

  function toggleLauncher({ id, mode = null, direction = Qt.LeftToRight, index = 0 }) {
    if (launcherOpen) {
      closeLauncher()
    } else {
      openLauncher({ id, mode, direction, index })
    }
  }
}
