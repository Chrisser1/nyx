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
import Quickshell.Io
import QtQuick
import qs.services
import qs.config
import qs.utils


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
  property list<var> monitorEntries: []
  property list<var> displayData: {
    const live = monitorEntries.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }));
    const statics = Config.displayLayouts.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }));
    return [...live, ...statics];
  }

  function refreshMonitors() { monProc.running = true }

  Process {
    id: monProc
    command: [Host.monitors, "list"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const rows = [];
        for (const line of this.text.split("\n")) {
          if (!line.length) continue;
          const f = line.split("\t");
          if (f.length < 8) continue;
          rows.push({
            name: f[0], desc: f[1], mode: f[2], pos: f[3],
            scale: f[4], enabled: f[5] === "enabled",
            mirrorOf: f[6], focused: f[7] === "focused"
          });
        }

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

          const state = [];
          if (!m.enabled) state.push("disabled");
          if (m.mirrorOf !== "none") state.push(`mirroring ${m.mirrorOf}`);
          if (m.focused) state.push("focused");

          out.push({
            id: `nyx-monitor-${m.name}`,
            name: m.name,
            comment: `${m.desc} — ${m.mode} at ${m.pos}${state.length ? " (" + state.join(", ") + ")" : ""}`,
            genericName: "Monitor",
            categories: ["Display", m.enabled ? "Enabled" : "Disabled"],
            iconId: m.enabled ? "video-display" : "preferences-desktop-display",
            // Enter on the card toggles; the drawer holds mirroring.
            command: [Host.monitors, "toggle", m.name],
            script: [Host.monitors, "toggle", m.name],
            actions: actions
          });
        }
        root.monitorEntries = out;
      }
    }
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

  // ---- Clipboard history -----------------------------------------------------
  // Backed by `nyx-clipboard list`, which emits "<id>\t<preview>" per line
  // (cliphist's own format). Refreshed each time the mode is opened, since the
  // history changes constantly outside the shell.
  property list<var> clipboardEntries: []
  property list<var> clipboardData: clipboardEntries.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }))

  function refreshClipboard() { clipProc.running = true }

  Process {
    id: clipProc
    command: [Host.clipboard, "list"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const out = [];
        for (const line of this.text.split("\n")) {
          if (!line.length) continue;
          const tab = line.indexOf("\t");
          if (tab < 0) continue;
          const id = line.slice(0, tab);
          const preview = line.slice(tab + 1);
          out.push({
            id: `nyx-clip-${id}`,
            clipId: id,
            name: preview,
            comment: "Copy this entry to the clipboard",
            genericName: "Clipboard",
            categories: ["Clipboard"],
            iconId: preview.startsWith("[[ binary data") ? "image" : "edit-paste",
            script: [Host.clipboard, "copy", id]
          });
        }
        root.clipboardEntries = out;
      }
    }
  }

  // ---- Wallpapers ------------------------------------------------------------
  // `nyx-wallpaper list` emits paths relative to the wallpaper root, so the
  // stored selection survives a rebuild or a store GC.
  property list<var> wallpaperEntries: []
  property list<var> wallpaperData: wallpaperEntries.map(a => ({ name: Fuzzy.prepare(a.name), entry: a }))

  function refreshWallpapers() { wallProc.running = true }

  Process {
    id: wallProc
    command: [Host.wallpaper, "list"]
    running: false
    stdout: StdioCollector {
      onStreamFinished: {
        const out = [];
        for (const rel of this.text.split("\n")) {
          if (!rel.length) continue;
          const isVideo = /\.(mp4|mkv|webm|avi|mov)$/i.test(rel);
          const slash = rel.lastIndexOf("/");
          const folder = slash > 0 ? rel.slice(0, slash) : "";
          const file = rel.slice(slash + 1).replace(/\.[^.]+$/, "");
          out.push({
            id: `nyx-wall-${rel}`,
            name: file,
            comment: isVideo ? `Animated wallpaper (${folder})` : `Wallpaper (${folder})`,
            genericName: isVideo ? "Video" : "Image",
            categories: ["Wallpaper", folder],
            iconId: isVideo ? "video-x-generic" : "image-x-generic",
            script: [Host.wallpaper, "set-all", rel]
          });
        }
        root.wallpaperEntries = out;
      }
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

