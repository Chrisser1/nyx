// ┌────────────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█░░░█▀█░█░█░█▀█░█▀▀░█░█░█▀▀░█▀▄░█▀▄░█▀█░▀█▀░█▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█░░░█▀█░█░█░█░█░█░░░█▀█░█▀▀░█▀▄░█░█░█▀█░░█░░█▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀░░▀░▀░░▀░░▀░▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                               ├┤
// ││ Repo    : https://github.com/roosta/dotfiles                         ││
// ││ Site    : https://www.roosta.sh                                      ││
// ├┤ License : GNU General Public License v3                              ├┤
// ┆└──────────────────────────────────────────────────────────────────────┘┆

pragma Singleton
pragma ComponentBehavior: Bound

pragma Singleton
import Quickshell
import qs
import Quickshell.Io
import QtQuick
import qs.services
import qs.config
import qs.utils
import "../utils/emojiSearch.js" as EmojiSearch


Singleton {
  id: root
  property list<var> audioData: {
    if (AudioData.ready) {
      let data = [...Config.outputs, ...Config.audioOptions]
      return data.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }))
    }
    return []
  }

  // ---- Displays --------------------------------------------------------------
  // One card per output, read live from `nyx-monitors list` (tab-separated:
  // name, description, mode, position, scale, enabled|disabled, mirrorOf, focused).
  // Each card carries per-monitor actions in its drawer; the static arrange/save
  // entries from Config are appended at the end.
  property list<var> monitorEntries: root.monitorCards(MonitorData.rows)
  property list<var> displayData: {
    const live = monitorEntries.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }));
    const statics = Config.displayLayouts.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }));
    return [...live, ...statics];
  }

  function refreshMonitors() { MonitorData.refresh() }

  function monitorCards(rows) {
    const out = [];
    for (const m of rows) {
      const actions = [{
        id: `mon-toggle-${m.name}`,
        name: m.enabled ? "Disable" : "Enable",
        icon: "",
        execString: `${Host.monitors} toggle ${m.name}`,
        command: [Host.monitors, "toggle", m.name]
      }];

      if (m.mirrorOf !== "none") {
        actions.push({
          id: `mon-unmirror-${m.name}`,
          name: `Stop mirroring ${m.mirrorOf}`,
          icon: "",
          execString: `${Host.monitors} unmirror ${m.name}`,
          command: [Host.monitors, "unmirror", m.name]
        });
      }

      // Mirror any *other* output onto this one.
      for (const src of rows) {
        if (src.name === m.name || !src.enabled) continue;
        actions.push({
          id: `mon-mirror-${src.name}-${m.name}`,
          name: `Show ${src.name} here`,
          icon: "",
          execString: `${Host.monitors} mirror ${src.name} ${m.name}`,
          command: [Host.monitors, "mirror", src.name, m.name]
        });
      }

      // Each preset but the current one; Hyprland rounds to what the panel allows.
      if (m.enabled && m.mirrorOf === "none") {
        for (const s of ["1", "1.25", "1.5", "1.6", "2"]) {
          if (Number(s) === Number(m.scale)) continue;
          actions.push({
            id: `mon-scale-${m.name}-${s}`,
            name: `Scale ${s}x`,
            icon: "",
            execString: `${Host.monitors} scale ${m.name} ${s}`,
            command: [Host.monitors, "scale", m.name, s]
          });
        }
      }

      const state = [];
      if (!m.enabled) state.push("disabled");
      if (m.mirrorOf !== "none") state.push(`mirroring ${m.mirrorOf}`);
      if (m.focused) state.push("focused");

      out.push({
        id: `nyx-monitor-${m.name}`,
        name: m.name,
        comment: `${m.desc} — ${m.mode} at ${m.pos}, ${m.scale}x${state.length ? " (" + state.join(", ") + ")" : ""}`,
        genericName: "Monitor",
        categories: ["Display", m.enabled ? "Enabled" : "Disabled"],
        iconId: m.enabled ? "video-display" : "preferences-desktop-display",
        // Enter on the card toggles; the drawer holds mirroring.
        command: [Host.monitors, "toggle", m.name],
        script: [Host.monitors, "toggle", m.name],
        actions: actions
      });
    }
    return out;
  }

  property list<var> powerData: {
    return Config.powerScripts.map(a => {
      return  {
        name: Fuzzy.prepare(a.name),
        entry: a
      }
    })
  }

  property list<var> menuData: Config.launcherMenus.map(a => {
    return  {
      name: Fuzzy.prepare(a.name),
      entry: a
    }
  })

  property list<var> utilsData: Config.utilities.map(a => {
    return {
      name: Fuzzy.prepare(a.name),
      entry: a
    }
  })

  property list<var> appsData: {
    let entries = Array.from(DesktopEntries.applications.values) ?? [];

    const favs = Config.favorites
      .map(id => entries.find(a => a.id === id))
      .filter(a => a !== undefined);

    const rest = entries
      .filter(a => !Config.favorites.includes(a.id))
      .sort((a, b) => a.name.localeCompare(b.name));

    return [...favs, ...rest].map(a => ({
      name: Fuzzy.prepare(a.name),
      entry: a,
    }));
  }

  // ---- Wallpapers ------------------------------------------------------------
  // Paths are relative to the wallpaper root, so a saved choice survives a
  // rebuild. The list shows at once; thumbnails fill in when they are ready.
  property list<var> wallpaperEntries: []
  property var wallpaperThumbs: ({})
  property list<var> wallpaperData: wallpaperEntries.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }))

  function refreshWallpapers() {
    wallProc.running = true;
    thumbProc.running = true;
  }

  Process {
    id: wallProc
    command: [Host.wallpaper, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.wallpaperEntries = this.text.split("\n").filter(Boolean).map(rel => {
          const isVideo = /\.(mp4|mkv|webm|avi|mov)$/i.test(rel);
          const slash = rel.lastIndexOf("/");
          return {
            id: `nyx-wall-${rel}`,
            rel: rel,
            name: rel.slice(slash + 1).replace(/\.[^.]+$/, ""),
            genericName: isVideo ? "Video" : "Image",
            categories: slash > 0 ? [rel.slice(0, slash)] : [],
            iconId: isVideo ? "video-x-generic" : "image-x-generic",
            script: [Host.wallpaper, "set-all", rel]
          };
        });
      }
    }
  }

  Process {
    id: thumbProc
    command: [Host.wallpaper, "thumbs"]
    stdout: StdioCollector {
      onStreamFinished: {
        const thumbs = {};
        for (const line of this.text.split("\n")) {
          const [rel, thumb] = line.split("\t");
          if (thumb) thumbs[rel] = thumb;
        }
        root.wallpaperThumbs = thumbs;
      }
    }
  }

  // ---- Themes ----------------------------------------------------------------
  // Every base16 scheme from `nyx-theme schemes`, plus following the wallpaper,
  // light/dark and the accent slot. `themeState` mirrors theme.json.
  //
  // The launcher's ScriptModel keeps delegates for unchanged entries, so anything
  // that changes while it is open (thumbnails, current marker, accent swatches)
  // is looked up live through the functions below rather than stored in entries.
  property list<var> themeSchemes: []
  property var themeState: ({})
  readonly property var accentSlots: [
    ["base08", "Red"], ["base09", "Orange"], ["base0A", "Yellow"], ["base0B", "Green"],
    ["base0C", "Cyan"], ["base0D", "Blue"], ["base0E", "Purple"], ["base0F", "Brown"]
  ]

  readonly property var currentScheme: themeSchemes.find(s => s.id === themeState.scheme) ?? null
  readonly property bool followingWallpaper: themeState.source === "wallpaper"

  property list<var> themeEntries: [
    {
      id: "nyx-theme-follow",
      name: "Follow wallpaper",
      genericName: "Material You",
      comment: "Generate colours from the current wallpaper",
      iconId: "preferences-desktop-wallpaper",
      themeAction: ["follow"]
    },
    {
      id: "nyx-theme-mode",
      name: "Light / dark",
      genericName: "Material You",
      comment: "Toggle the mode used when following the wallpaper",
      iconId: "preferences-desktop-theme",
      themeAction: ["mode"]
    },
    ...root.accentSlots.map(([slot, label]) => ({
      id: `nyx-theme-accent-${slot}`,
      name: `${label} accent`,
      genericName: "Accent",
      comment: `Use ${slot} of the scheme as the accent`,
      themeAction: ["accent", slot]
    })),
    ...root.themeSchemes.map(scheme => ({
      id: `nyx-theme-${scheme.id}`,
      name: scheme.name,
      genericName: scheme.variant === "light" ? "Light" : "Dark",
      comment: scheme.id,
      palette: scheme.colors,
      themeAction: ["scheme", scheme.id]
    }))
  ]
  property list<var> themeData: themeEntries.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }))

  function previewFor(entry) {
    return entry?.rel !== undefined ? (root.wallpaperThumbs[entry.rel] ?? "") : "";
  }

  function isCurrent(entry) {
    const [action, arg] = entry?.themeAction ?? [];
    const s = root.themeState;
    if (action === "follow") return root.followingWallpaper;
    if (action === "accent") return !root.followingWallpaper && s.accent === arg;
    if (action === "scheme") return !root.followingWallpaper && s.scheme === arg;
    return false;
  }

  function swatchFor(entry) {
    const [action, arg] = entry?.themeAction ?? [];
    if (action !== "accent") return "";
    const index = root.accentSlots.findIndex(([slot]) => slot === arg);
    return root.currentScheme?.colors[8 + index] ?? "";
  }

  function themeCommand(entry) {
    const [action, arg] = entry.themeAction;
    switch (action) {
    case "follow": return [Host.wallpaper, "theme"];
    case "mode": return [Host.theme, "mode", root.themeState.mode === "light" ? "dark" : "light"];
    default: return [Host.theme, action, arg];
    }
  }

  function refreshThemes() {
    if (!root.themeSchemes.length) schemesProc.running = true;
    themeStateProc.running = true;
  }

  // One change at a time; matugen should not be interrupted mid-render.
  function applyTheme(entry) {
    if (themeApplyProc.running) return;
    themeApplyProc.command = root.themeCommand(entry);
    themeApplyProc.running = true;
  }

  Process {
    id: themeApplyProc
    onExited: themeStateProc.running = true
  }

  Process {
    id: schemesProc
    command: [Host.theme, "schemes"]
    stdout: StdioCollector {
      onStreamFinished: root.themeSchemes = JSON.parse(this.text)
    }
  }

  Process {
    id: themeStateProc
    command: [Host.theme, "current"]
    stdout: StdioCollector {
      onStreamFinished: root.themeState = JSON.parse(this.text)
    }
  }

  // nyx-theme rewrites it on every change.
  FileView {
    path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/nyx/theme.json`
    watchChanges: true
    printErrors: false
    onFileChanged: themeStateProc.running = true
  }

  // ---- Emoji ---------------------------------------------------------------
  // From `nyx-emoji list`, recently used first. Skin tones sit in the drawer.
  property list<var> emojiEntries: []
  property var emojiIndex: []
  readonly property int emojiCap: 60

  function searchEmoji(query) { return EmojiSearch.search(query, root.emojiIndex, root.emojiCap) }

  function refreshEmoji() { emojiProc.running = true }

  Process {
    id: emojiProc
    command: [Host.emoji, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        root.emojiEntries = JSON.parse(this.text).map(e => ({
          id: `nyx-emoji-${e.e}`,
          name: e.n,
          glyph: e.e,
          genericName: e.g,
          comment: e.k.join(", "),
          script: [Host.emoji, "copy", e.e],
          actions: e.v.map(v => ({
            id: `nyx-emoji-${v.e}`,
            name: `${v.e} ${v.n}`,
            script: [Host.emoji, "copy", v.e]
          }))
        }));
        root.emojiIndex = EmojiSearch.index(root.emojiEntries);
      }
    }
  }

  // ---- Bitwarden -----------------------------------------------------------
  // The vault itself lives in VaultData and modules/bitwarden. The launcher
  // only hosts the login form, for a vault that is not set up yet.

  // Before login the search box is the form: type the email, pick a region
  // (or paste a server URL and press Enter on its card), then Enter on the
  // login card. The password and 2FA code are asked for in pinentry.
  readonly property bool vaultNeedsSetup: VaultData.needsSetup
  // Follows what rbw is configured with until a card is picked.
  property string vaultRegion: VaultData.region
  readonly property var vaultRegions: [
    { id: "com", name: "Bitwarden.com", comment: "United States" },
    { id: "eu", name: "Bitwarden.eu", comment: "European Union" }
  ]

  function setupEntries(query) {
    const q = query.trim() || VaultData.email;
    const isUrl = /^https?:\/\//.test(q);
    const valid = !isUrl && /^[^@\s]+@[^@\s]+$/.test(q);
    const region = root.vaultRegions.find(r => r.id === root.vaultRegion)?.name ?? root.vaultRegion;
    const entries = [{
      id: "nyx-bw-login",
      name: valid ? `Log in as ${q}` : "Type your email above",
      genericName: region,
      comment: valid ? "Asks for your password in a dialog" : "Then press Enter here",
      iconId: "bitwarden",
      loginEmail: valid ? q : ""
    }];
    for (const r of root.vaultRegions) {
      entries.push({
        id: `nyx-bw-region-${r.id}`,
        name: `${root.vaultRegion === r.id ? "● " : "○ "}${r.name}`,
        genericName: "Region",
        comment: r.comment,
        iconId: "network-server",
        setRegion: r.id
      });
    }
    if (isUrl) {
      entries.push({
        id: "nyx-bw-region-custom",
        name: `${root.vaultRegion === q ? "● " : "○ "}Self-hosted`,
        genericName: "Region",
        comment: q,
        iconId: "network-server",
        setRegion: q
      });
    }
    return entries;
  }

  function loginVault(monitorId, email) {
    loginProc.monitorId = monitorId;
    loginProc.command = [Host.bitwarden, "setup", email, root.vaultRegion];
    loginProc.running = true;
  }

  Process {
    id: loginProc
    property string monitorId: ""
    onExited: code => {
      if (code !== 0) return;
      VaultData.refresh();
      GlobalState.openBitwarden(loginProc.monitorId);
    }
  }

  // ---- Calculator ------------------------------------------------------------
  // Backed by `nyx-calc eval`, which is one qalc process per query, so the
  // keystrokes are debounced and the running process is never re-argv'd.
  //
  // qalc will "evaluate" prose as readily as maths -- `not an expression` comes
  // back as `n = 0` -- so an empty result is not a reliable "this wasn't maths"
  // signal. isExpression() is what actually keeps stray cards out of the app
  // list; Launcher.qml gates on it before calling evaluate().
  property string calcExpr: ""
  property list<var> calcEntries: []
  // Deliberately not run through Fuzzy: the row set is already exactly the answer.
  property list<var> calcData: calcEntries

  // Conservative on purpose: a false positive pushes a nonsense card above the
  // app the user is actually searching for, and qalc answers nonsense happily
  // ("7-zip" evaluates to "7 − iz", "1password" to "1 pa·word·s²").
  //
  // Note `to` and not `in` — qalc reads `in` as the inch unit, so "2 GB in MB"
  // comes back as "2000 in·MB²". `to` is the conversion keyword that works.
  function isExpression(q) {
    const s = q.trim();
    // Three characters is the shortest real sum ("1+1"), and an app search
    // effectively never opens with a digit or a bracket.
    if (s.length < 3) return false;
    if (!/^[0-9(.+-]/.test(s)) return false;
    if (/\bto\b/.test(s)) return true;
    // An operator only counts with a digit, space or bracket on both sides,
    // which is what keeps "7-zip" out.
    return /(^|[\d\s)])\s*[-+*/^%]\s*($|[\d\s(.])/.test(s);
  }

  function evaluate(expr) {
    const s = expr.trim();
    if (s === root.calcExpr) return;
    root.calcExpr = s;
    if (!s.length) {
      calcDebounce.stop();
      root.calcEntries = [];
      return;
    }
    calcDebounce.restart();
  }

  Timer {
    id: calcDebounce
    interval: 120
    onTriggered: {
      // One qalc at a time. Killing a run mid-flight would let its stdout land
      // after the next one's, so wait a tick instead -- and assign command
      // rather than binding it, so the argv of a running process never changes.
      if (calcProc.running) {
        calcDebounce.restart();
        return;
      }
      calcProc.command = [Host.calc, "eval", root.calcExpr];
      calcProc.running = true;
    }
  }

  Process {
    id: calcProc
    command: [Host.calc, "eval", ""]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const result = this.text.trim();
        // The expression this run was actually started with; the query may have
        // moved on since, in which case the pending debounce re-dispatches.
        const expr = calcProc.command[2];
        if (expr !== root.calcExpr) return;
        // qalc echoes an expression it could not reduce straight back.
        if (!result.length || result === expr) {
          root.calcEntries = [];
          return;
        }
        root.calcEntries = [{
          id: "nyx-calc-result",
          name: result,
          comment: `${expr} — Enter to copy`,
          genericName: "Calculator",
          categories: ["Calculator"],
          iconId: "accessories-calculator",
          script: [Host.calc, "copy", result]
        }];
      }
    }
  }

  function launch(entry) {
    if (entry.script) {
      Quickshell.execDetached({
        command: entry.script,
      });
    } else if (entry.runInTerminal) {
      Quickshell.execDetached({
        command: [Config.terminal, ...entry.command],
        workingDirectory: entry.workingDirectory
      });
    } else {
      const wdir = entry.workingDirectory
      const obj = { command: entry.command, }
      if (wdir) { obj.workingDirectory = wdir }
      Quickshell.execDetached(obj);
    }
  }
}

