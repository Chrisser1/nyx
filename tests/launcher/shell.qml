// Launcher theme, wallpaper and emoji modes: entries, previews and search.
// Saves screenshots to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.utils
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

  function find(item, name) {
    if (item.objectName === name) return item;
    for (const c of item.children) {
      const found = root.find(c, name);
      if (found) return found;
    }
    return null;
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
      act: () => {
        const card = root.find(launcher, "preview");
        if (!card || Math.abs(card.width / card.height - 16 / 9) > 0.05) root.fail(`wallpaper preview aspect: ${card?.width}x${card?.height}`);
        root.shot("wallpaper");
      } },
    { what: "wallpaper screenshot", settle: 5, ready: () => true,
      act: () => GlobalState.launcherMode = "emoji" },
    { what: "emoji loaded", settle: 5, ready: () => LauncherData.emojiEntries.length > 1800,
      act: () => {
        const thumbs = LauncherData.searchEmoji("thumbs up")[0];
        if (thumbs?.glyph !== "👍") root.fail(`emoji search: ${thumbs?.name}`);
        if (thumbs.actions.length !== 5) root.fail("emoji skin tones");
        if (LauncherData.searchEmoji("+1")[0]?.glyph !== "👍") root.fail("emoji keyword search");
        if (LauncherData.searchEmoji("face").length !== LauncherData.emojiCap) root.fail("emoji results capped");
        if (LauncherData.searchEmoji("red heart")[0]?.glyph !== "❤️") root.fail(`emoji ranking: ${LauncherData.searchEmoji("red heart")[0]?.name}`);
        if (LauncherData.searchEmoji("").length !== LauncherData.emojiEntries.length) root.fail("empty query lists all");
        if (LauncherData.searchEmoji("zzzzqq").length !== 0) root.fail("no match");
        const t = Date.now();
        for (const q of ["a", "heart", "face", "thumbs up", "x"]) LauncherData.searchEmoji(q);
        console.log(`emoji search x5: ${Date.now() - t}ms`);
        GlobalState.searchQuery = "heart";
      } },
    { what: "emoji search", settle: 5, ready: () => true,
      act: () => root.shot("emoji") },
    { what: "emoji screenshot", settle: 5, ready: () => true,
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
