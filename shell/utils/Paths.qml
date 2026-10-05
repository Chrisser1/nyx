// Adapted from roosta/dotfiles (.config/quickshell/utils/Paths.qml, GPLv3).
// roosta's `scripts`/`assets`/`srcery` paths are gone — helper binaries come from
// Host.qml, and there is no srcery submodule here.

pragma Singleton

import Quickshell

Singleton {
  id: root

  readonly property string home: Quickshell.env("HOME")

  // Helper function to get XDG directory with fallback
  function xdgDir(envVar, fallback, subdir = "") {
    const base = Quickshell.env(envVar) || `${abs(fallback)}`;
    return subdir ? `${base}/${subdir}` : base;
  }

  readonly property string config: xdgDir("XDG_CONFIG_HOME", "~/.config")
  readonly property string cache: xdgDir("XDG_CACHE_HOME", "~/.cache", "nyx")
  readonly property string state: xdgDir("XDG_STATE_HOME", "~/.local/state", "nyx")

  function abs(path: string): string {
    return path.replace("~", home);
  }
}
