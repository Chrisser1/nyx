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

import qs
import qs.components
import qs.config
import qs.services
import qs.utils
import QtQuick
import QtQuick.Layouts
import Quickshell.Hyprland
import Quickshell

Item {
  id: root
  required property string monitorId

  anchors.topMargin: Style.bar.height
  anchors.top: parent.top
  anchors.left: parent.left
  anchors.right: parent.right

  // Constant height: nothing outside this item reflows while animating.
  implicitHeight: Style.launcher.height

  // The slide happens inside these bounds
  clip: true

  readonly property bool active: GlobalState.launcherOpen
    && GlobalState.launcherMonitorId === root.monitorId

  // There is one launcher per monitor, but only the one on launcherMonitorId
  // is ever shown. The others skip the search entirely rather than filtering
  // and rebuilding a hidden list on every keystroke.
  readonly property bool owner: GlobalState.launcherMonitorId === root.monitorId

  // Only render while on-screen or mid-transition
  visible: launcher.y > -Style.launcher.height

  signal decrementCurrentIndex()
  signal incrementCurrentIndex()
  signal drawerNext()
  signal drawerPrev()
  signal openDrawer()
  signal closeDrawer()
  signal drawerActivate()

  signal accepted()

  onDrawerActivate: {
    const currentItem = launcherList?.list?.currentItem;
    currentItem.drawerActivate()
  }
  onDrawerNext: {
    const currentItem = launcherList?.list?.currentItem;
    currentItem.drawerNext()
  }
  onDrawerPrev: {
    const currentItem = launcherList?.list?.currentItem;
    currentItem.drawerPrev()
  }
  onOpenDrawer: {
    const currentItem = launcherList?.list?.currentItem;
    currentItem.openDrawer()
  }
  onCloseDrawer: {
    const currentItem = launcherList?.list?.currentItem;
    currentItem.closeDrawer()
  }
  onAccepted: {
    const currentItem = launcherList?.list?.currentItem;
    if (currentItem) {
      launcherList.accept(currentItem.modelData)
    }
  }

  onIncrementCurrentIndex: {
    launcherList.list.incrementCurrentIndex()
  }

  onDecrementCurrentIndex: {
    launcherList.list.decrementCurrentIndex()
  }

  // The calculator is the one source driven by the query rather than the mode:
  // in calc mode every keystroke is an expression, in apps mode only the ones
  // that look like maths, so searching for "1password" never spawns qalc.
  function evaluateQuery() {
    const s = GlobalState.launcherMode
    const q = GlobalState.searchQuery
    if (s === "calc") {
      LauncherData.evaluate(q.replace(`${Config.menuPrefix}/calc`, ""))
    } else if (s === "apps" || s === "") {
      LauncherData.evaluate(LauncherData.isExpression(q) ? q : "")
    } else {
      LauncherData.evaluate("")
    }
  }

  // The wallpaper and monitor lists are read from external commands, so
  // re-read them on entering the mode rather than caching at startup.
  Connections {
    target: GlobalState
    function onLauncherMonitorIdChanged() {
      if (root.owner) root.evaluateQuery();
    }
    function onLauncherModeChanged() {
      if (!root.owner) return;
      if (GlobalState.launcherMode === "wallpaper") LauncherData.refreshWallpapers();
      else if (GlobalState.launcherMode === "theme") LauncherData.refreshThemes();
      else if (GlobalState.launcherMode === "display") LauncherData.refreshMonitors();
      root.evaluateQuery();
    }
    function onSearchQueryChanged() {
      if (root.owner) root.evaluateQuery();
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleLauncher"
    description: "Toggles launcher"

    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({ id: Hyprland.focusedMonitor?.name })
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleMenu"
    description: "Toggles launcher menu"

    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({id: Hyprland.focusedMonitor?.name, mode: "menu"})
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleWallpaper"
    description: "Opens the launcher in wallpaper-picker mode"
    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({ id: Hyprland.focusedMonitor?.name, mode: "wallpaper" })
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleTheme"
    description: "Opens the launcher in theme-picker mode"
    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({ id: Hyprland.focusedMonitor?.name, mode: "theme" })
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleDisplays"
    description: "Opens the launcher in monitor-management mode"
    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({ id: Hyprland.focusedMonitor?.name, mode: "display" })
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "togglePower"
    description: "Opens the launcher in power/session mode"
    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({ id: Hyprland.focusedMonitor?.name, mode: "power" })
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleNotifications"
    description: "Toggles nofication launcher panel"

    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleLauncher({id: Hyprland.focusedMonitor?.name, mode: "notifications" })
      }
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "discardLastNotification"
    description: "Discards last notification"
    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        Notifications.discardLastNotification();
      }
    }
  }

  BorderRect {
    id: launcher

    // Fixed geometry: the ColumnLayout / ListView never relayout during the animation
    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: Style.launcher.height

    // 0 == fully open, -Style.launcher.height == fully hidden behind the bar
    y: root.active ? 0 : -Style.launcher.height

    color: Style.colors.black
    bottomBorder: Style.bar.borderWidth
    borderColor: Style.colors.gray2

    Behavior on y {
      NumberAnimation {
        duration: Style.durations.small
        easing.type: Easing.InOutCubic
      }
    }

    ColumnLayout {
      anchors.fill: parent
      id: layout
      spacing: 0
      // This handles setting context description when launcher is open
      // TODO: Improve
      property string desc: launcherList?.list?.currentItem?.name ?? "Undefined"
      onDescChanged: {
        if (root.owner && typeof desc === "string" && desc !== "Undefined") { ContextData.launcherDesc = desc }
      }

      property var sourceData: {
        if (!root.owner) return []
        const s = GlobalState.launcherMode
        if (s === "notifications") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/notifications`, "")
          return Fuzzy.go(q, Notifications.list, { all: true, key: "appName" }).map(s => s.obj)
        } else if (s === "menu") {
          const q = GlobalState.searchQuery.replace("/", "")
          return Fuzzy.query(q, LauncherData.menuData)
        } else if (s === "power") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/power`, "")
          return Fuzzy.query(q, LauncherData.powerData)
        } else if (s === "display") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/display`, "")
          return Fuzzy.query(q, LauncherData.displayData)
        } else if (s === "audio") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/audio`, "")
          return Fuzzy.query(q, LauncherData.audioData)
        } else if (s === "utils") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/utils`, "")
          return Fuzzy.query(q, LauncherData.utilsData)
        } else if (s === "wallpaper") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/wallpaper`, "")
          return Fuzzy.query(q, LauncherData.wallpaperData)
        } else if (s === "theme") {
          const q = GlobalState.searchQuery.replace(`${Config.menuPrefix}/theme`, "")
          return Fuzzy.query(q, LauncherData.themeData)
        } else if (s === "calc") {
          return LauncherData.calcData
        } else {
          // calcData is empty unless the query looks like maths, so in the
          // common case this is just the app list.
          return [...LauncherData.calcData, ...Fuzzy.query(GlobalState.searchQuery, LauncherData.appsData)]
        }
      }

      onSourceDataChanged: {
        if (root.owner) GlobalState.matchCount = layout.sourceData.length
      }

      function onAccept(entry) {
        const s = GlobalState.launcherMode
        if (s === "notifications") {
          Notifications.attemptInvokeAction(entry.notificationId, "default")
          GlobalState.closeLauncher()
        } else if (s === "menu") {
          GlobalState.launcherMode = entry.mode
          GlobalState.searchQuery = ""
        } else if (s === "theme") {
          // Stays open so themes can be compared.
          LauncherData.applyTheme(entry)
        } else if (s === "power"
          || s === "display"
          || s === "audio"
          || s === "utils"
          || s === "wallpaper"
          || s === "calc"
          || s === "apps"
          || s === "") {
          LauncherData.launch(entry)
          GlobalState.closeLauncher()
        }

      }

      LauncherList {
        monitorId: root.monitorId
        id: launcherList

        sourceModel: layout.sourceData

        signal accept(entry: var)
        onAccept: (entry) => {
          layout.onAccept(entry)
        }

        delegate: LauncherItem {
          required property var modelData

          iconSource: {
            const icon = modelData?.iconId || modelData?.appIcon
            if (icon) {
              return Quickshell.iconPath(icon)
            } else if (modelData?.id) {
              return Icons.getEntryIcon(modelData)
            }
            return ""
          }

          notificationId: modelData?.notificationId ?? -1
          imageSource: modelData?.image ?? ""
          preview: LauncherData.previewFor(modelData)
          palette: modelData?.palette ?? []
          swatch: LauncherData.swatchFor(modelData)
          current: LauncherData.isCurrent(modelData)
          name: modelData?.name ?? modelData?.appName ?? ""
          favorite: Config.favorites.includes(modelData?.id ?? "") ?? false
          isNotification: modelData?.isNotification ?? false
          timeElapsed: Functions.timeElapsed(modelData?.time) ?? ""
          description: modelData?.comment ?? modelData?.body ?? ""
          genericName: modelData?.genericName ?? modelData?.summary ??  ""
          actions: modelData?.actions ?? []
          categories: modelData?.categories ?? []
          onClicked: launcherList.accept(modelData)
        }
      }
    }
  }
}
