// Top processes for the system panel's kill list, from one `ps` per tick.
//
// The timer only runs while GlobalState.sysOpen, so a closed panel forks
// nothing. A /proc walk would avoid the fork entirely but needs one FileView per
// pid, which is worse for the handful of rows this shows.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs

Singleton {
  id: root

  // Goes straight to `ps --sort`, prefixed with a minus for descending.
  property string sortKey: "%cpu"
  readonly property int rows: 15

  // [{ pid, name, cpu, mem, rss }], already truncated to `rows`.
  property var list: []

  function setSort(key: string): void {
    if (root.sortKey === key) return
    root.sortKey = key
    root.refresh()
  }

  function refresh(): void {
    // `running = true` on an already-running Process is a silent no-op, so this
    // can never stack two `ps` calls.
    psProc.running = true
  }

  // SIGTERM only, and as the session user: anything that needs more than that
  // wants btop, which the panel's footer opens.
  function kill(pid: int): void {
    if (!pid) return
    Quickshell.execDetached(["kill", "-TERM", String(pid)])
    settle.restart()
  }

  Process {
    id: psProc
    // The trailing `=` on each field suppresses its header, so there is no
    // header line to skip.
    command: ["ps", "-eo", "pid=,comm=,%cpu=,%mem=,rss=", "--sort=-" + root.sortKey]
    stdout: StdioCollector {
      id: psOut
      onStreamFinished: {
        const parsed = []
        for (const line of psOut.text.split("\n")) {
          // comm can contain spaces, so anchor on the three numeric columns at
          // the end rather than splitting on whitespace.
          const m = line.trim().match(/^(\d+)\s+(.+?)\s+([\d.]+)\s+([\d.]+)\s+(\d+)$/)
          if (!m) continue
          parsed.push({
            pid: Number(m[1]),
            name: m[2],
            cpu: Number(m[3]),
            mem: Number(m[4]),
            rss: Number(m[5])
          })
          if (parsed.length >= root.rows) break
        }
        root.list = parsed
      }
    }
  }

  Timer {
    interval: 2000
    running: GlobalState.sysOpen
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  // A killed process takes a moment to actually go; re-read once so the row
  // disappears with the click instead of on the next full tick.
  Timer {
    id: settle
    interval: 400
    onTriggered: root.refresh()
  }
}
