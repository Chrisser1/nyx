// System panel: resource graphs, live throughput, bluetooth devices and a
// killable process list. Dropped from the bar's SystemButton, or on the
// toggleSystem shortcut.
//
// Built on the same sliding-Item idiom as modules/network/WifiPanel.qml: it
// lives inside shell.qml's fullscreen "main" panel, and GlobalState.overlayOpen
// flips that panel's input mask so the contents become clickable. Nothing in it
// is typed into; shell.qml only gives it the keyboard so Escape can close it.
//
// shell.qml builds one of these per monitor, so nothing stateful is kept here:
// the resource histories live in services/ResourceUsage.qml and
// services/NetworkUsage.qml, the device tracker in services/BluetoothData.qml,
// and the process list plus its sort order in services/Processes.qml. See
// services/NetworkData.qml's header for what goes wrong when that is ignored.

pragma ComponentBehavior: Bound

import qs
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Bluetooth

Item {
  id: root
  required property string monitorId

  anchors.top: parent.top
  anchors.topMargin: Style.bar.height
  anchors.right: parent.right
  anchors.rightMargin: Style.spacing.p1

  implicitWidth: Style.system.width
  implicitHeight: Style.system.height

  // The slide happens inside these bounds.
  clip: true

  readonly property bool active: GlobalState.sysOpen
    && GlobalState.sysMonitorId === root.monitorId

  // Only render while on-screen or mid-transition.
  visible: panel.y > -Style.system.height

  // Polling follows GlobalState.sysOpen inside Processes, so there is nothing to
  // mirror from here.

  function openBtop(): void {
    // Detached rather than a Process: `running = true` on an already-running
    // Process is a silent no-op, so a second click would do nothing at all.
    Quickshell.execDetached([Config.terminal, "-e", Host.sysmon])
    GlobalState.closeSys()
  }

  // Everything this panel deliberately doesn't do -- passkey pairing, device
  // profiles, file transfer -- lives in blueman, which bluetooth.nix already
  // enables. Named bare like WifiPanel's nm-connection-editor, and detached for
  // the same reason.
  function openBluetoothManager(): void {
    Quickshell.execDetached(["blueman-manager"])
    GlobalState.closeSys()
  }

  function formatBytes(kb: real): string {
    if (kb >= 1024 * 1024) return (kb / (1024 * 1024)).toFixed(1) + "G";
    if (kb >= 1024) return Math.round(kb / 1024) + "M";
    return Math.round(kb) + "K";
  }

  // ── Local building blocks ──────────────────────────────────────────────

  component Divider: BorderRect {
    Layout.fillWidth: true
    implicitHeight: Style.bar.borderWidth
    color: Style.colors.gray3
    borderWidth: 0
  }

  component SectionTitle: RowLayout {
    id: title
    required property string glyph
    required property string text
    property color tint: Style.colors.gray6
    spacing: Style.spacing.p0

    Text {
      text: title.glyph
      color: title.tint
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      Layout.alignment: Qt.AlignVCenter

      Behavior on color {
        ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
      }
    }
    Text {
      text: title.text
      color: Style.colors.brightWhite
      font.family: Style.font.main
      font.pointSize: Style.font.normal
      Layout.alignment: Qt.AlignVCenter
    }
  }

  component StatRow: RowLayout {
    id: stat
    required property string glyph
    required property string label
    required property var history
    // 0 autoscales -- see components/Sparkline.qml.
    required property real maxValue
    required property color tint
    required property string value

    Layout.fillWidth: true
    Layout.preferredHeight: Style.system.rowHeight
    spacing: Style.spacing.p1

    Text {
      text: stat.glyph
      color: stat.tint
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: Style.font.size4
    }
    Text {
      text: stat.label
      color: Style.colors.white
      font.family: Style.font.main
      font.pointSize: Style.font.tiny
      Layout.alignment: Qt.AlignVCenter
      Layout.preferredWidth: 32 * Config.scale
    }
    Sparkline {
      values: stat.history
      maxValue: stat.maxValue
      tint: stat.tint
      Layout.preferredWidth: Style.system.sparkWidth
      Layout.preferredHeight: Style.system.sparkHeight
      Layout.alignment: Qt.AlignVCenter
    }
    Item { Layout.fillWidth: true }
    Text {
      text: stat.value
      color: Style.colors.brightWhite
      font.family: Style.font.main
      font.pointSize: Style.font.tiny
      horizontalAlignment: Text.AlignRight
      Layout.alignment: Qt.AlignVCenter
    }
  }

  // One delegate for both bluetooth lists: a remembered device and a stranger
  // differ only in which action the click means, and that is already decided
  // per-row from `known`.
  component DeviceList: Item {
    id: devList
    required property var devices
    required property int rows
    property string emptyText: ""

    Layout.fillWidth: true
    Layout.preferredHeight: devList.visible ? Style.system.rowHeight * devList.rows : 0

    ListView {
      id: view
      anchors.fill: parent
      clip: true
      spacing: 0
      model: devList.devices

      delegate: Rectangle {
        id: entry
        required property var modelData

        readonly property bool busy: entry.modelData.state === BluetoothDeviceState.Connecting
          || entry.modelData.state === BluetoothDeviceState.Disconnecting
          || (entry.modelData.pairing ?? false)
        readonly property bool known: BluetoothData.isKnown(entry.modelData)
        readonly property bool named: BluetoothData.hasName(entry.modelData)
        readonly property string nameState: BluetoothData.nameStateFor(entry.modelData)

        width: view.width
        implicitHeight: Style.system.rowHeight
        color: area.containsMouse ? Style.colors.gray1 : "transparent"

        Behavior on color {
          ColorAnimation { duration: Style.durations.tiny; easing.type: Easing.OutQuad }
        }

        MouseArea {
          id: area
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          acceptedButtons: Qt.LeftButton | Qt.RightButton
          onClicked: mouse => {
            const dev = entry.modelData
            if (mouse.button === Qt.RightButton) {
              // Right-click only means anything on a remembered device.
              if (entry.known) dev.forget()
              return
            }
            if (dev.connected) {
              dev.disconnect()
            } else if (entry.known) {
              dev.connect()
            } else {
              // "Just works" pairing only -- nothing here can answer a passkey
              // prompt, so a device that wants one fails silently and the
              // section's settings button is the way out.
              dev.pair()
            }
          }
        }

        RowLayout {
          anchors.fill: parent
          anchors.leftMargin: Style.spacing.p1
          anchors.rightMargin: Style.spacing.p1
          spacing: Style.spacing.p1

          Text {
            text: BluetoothData.glyphFor(entry.modelData)
            color: entry.modelData.connected ? Style.colors.accent : Style.colors.white
            font.family: Style.font.symbols
            font.pointSize: Style.font.small
          }
          Text {
            Layout.fillWidth: true
            // Never BlueZ's address-shaped stand-in dressed up as a name -- see
            // BluetoothData.displayName.
            text: BluetoothData.displayName(entry.modelData)
            elide: Text.ElideRight
            color: {
              if (entry.modelData.connected) return Style.colors.brightWhite;
              // A bare address is weaker information than a name, and should
              // read that way on the row.
              return entry.named ? Style.colors.white : Style.colors.gray6;
            }
            font.family: Style.font.main
            font.pointSize: Style.font.small
          }
          Text {
            visible: entry.modelData.batteryAvailable ?? false
            text: `${Math.round((entry.modelData.battery ?? 0) * 100)}%`
            color: Style.colors.brightGreen
            font.family: Style.font.main
            font.pointSize: Style.font.tiny
          }
          Text {
            text: {
              if (entry.busy) return "…"
              if (entry.modelData.connected) return "connected"
              if (entry.known) return "paired"
              // Name resolution only says anything while the name is missing;
              // once one arrives the row goes back to advertising the action.
              if (!entry.named && entry.nameState === "asking") return "asking…"
              if (!entry.named && entry.nameState === "silent") return "no response"
              return "pair"
            }
            color: {
              if (entry.modelData.connected) return Style.colors.accent;
              if (!entry.named && entry.nameState === "asking") return Style.colors.brightYellow;
              return Style.colors.gray6;
            }
            font.family: Style.font.main
            font.pointSize: Style.font.tiny
          }
        }
      }
    }

    // Empty state. A plain child of the ListView would sit inside its
    // scrolling contentItem, so it's a sibling overlay.
    Text {
      anchors.centerIn: parent
      width: parent.width - Style.spacing.p2 * 2
      visible: view.count === 0 && devList.emptyText !== ""
      horizontalAlignment: Text.AlignHCenter
      wrapMode: Text.WordWrap
      text: devList.emptyText
      color: Style.colors.gray4
      font.family: Style.font.main
      font.pointSize: Style.font.tiny
    }
  }

  component IconButton: Rectangle {
    id: btn
    required property string glyph
    property string label: ""
    // Resting colour; hover always brightens on top of it.
    property color tint: Style.colors.white
    signal activated()

    implicitWidth: row.implicitWidth + Style.spacing.p1 * 2
    implicitHeight: Style.font.size4 + Style.spacing.p0 * 2
    color: area.containsMouse ? Style.colors.gray2 : "transparent"

    Behavior on color {
      ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
    }

    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: Style.spacing.p0

      Text {
        text: btn.glyph
        color: area.containsMouse ? Style.colors.brightWhite : btn.tint
        font.family: Style.font.symbols
        font.pixelSize: Style.font.size2

        Behavior on color {
          ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
        }
      }
      Text {
        visible: btn.label !== ""
        text: btn.label
        color: area.containsMouse ? Style.colors.brightWhite : btn.tint
        font.family: Style.font.main
        font.pointSize: Style.font.tiny

        Behavior on color {
          ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
        }
      }
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.activated()
    }
  }

  // ── Panel ──────────────────────────────────────────────────────────────

  BorderRect {
    id: panel

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: Style.system.height

    // 0 == fully open, -Style.system.height == fully hidden behind the bar.
    y: root.active ? 0 : -Style.system.height

    color: Style.colors.black
    borderColor: Style.colors.gray2
    borderWidth: Style.bar.borderWidth

    Behavior on y {
      NumberAnimation {
        duration: Style.durations.small
        easing.type: Easing.InOutCubic
      }
    }

    // Swallow clicks so they don't reach shell.qml's close-on-click-outside.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: Style.spacing.p2
      spacing: Style.spacing.p1

      // ── Header ───────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p1

        Text {
          text: "󰊚"
          color: Style.colors.accent
          font.family: Style.font.symbols
          font.pixelSize: Style.font.size4
          Layout.alignment: Qt.AlignVCenter
        }
        Text {
          Layout.fillWidth: true
          text: "System"
          color: Style.colors.brightWhite
          font.family: Style.font.main
          font.pointSize: Style.font.large
          Layout.alignment: Qt.AlignVCenter
        }
        Text {
          text: ResourceUsage.uptimeString
          color: Style.colors.gray6
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
          Layout.alignment: Qt.AlignVCenter
        }
      }

      Divider { }

      // ── Resources ────────────────────────────────────────────────────
      StatRow {
        glyph: ""
        label: "CPU"
        history: ResourceUsage.cpuUsageHistory
        maxValue: 1.0
        tint: ResourceUsage.cpuUsage > 0.8 ? Style.colors.brightRed : Style.colors.brightBlue
        value: `${Math.round(ResourceUsage.cpuUsage * 100)}%`
      }
      StatRow {
        glyph: "󰍛"
        label: "RAM"
        history: ResourceUsage.memoryUsageHistory
        maxValue: 1.0
        tint: ResourceUsage.memoryUsedPercentage > 0.9 ? Style.colors.brightRed : Style.colors.brightGreen
        value: `${ResourceUsage.memoryUsedGb}/${ResourceUsage.memoryTotalGb}G`
      }
      StatRow {
        glyph: "󰓡"
        label: "SWAP"
        history: ResourceUsage.swapUsageHistory
        maxValue: 1.0
        tint: ResourceUsage.swapUsedPercentage > 0.5 ? Style.colors.brightYellow : Style.colors.gray6
        value: `${Math.round(ResourceUsage.swapUsedPercentage * 100)}%`
      }

      Divider { }

      // ── Network ──────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p1

        SectionTitle {
          Layout.fillWidth: true
          glyph: "󰌗"
          text: "Network"
        }
        Text {
          // Interface, not SSID: NetworkData.label already shows the SSID up in
          // the bar, and the rates below are per-interface.
          text: NetworkUsage.iface === "" ? "offline" : NetworkUsage.iface
          color: NetworkUsage.iface === "" ? Style.colors.brightBlack : Style.colors.white
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
        IconButton {
          glyph: "󰤨"
          label: "wifi"
          // Hand off rather than reimplement the picker.
          onActivated: GlobalState.toggleWifi(root.monitorId)
        }
      }

      StatRow {
        glyph: "󰇚"
        label: "DOWN"
        history: NetworkUsage.rxHistory
        maxValue: 0
        tint: Style.colors.brightCyan
        value: NetworkUsage.formatRate(NetworkUsage.rxRate) + "/s"
      }
      StatRow {
        glyph: "󰕒"
        label: "UP"
        history: NetworkUsage.txHistory
        maxValue: 0
        tint: Style.colors.brightMagenta
        value: NetworkUsage.formatRate(NetworkUsage.txRate) + "/s"
      }

      Divider { }

      // ── Bluetooth ────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p1

        SectionTitle {
          Layout.fillWidth: true
          // Swaps to the searching mark while a sweep is live, so the state is
          // readable without watching the list for new rows.
          glyph: BluetoothData.scanning ? "󰂳" : "󰂯"
          tint: BluetoothData.scanning ? Style.colors.accent : Style.colors.gray6
          text: "Bluetooth"
        }

        Text {
          visible: !BluetoothData.hasAdapter
          text: "no adapter"
          color: Style.colors.brightYellow
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }

        IconButton {
          visible: BluetoothData.enabled
          glyph: "󰍉"
          label: "scan"
          tint: BluetoothData.scanning ? Style.colors.accent : Style.colors.white
          onActivated: BluetoothData.scanRequested = !BluetoothData.scanRequested
        }

        IconButton {
          visible: BluetoothData.hasAdapter
          glyph: "󰒓"
          // quickshell exposes pair() but no way to answer a passkey prompt, so
          // anything that wants a confirmation code needs a real manager.
          onActivated: root.openBluetoothManager()
        }

        Switch {
          id: btRadio
          visible: BluetoothData.hasAdapter
          checked: BluetoothData.enabled
          implicitHeight: Style.font.size4 + Style.spacing.p0

          // Not a two-way binding on `checked`: BlueZ owns this state and may
          // refuse or lag, so drive it from the click and let the property above
          // pull the visual back to the truth. Same reasoning as WifiPanel's
          // radio switch.
          onToggled: {
            if (BluetoothData.adapter) BluetoothData.adapter.enabled = btRadio.checked
          }

          indicator: Rectangle {
            implicitWidth: Style.font.size4 * 2
            implicitHeight: Style.font.size4
            radius: height / 2
            color: btRadio.checked ? Style.colors.accent : Style.colors.gray3

            Behavior on color {
              ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
            }

            Rectangle {
              x: btRadio.checked ? parent.width - width - 2 : 2
              anchors.verticalCenter: parent.verticalCenter
              width: parent.height - 4
              height: width
              radius: height / 2
              color: Style.colors.brightWhite

              Behavior on x {
                NumberAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
              }
            }
          }

          background: null
        }
      }

      // Remembered devices. Three rows, then it scrolls -- the process list
      // below is what should get the leftover height, not a pile of headsets.
      DeviceList {
        devices: BluetoothData.knownDevices
        rows: 3
        emptyText: {
          if (!BluetoothData.hasAdapter) return "No bluetooth adapter.";
          if (!BluetoothData.enabled) return "Bluetooth is off.";
          return "Nothing paired yet — scan to find a device.";
        }
      }

      // ── Nearby ───────────────────────────────────────────────────────
      // Only while a sweep is live: BlueZ keeps devices it found hanging around
      // for a while after discovery stops, and a list of stale strangers is
      // worse than no list. Both rows collapse so the processes reclaim the
      // height.
      RowLayout {
        Layout.fillWidth: true
        visible: BluetoothData.scanning
        spacing: Style.spacing.p1

        Text {
          text: "nearby"
          color: Style.colors.gray6
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
        BorderRect {
          Layout.fillWidth: true
          Layout.alignment: Qt.AlignVCenter
          implicitHeight: Style.bar.borderWidth
          color: Style.colors.gray3
          borderWidth: 0
        }
        Text {
          text: "scanning…"
          color: Style.colors.accent
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
      }

      DeviceList {
        visible: BluetoothData.scanning
        devices: BluetoothData.nearbyDevices
        rows: 4
        // No RSSI: quickshell 0.3.1's BluetoothDevice exposes no signal
        // strength, so there is nothing to sort or filter weak results by and
        // the wait is the only thing to report.
        emptyText: "Looking for devices…"
      }

      Divider { }

      // ── Processes ────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p1

        SectionTitle {
          Layout.fillWidth: true
          glyph: "󰉹"
          text: "Processes"
        }
        // The two labels double as the sort control; the active one is tinted.
        IconButton {
          glyph: ""
          label: "cpu"
          opacity: Processes.sortKey === "%cpu" ? 1 : 0.5
          onActivated: Processes.setSort("%cpu")
        }
        IconButton {
          glyph: "󰍛"
          label: "mem"
          opacity: Processes.sortKey === "%mem" ? 1 : 0.5
          onActivated: Processes.setSort("%mem")
        }
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
          id: procList
          anchors.fill: parent
          clip: true
          spacing: 0
          model: Processes.list

          delegate: Rectangle {
            id: procEntry
            required property var modelData

            width: procList.width
            implicitHeight: Style.system.rowHeight
            color: procArea.containsMouse ? Style.colors.gray1 : "transparent"

            Behavior on color {
              ColorAnimation { duration: Style.durations.tiny; easing.type: Easing.OutQuad }
            }

            MouseArea {
              id: procArea
              anchors.fill: parent
              hoverEnabled: true
            }

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.p1
              anchors.rightMargin: Style.spacing.p1
              spacing: Style.spacing.p1

              Text {
                Layout.fillWidth: true
                text: procEntry.modelData.name
                elide: Text.ElideRight
                color: Style.colors.white
                font.family: Style.font.main
                font.pointSize: Style.font.small
              }
              Text {
                text: `${procEntry.modelData.cpu.toFixed(1)}%`
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 42 * Config.scale
                color: procEntry.modelData.cpu > 50 ? Style.colors.brightRed : Style.colors.brightBlue
                font.family: Style.font.main
                font.pointSize: Style.font.tiny
              }
              Text {
                text: root.formatBytes(procEntry.modelData.rss)
                horizontalAlignment: Text.AlignRight
                Layout.preferredWidth: 46 * Config.scale
                color: Style.colors.brightGreen
                font.family: Style.font.main
                font.pointSize: Style.font.tiny
              }
              Text {
                // Only offered on hover: this sends a signal to a real process,
                // so it should not sit under the cursor by accident.
                opacity: procArea.containsMouse ? 1 : 0
                text: "󰅖"
                color: killArea.containsMouse ? Style.colors.brightRed : Style.colors.gray6
                font.family: Style.font.symbols
                font.pointSize: Style.font.tiny
                Layout.preferredWidth: Style.font.size2

                Behavior on opacity {
                  NumberAnimation { duration: Style.durations.tiny }
                }

                MouseArea {
                  id: killArea
                  anchors.fill: parent
                  anchors.margins: -Style.spacing.p0
                  hoverEnabled: true
                  enabled: procArea.containsMouse
                  cursorShape: Qt.PointingHandCursor
                  onClicked: Processes.kill(procEntry.modelData.pid)
                }
              }
            }
          }
        }

        Text {
          anchors.centerIn: parent
          visible: procList.count === 0
          text: "Reading process table…"
          color: Style.colors.gray4
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
      }

      Divider { }

      // ── Footer ───────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p0

        Text {
          text: `SIGTERM on ✕ · ${ResourceUsage.maxAvailableMemoryString} total`
          color: Style.colors.gray6
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }

        Item { Layout.fillWidth: true }

        IconButton {
          glyph: "󰍛"
          label: "btop"
          onActivated: root.openBtop()
        }
      }
    }
  }
}
