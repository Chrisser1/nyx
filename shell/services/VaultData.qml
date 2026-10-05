// The Bitwarden vault for modules/bitwarden, read from `nyx-bitwarden list`,
// which never prompts. Secrets are copied or typed by the helper; nothing
// here ever holds one.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.config

Singleton {
  id: root

  // unconfigured | login | locked | unlocked; "" until the first list.
  property string state: ""
  // [{ id, name, user, folder, type, uri }]
  property list<var> entries: []
  readonly property bool needsSetup: root.state === "unconfigured" || root.state === "login"

  // The focused window's title and class when the panel opened; entries that
  // look like it are offered first.
  property string hint: ""

  function refresh() { listProc.running = true }

  // "github.com" -> "github"; "https://www.login.example.co.uk/x" -> "login".
  function site(uri) {
    const host = (uri || "").replace(/^[a-z]+:\/\//i, "").split(/[\/:?#]/)[0].replace(/^www\./i, "");
    return host.split(".")[0].toLowerCase();
  }

  function suggested(entry) {
    const hint = root.hint.toLowerCase();
    if (!hint) return false;
    const site = root.site(entry.uri);
    if (site.length >= 3 && hint.includes(site)) return true;
    return entry.name.toLowerCase().split(/[\s\-_.]+/).some(w => w.length >= 3 && hint.includes(w));
  }

  function matches(entry, query) {
    const haystack = [entry.name, entry.user, entry.folder, entry.uri].join(" ").toLowerCase();
    return query.toLowerCase().split(/\s+/).filter(Boolean).every(word => haystack.includes(word));
  }

  // Matches for the query; with none typed, suggestions come first.
  function filter(query) {
    const q = query.trim();
    const found = q ? root.entries.filter(e => root.matches(e, q)) : root.entries;
    if (q) return found;
    return [...found.filter(e => root.suggested(e)), ...found.filter(e => !root.suggested(e))];
  }

  function copy(entry, field) { Quickshell.execDetached([Host.bitwarden, "copy", entry.id, field]); }
  function type(entry, field) { Quickshell.execDetached([Host.bitwarden, "type", entry.id, field]); }
  function sync() { Quickshell.execDetached([Host.bitwarden, "sync"]); }

  function lock() {
    lockProc.running = true;
  }

  // Unlocking prompts through pinentry.
  function unlock() {
    if (!unlockProc.running) unlockProc.running = true;
  }

  Process {
    id: listProc
    command: [Host.bitwarden, "list"]
    stdout: StdioCollector {
      onStreamFinished: {
        let data;
        try {
          data = JSON.parse(this.text);
        } catch (e) {
          console.warn(`nyx: bad bitwarden list: ${e}`);
          return;
        }
        root.state = data.state;
        root.entries = data.entries;
      }
    }
  }

  Process {
    id: unlockProc
    command: [Host.bitwarden, "unlock"]
    onExited: root.refresh()
  }

  Process {
    id: lockProc
    command: [Host.bitwarden, "lock"]
    onExited: root.refresh()
  }
}
