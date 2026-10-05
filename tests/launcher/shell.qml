// Launcher theme and wallpaper modes: entries, previews and the current marker.
// Saves screenshots to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.launcher

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function shot(name) {
    if (Quickshell.env("OUT")) launcher.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/${name}.png`));
  }

  function entry(id) {
    return LauncherData.themeEntries.find(e => e.id === id);
  }

  readonly property var steps: [
    { what: "open theme mode", ready: () => true,
      act: () => GlobalState.openLauncher({ id: "TEST", mode: "theme" }) },
    { what: "schemes loaded", settle: 5,
      ready: () => LauncherData.themeEntries.length > 300 && LauncherData.themeState.scheme !== undefined,
      act: () => {
        const gruvbox = root.entry("nyx-theme-gruvbox-dark-medium");
        if (!LauncherData.isCurrent(gruvbox)) root.fail("default scheme marked current");
        if (gruvbox.palette.length !== 16) root.fail("scheme palette");
        if (!LauncherData.isCurrent(root.entry("nyx-theme-accent-base0D"))) root.fail("default accent marked current");
        if (LauncherData.swatchFor(root.entry("nyx-theme-accent-base0B")) !== "#b8bb26") root.fail("accent swatch");
        root.shot("theme");
      } },
    { what: "theme screenshot", settle: 5, ready: () => true,
      act: () => LauncherData.applyTheme(root.entry("nyx-theme-accent-base0B")) },
    { what: "accent applied", settle: 5, ready: () => LauncherData.themeState.accent === "base0B",
      act: () => {
        if (!LauncherData.isCurrent(root.entry("nyx-theme-accent-base0B"))) root.fail("new accent marked current");
        if (LauncherData.isCurrent(root.entry("nyx-theme-accent-base0D"))) root.fail("old accent still current");
        if (!GlobalState.launcherOpen) root.fail("theme mode closed after applying");
        root.shot("theme-accent");
      } },
    { what: "accent screenshot", settle: 5, ready: () => true,
      act: () => GlobalState.launcherMode = "wallpaper" },
    { what: "wallpaper thumbnails", settle: 30,
      ready: () => LauncherData.wallpaperData.length > 0
        && LauncherData.wallpaperData.every(d => LauncherData.previewFor(d.entry) !== ""),
      act: () => root.shot("wallpaper") },
    { what: "wallpaper screenshot", settle: 5, ready: () => true,
      act: () => { console.log("PASS"); Qt.exit(0); } }
  ]

  FloatingWindow {
    implicitWidth: 1440
    implicitHeight: 400
    color: "black"

    Launcher {
      id: launcher
      monitorId: "TEST"
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      const s = root.steps[root.step];
      if (s.ready() && root.waited >= (s.settle ?? 0)) {
        root.waited = 0;
        root.step++;
        s.act();
      } else if (++root.waited > 150) {
        root.fail(`timed out waiting for: ${s.what}`);
      }
    }
  }
}
