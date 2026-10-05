// Alt+Tab: windows in focus-history order, snapshotted on open so the list
// holds still while cycling.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Hyprland
import qs
import qs.config

Singleton {
  id: root

  property var windows: []
  property int index: 0
  readonly property var selected: root.windows[root.index] ?? null

  // Hyprland numbers focus history from 0, the focused window.
  function ordered() {
    return HyprlandData.windowList
      .filter(w => w.mapped && !w.hidden)
      .sort((a, b) => a.focusHistoryID - b.focusHistoryID);
  }

  function step(delta) {
    if (!GlobalState.switcherOpen) {
      root.windows = root.ordered();
      const n = root.windows.length;
      if (!n) return;
      // Forward starts on the previous window, so a quick Alt+Tab flips between two.
      root.index = delta > 0 ? Math.min(1, n - 1) : n - 1;
      GlobalState.openSwitcher(Hyprland.focusedMonitor?.name ?? Config.primaryDisplay);
      return;
    }
    const n = root.windows.length;
    root.index = (root.index + delta + n) % n;
  }

  function next() { root.step(1) }
  function previous() { root.step(-1) }

  function commit() {
    if (!GlobalState.switcherOpen) return;
    const w = root.selected;
    GlobalState.closeSwitcher();
    if (w) Hyprland.dispatch(`hl.dsp.focus({ window = "address:${w.address}" })`);
  }

  // Compared without 0x: hyprctl prefixes addresses, Hyprland events do not.
  function toplevel(address) {
    const bare = address.replace(/^0x/, "");
    return Hyprland.toplevels.values.find(t => t.address.replace(/^0x/, "") === bare) ?? null;
  }
}
