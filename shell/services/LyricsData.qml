// Lyrics for the current MPRIS track, fetched through nyx-lyrics (LRCLIB) while
// the media panel is open. Time-synced lyrics expose which line is playing;
// plain ones are shown without a position.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

Singleton {
  id: root

  readonly property var player: MediaData.player

  // loading | synced | plain | none
  property string state: "none"
  // [{ time: seconds, text }]; time is -1 for plain lyrics.
  property var lines: []

  // Not reactive on its own; MediaData's ticker re-evaluates it.
  readonly property real position: root.player?.position ?? 0
  readonly property int currentIndex: root.state === "synced" ? root.indexAt(root.lines, root.position) : -1

  // The track being asked about; empty while nobody is looking.
  readonly property string wanted: {
    if (!GlobalState.mediaOpen || !root.player?.trackTitle) return "";
    return [root.player.trackArtist, root.player.trackTitle, root.player.trackAlbum, Math.round(root.player.length)].join("\u0000");
  }

  property var cache: ({})

  // "[01:23.45] text" -> sorted [{ time, text }]. A line may carry several
  // stamps; [ar:...]-style tags are not stamps and are skipped.
  function parseLrc(lrc: string): var {
    const out = [];
    for (const raw of lrc.split("\n")) {
      const stamp = /\[(\d+):(\d+(?:\.\d+)?)\]/g;
      const stamps = [];
      for (let m = stamp.exec(raw); m; m = stamp.exec(raw)) stamps.push(m);
      if (!stamps.length) continue;
      const text = raw.replace(/\[[^\]]*\]/g, "").trim();
      for (const s of stamps) out.push({ time: Number(s[1]) * 60 + Number(s[2]), text });
    }
    return out.sort((a, b) => a.time - b.time);
  }

  // The last line that has started by `position`, or -1 before the first.
  function indexAt(lines: var, position: real): int {
    let found = -1;
    for (let i = 0; i < lines.length; i++) {
      if (lines[i].time > position) break;
      found = i;
    }
    return found;
  }

  function resolve(result: var): var {
    if (result.synced) return { state: "synced", lines: root.parseLrc(result.synced) };
    if (result.plain) return { state: "plain", lines: result.plain.split("\n").map(text => ({ time: -1, text })) };
    return { state: "none", lines: [] };
  }

  function apply(entry: var) {
    root.state = entry.state;
    root.lines = entry.lines;
  }

  function refresh() {
    if (!root.wanted) return;
    const hit = root.cache[root.wanted];
    if (hit) {
      root.apply(hit);
      return;
    }
    root.apply({ state: "loading", lines: [] });
    if (proc.running) return;
    const p = root.player;
    proc.requestKey = root.wanted;
    proc.command = [Host.lyrics, p.trackArtist || "", p.trackTitle, p.trackAlbum || "", String(p.length || 0)];
    proc.running = true;
  }

  onWantedChanged: root.refresh()

  Process {
    id: proc
    property string requestKey
    stdout: StdioCollector {
      onStreamFinished: {
        let result = null;
        try { result = JSON.parse(this.text); } catch (e) { }
        // A failed request (offline) is not cached, so reopening retries.
        const entry = result ? root.resolve(result) : { state: "none", lines: [] };
        if (result) root.cache[proc.requestKey] = entry;
        if (proc.requestKey === root.wanted) root.apply(entry);
      }
    }
    // The track changed while this was in flight.
    onExited: if (root.wanted && root.wanted !== proc.requestKey) root.refresh()
  }
}
