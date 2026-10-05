// Clipboard history for modules/clipboard, backed by the nyx-clipboard helper.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config
import qs.utils

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

  // Overlapping refreshes run one after another.
  property bool refreshPending: false

  function refresh() {
    if (listProc.running) root.refreshPending = true;
    else listProc.running = true;
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

  function copy(entry) { actions.run([Host.clipboard, "copy", entry.id]); }
  function remove(entry) { actions.run([Host.clipboard, "delete", entry.id]); }
  function togglePin(entry) { actions.run([Host.clipboard, entry.pinned ? "unpin" : "pin", entry.id]); }
  function wipe() { actions.run([Host.clipboard, "wipe"]); }

  readonly property CommandQueue actions: CommandQueue {
    onDrained: root.refresh()
  }

  Process {
    id: listProc
    command: [Host.clipboard, "list"]
    onExited: {
      if (!root.refreshPending) return;
      root.refreshPending = false;
      Qt.callLater(root.refresh);
    }
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
    onFileChanged: if (GlobalState.clipboardOpen && !root.actions.busy) root.refresh()
  }
}
