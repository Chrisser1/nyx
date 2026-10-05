// Clipboard history for modules/clipboard, backed by the nyx-clipboard helper.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

Singleton {
  id: root

  // [{ id, pinned, time, preview, kind, size?, format?, width?, height? }], pins first.
  property list<var> entries: []

  // Detail of the selected entry, fetched on demand.
  property string detailId: ""
  property string detailText: ""
  property bool detailTruncated: false
  property string detailImage: ""

  // Large entries are cut for display; copying still uses the full content.
  readonly property int textLimit: 100000

  function matches(entry, query) {
    const haystack = (entry.kind === "image" ? `image ${entry.format}` : entry.preview).toLowerCase();
    return query.toLowerCase().split(/\s+/).every(word => haystack.includes(word));
  }

  function filter(query) {
    return query.trim() ? root.entries.filter(e => root.matches(e, query.trim())) : root.entries;
  }

  function refresh() {
    listProc.running = true;
  }

  function select(entry) {
    if (!entry || entry.id === root.detailId) return;
    root.detailId = entry.id;
    root.detailText = "";
    root.detailTruncated = false;
    root.detailImage = "";
    detailProc.running = false;
    detailProc.command = [Host.clipboard, entry.kind === "image" ? "image" : "text", entry.id];
    detailProc.kind = entry.kind;
    detailProc.running = true;
  }

  function copy(entry) { root.run(["copy", entry.id]); }
  function remove(entry) { root.run(["delete", entry.id]); }
  function togglePin(entry) { root.run([entry.pinned ? "unpin" : "pin", entry.id]); }
  function wipe() { root.run(["wipe"]); }

  // Actions run one at a time, in order, each followed by a refresh.
  property list<var> queue: []

  function run(args) {
    root.queue = [...root.queue, [Host.clipboard, ...args]];
    if (!actionProc.running) root.next();
  }

  function next() {
    if (!root.queue.length) {
      root.refresh();
      return;
    }
    actionProc.command = root.queue[0];
    root.queue = root.queue.slice(1);
    actionProc.running = true;
  }

  Process {
    id: actionProc
    onExited: root.next()
  }

  Process {
    id: listProc
    command: [Host.clipboard, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        try {
          root.entries = JSON.parse(this.text);
        } catch (e) {
          console.warn(`nyx: bad clipboard list: ${e}`);
        }
        if (!root.entries.some(e => e.id === root.detailId)) root.detailId = "";
      }
    }
  }

  Process {
    id: detailProc
    property string kind: ""
    stdout: StdioCollector {
      onStreamFinished: {
        if (detailProc.kind === "image") {
          root.detailImage = this.text.trim();
        } else {
          root.detailTruncated = this.text.length > root.textLimit;
          root.detailText = this.text.slice(0, root.textLimit);
        }
      }
    }
  }

  // Written by `nyx-clipboard store` on every copy.
  FileView {
    path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/nyx/clipboard/seen.tsv`
    watchChanges: true
    printErrors: false
    onFileChanged: if (GlobalState.clipboardOpen) root.refresh()
  }
}
