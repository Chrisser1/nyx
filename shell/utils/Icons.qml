// ┌───────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░░▀█▀░█▀▀░█▀█░█▀█░█▀▀░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░█░░█░░░█░█░█░█░▀▀█░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀───────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>      ├┤
// ││ Repo    : https://github.com/roosta/dotfiles││
// ││ Site    : https://www.roosta.sh             ││
// ├┤ License : GNU General Public License v3     ├┤
// ┆└─────────────────────────────────────────────┘┆

pragma Singleton
import Quickshell
import qs.services
import qs.config

Singleton {
  id: root
  readonly property var icons: {
    "missing": "image-missing",
  }

  // Get an alias for input id (usually class/appid)
  function getAlias(id) {
    for (const [re, repl] of Config.aliases) {
      if (re.test(id)) {
        return id.replace(re, repl);
      }
    }
    return null;
  }


  // Get desktop entry from id
  function getEntry(id: string): DesktopEntry {
    return DesktopEntries.heuristicLookup(id)
  }

  function getEntryIcon(entry: DesktopEntry): string {
    const icon = root.getAlias(entry.id) ?? entry?.icon
    return Quickshell.iconPath(icon, root.icons.missing)
  }

  function lookupIcon(appId: string): string {
    const icon = root.getAlias(appId) ?? getEntry(appId)?.icon
    return Quickshell.iconPath(icon, root.icons.missing)
  }


  // Returns a collection of icons in a given workspace (by address)
  // Removes duplicates, and applies aliases if present
  function getWsIcons(wsAddress: string): var {
    const classes = HyprlandData.windowList.filter(w => {
      return w.workspace.address === wsAddress
    }).map(w => w?.class)
    const uniq = [...new Set(classes)].sort((a, b) => a.localeCompare(b))
    return uniq.map(id => {
      const icon = root.getAlias(id) ?? DesktopEntries.heuristicLookup(id)?.icon
      return {
        icon: Quickshell.iconPath(icon, root.icons.missing),
        class: id
      }
    })
  }

}
