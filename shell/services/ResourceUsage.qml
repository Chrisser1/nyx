// ┌────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀▄░█▀▀░█▀▀░█▀█░█░█░█▀▄░█▀▀░█▀▀░█▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▀▄░█▀▀░▀▀█░█░█░█░█░█▀▄░█░░░█▀▀░▀▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░▀░▀▀▀░▀▀▀░▀▀▀░▀▀▀░▀░▀░▀▀▀░▀▀▀░▀▀▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                   ├┤
// ││ Repo    : https://github.com/roosta/dotfiles             ││
// ││ Site    : https://www.roosta.sh                          ││
// ├┤ License : GNU General Public License v3                  ├┤
// ┆└──────────────────────────────────────────────────────────┘┆
// Based on: https://github.com/end-4/dots-hyprland/blob/b4920a7cb610c026ec8683f73909400f39097340/dots/.config/quickshell/ii/services/ResourceUsage.qml
// Modified 2025 by Daniel Berg <mail@roosta.sh>

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
  id: root
  property real memoryTotal: 1
  property real memoryFree: 0
  property real memoryUsed: memoryTotal - memoryFree
  property real memoryUsedPercentage: memoryUsed / memoryTotal
  property real swapTotal: 1
  property real swapFree: 0
  property real swapUsed: swapTotal - swapFree
  property real swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
  property real cpuUsage: 0
  property var previousCpuStats
  property string cpuTooltip

  property string maxAvailableMemoryString: kbToGbString(ResourceUsage.memoryTotal)

  // Bare GiB numbers, no unit suffix -- SysmonWidget renders them as "12.4/31.3G",
  // which kbToGbString()'s " GB" suffix makes too wide for the bar.
  readonly property string memoryUsedGb: (memoryUsed / (1024 * 1024)).toFixed(1)
  readonly property string memoryTotalGb: (memoryTotal / (1024 * 1024)).toFixed(1)

  // Seconds since boot, off the same timer as everything else. Rendered in the
  // system panel's header.
  property real uptimeSeconds: 0
  readonly property string uptimeString: {
    const total = Math.floor(root.uptimeSeconds);
    const days = Math.floor(total / 86400);
    const hours = Math.floor((total % 86400) / 3600);
    const minutes = Math.floor((total % 3600) / 60);
    if (days > 0) return `up ${days}d ${hours}h`;
    if (hours > 0) return `up ${hours}h ${minutes}m`;
    return `up ${minutes}m`;
  }

  readonly property int historyLength: 60
  property list<real> cpuUsageHistory: []
  property list<real> memoryUsageHistory: []
  property list<real> swapUsageHistory: []

  function kbToGbString(kb) {
    return (kb / (1024 * 1024)).toFixed(1) + " GB";
  }

  function refreshTooltip() {
    topProc.running = true
  }

  function updateMemoryUsageHistory() {
    memoryUsageHistory = [...memoryUsageHistory, memoryUsedPercentage]
    if (memoryUsageHistory.length > historyLength) {
      memoryUsageHistory.shift()
    }
  }
  function updateSwapUsageHistory() {
    swapUsageHistory = [...swapUsageHistory, swapUsedPercentage]
    if (swapUsageHistory.length > historyLength) {
      swapUsageHistory.shift()
    }
  }
  function updateCpuUsageHistory() {
    cpuUsageHistory = [...cpuUsageHistory, cpuUsage]
    if (cpuUsageHistory.length > historyLength) {
      cpuUsageHistory.shift()
    }
  }
  function updateHistories() {
    updateMemoryUsageHistory()
    updateSwapUsageHistory()
    updateCpuUsageHistory()
  }

  Timer {
    interval: 1
    running: true
    repeat: true
    onTriggered: {
      // Reload files
      fileMeminfo.reload()
      fileStat.reload()
      fileUptime.reload()

      // "510.24 6688.87" -- seconds up, then seconds idle summed over all cores.
      root.uptimeSeconds = Number(fileUptime.text().split(/\s+/)[0] ?? 0)

      // Parse memory and swap usage
      const textMeminfo = fileMeminfo.text()
      root.memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
      root.memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
      root.swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
      root.swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

      // Parse CPU usage
      const textStat = fileStat.text()
      const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
      if (cpuLine) {
        const stats = cpuLine.slice(1).map(Number)
        const total = stats.reduce((a, b) => a + b, 0)
        const idle = stats[3]

        if (root.previousCpuStats) {
          const totalDiff = total - root.previousCpuStats.total
          const idleDiff = idle - root.previousCpuStats.idle
          root.cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
        }

        root.previousCpuStats = { total, idle }
      }

      root.updateHistories()
      interval = 3000
    }
  }

  FileView { id: fileMeminfo; path: "/proc/meminfo" }
  FileView { id: fileStat; path: "/proc/stat" }
  FileView { id: fileUptime; path: "/proc/uptime" }

  Process {
    id: topProc
    command: ["bash", "-c", "ps -eo comm:20,%cpu --sort=-%cpu | head -n 6 | tail -n 5"]
    running: true
    stdout: StdioCollector {
      id: outputCollector
      onStreamFinished: {
        root.cpuTooltip = outputCollector.text.replace(/\n$/, '')
      }
    }
  }
}
