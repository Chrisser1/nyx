// Runs commands one at a time, in order. A failure sets `error` to its stderr;
// drained() follows the last command.

import QtQuick
import Quickshell.Io

QtObject {
  id: root

  property list<var> pending: []
  property string error: ""
  readonly property bool busy: proc.running

  signal drained()

  function run(command) {
    root.pending = [...root.pending, command];
    if (!proc.running) root.next();
  }

  function next() {
    if (!root.pending.length) {
      root.drained();
      return;
    }
    proc.command = root.pending[0];
    root.pending = root.pending.slice(1);
    proc.running = true;
  }

  readonly property Process proc: Process {
    stderr: StdioCollector { id: errors }
    onExited: code => {
      root.error = code === 0 ? "" : (errors.text.trim() || `${proc.command[1]} failed`);
      root.next();
    }
  }
}
