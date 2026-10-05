// Live throughput for whichever link is actually carrying traffic, read from
// /proc/net/dev. Same FileView + Timer idiom as ResourceUsage.qml; nothing here
// shells out.
//
// The interface comes from NetworkData.activeDevice, which already prefers the
// wire over wifi when both are up (see its header), so docking doesn't flip the
// numbers between two links.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services

Singleton {
  id: root

  readonly property string iface: NetworkData.activeDevice?.name ?? ""

  // Bytes per second, averaged over one tick.
  property real rxRate: 0
  property real txRate: 0

  readonly property int historyLength: 60
  property list<real> rxHistory: []
  property list<real> txHistory: []

  // Counter snapshot from the previous tick: { iface: [rxBytes, txBytes] }.
  // Every interface is kept, not just the active one, so switching links picks
  // up a correct delta on the very next tick instead of drawing one spike.
  property var previous: ({})
  property real previousAt: 0

  readonly property int pollInterval: 2000

  function formatRate(bytes: real): string {
    if (bytes >= 1024 * 1024) return (bytes / (1024 * 1024)).toFixed(1) + "M";
    if (bytes >= 1024) return Math.round(bytes / 1024) + "K";
    return Math.round(bytes) + "B";
  }

  Timer {
    // Fires immediately to take the baseline sample, then settles at the real
    // interval -- the trick ResourceUsage.qml uses.
    // Only the system panel shows these numbers, so only sample while it is
    // open. Reopening drops the stale baseline so the first tick is a fresh
    // sample rather than one huge delta spanning the time it was closed.
    interval: 1
    running: GlobalState.sysOpen
    repeat: true
    onRunningChanged: {
      if (running) {
        root.previous = ({})
        interval = 1
      }
    }
    onTriggered: {
      fileNetDev.reload()

      const now = Date.now()
      const current = ({})
      for (const line of fileNetDev.text().split("\n")) {
        // "  enp2s0: 4290 65 0 0 0 0 0 0 1337 12 ..." -- eight receive columns
        // stand between the receive and transmit byte counts.
        const m = line.match(/^\s*([^:\s]+):\s*(\d+)(?:\s+\d+){7}\s+(\d+)/)
        if (!m || m[1] === "lo") continue
        current[m[1]] = [Number(m[2]), Number(m[3])]
      }

      const elapsed = (now - root.previousAt) / 1000
      const prev = root.previous[root.iface]
      const cur = current[root.iface]
      if (prev && cur && elapsed > 0) {
        // The counters reset when an interface goes down and comes back, so a
        // negative delta is a reset rather than a rate. Floor it at zero.
        root.rxRate = Math.max(0, (cur[0] - prev[0]) / elapsed)
        root.txRate = Math.max(0, (cur[1] - prev[1]) / elapsed)
      } else {
        root.rxRate = 0
        root.txRate = 0
      }

      root.previous = current
      root.previousAt = now

      root.rxHistory = [...root.rxHistory, root.rxRate].slice(-root.historyLength)
      root.txHistory = [...root.txHistory, root.txRate].slice(-root.historyLength)

      interval = root.pollInterval
    }
  }

  FileView { id: fileNetDev; path: "/proc/net/dev" }
}
