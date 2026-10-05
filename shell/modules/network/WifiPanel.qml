// Wifi picker, dropped from the bar when the network widget is clicked (or on
// the toggleWifi shortcut). Replaces reaching for nmtui to connect, disconnect
// or join something new.
//
// Built on the same sliding-Item idiom as modules/calendar/CalendarPanel.qml:
// it lives inside shell.qml's fullscreen "main" panel, and
// GlobalState.overlayOpen is what flips that panel's input mask so the contents
// become clickable. Like the calendar it floats over the windows rather than
// bumping the exclusion zone. Unlike the calendar it genuinely needs the
// keyboard for the password field, which shell.qml grants with OnDemand focus.
//
// Everything here talks to NetworkManager through Quickshell.Networking, so
// there is no nmcli to shell out to and no helper binary. Network list state
// *and* the transient panel state (which row is prompting for a password, which
// one last failed) both live in services/NetworkData.qml -- see its header for
// the lazy-model trap and for why this panel owns none of it: shell.qml builds
// one of these per monitor, so anything kept here would exist N times over.

pragma ComponentBehavior: Bound

import qs
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Networking

Item {
  id: root
  required property string monitorId

  anchors.top: parent.top
  anchors.topMargin: Style.bar.height
  anchors.right: parent.right
  anchors.rightMargin: Style.spacing.p1

  implicitWidth: Style.wifi.width
  implicitHeight: Style.wifi.height

  // The slide happens inside these bounds.
  clip: true

  readonly property bool active: GlobalState.wifiOpen
    && GlobalState.wifiMonitorId === root.monitorId

  // Only render while on-screen or mid-transition.
  visible: panel.y > -Style.wifi.height

  // Scanning follows GlobalState.wifiOpen inside NetworkData, so there is
  // nothing to mirror from here. Closing just drops whatever was half typed.
  // The toggleWifi shortcut is registered once, in shell.qml, rather than once
  // per monitor from in here.
  onActiveChanged: {
    if (!root.active) {
      NetworkData.dismiss()
    }
  }

  // Anything this panel deliberately doesn't do -- static addresses, VPNs,
  // 802.1X -- lives in NetworkManager's own editor. Detached rather than a
  // Process: `running = true` on an already-running Process is a silent no-op,
  // so a second click did nothing at all.
  function openEditor(): void {
    Quickshell.execDetached(["nm-connection-editor"])
    GlobalState.closeWifi()
  }

  component IconButton: Rectangle {
    id: btn
    required property string glyph
    property string label: ""
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
        color: area.containsMouse ? Style.colors.brightWhite : Style.colors.white
        font.family: Style.font.symbols
        font.pixelSize: Style.font.size2
      }
      Text {
        visible: btn.label !== ""
        text: btn.label
        color: area.containsMouse ? Style.colors.brightWhite : Style.colors.white
        font.family: Style.font.main
        font.pointSize: Style.font.tiny
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

  BorderRect {
    id: panel

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: Style.wifi.height

    // 0 == fully open, -Style.wifi.height == fully hidden behind the bar.
    y: root.active ? 0 : -Style.wifi.height

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

      // ── Header: radio toggle ─────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p1

        Text {
          Layout.fillWidth: true
          text: "Wi-Fi"
          color: Style.colors.brightWhite
          font.family: Style.font.main
          font.pointSize: Style.font.normal
        }

        Text {
          // A killswitch is not something the shell can undo, so say so
          // instead of offering a toggle that silently does nothing.
          visible: !Networking.wifiHardwareEnabled
          text: "blocked"
          color: Style.colors.brightYellow
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }

        Switch {
          id: radio
          visible: Networking.wifiHardwareEnabled
          checked: Networking.wifiEnabled
          implicitHeight: Style.font.size4 + Style.spacing.p0

          // Not a two-way binding on `checked`: NetworkManager is the owner of
          // this state and may refuse or lag, so drive it from the click and
          // let the property above pull the visual back to the truth.
          onToggled: Networking.wifiEnabled = radio.checked

          indicator: Rectangle {
            implicitWidth: Style.font.size4 * 2
            implicitHeight: Style.font.size4
            radius: height / 2
            color: radio.checked ? Style.colors.accent : Style.colors.gray3

            Behavior on color {
              ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
            }

            Rectangle {
              x: radio.checked ? parent.width - width - 2 : 2
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

      BorderRect {
        Layout.fillWidth: true
        implicitHeight: Style.bar.borderWidth
        color: Style.colors.gray3
        borderWidth: 0
      }

      // ── Network list ─────────────────────────────────────────────────
      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
          id: list
          anchors.fill: parent
          clip: true
          spacing: 0
          model: NetworkData.networks

          delegate: Item {
            id: entry
            required property var modelData

            readonly property bool secured: entry.modelData.security !== WifiSecurityType.Open
            readonly property bool enterprise: NetworkData.isEnterprise(entry.modelData)
            readonly property bool prompting: NetworkData.pskFor === entry.modelData.name
            readonly property bool failed: NetworkData.errorFor === entry.modelData.name

            width: list.width
            implicitHeight: rows.implicitHeight

            // The connectionFailed handler used to live here. It had to move to
            // NetworkData's per-network tracker: a connect attempt republishes
            // `networks`, which rebuilds every delegate, so a handler owned by
            // the delegate was destroyed before the failure came back and the
            // click looked like it did nothing.

            ColumnLayout {
              id: rows
              width: parent.width
              spacing: 0

              Rectangle {
                Layout.fillWidth: true
                implicitHeight: Style.wifi.rowHeight
                color: rowArea.containsMouse ? Style.colors.gray1 : "transparent"

                Behavior on color {
                  ColorAnimation { duration: Style.durations.tiny; easing.type: Easing.OutQuad }
                }

                MouseArea {
                  id: rowArea
                  anchors.fill: parent
                  hoverEnabled: true
                  cursorShape: Qt.PointingHandCursor
                  acceptedButtons: Qt.LeftButton | Qt.RightButton
                  onClicked: mouse => {
                    const net = entry.modelData
                    if (mouse.button === Qt.RightButton) {
                      // Right-click only means anything on a saved network.
                      if (net.known) {
                        if (NetworkData.pskFor === net.name) NetworkData.dismiss()
                        net.forget()
                      }
                      return
                    }
                    if (net.connected) {
                      net.disconnect()
                    } else if (net.known || !entry.secured) {
                      // Saved, or open: NM has everything it needs already.
                      net.connect()
                    } else if (entry.enterprise) {
                      // Nothing useful this panel can ask for -- see
                      // NetworkData.isEnterprise.
                      root.openEditor()
                    } else if (entry.prompting) {
                      NetworkData.dismiss()
                    } else {
                      NetworkData.promptFor(net.name)
                    }
                  }
                }

                RowLayout {
                  anchors.fill: parent
                  anchors.leftMargin: Style.spacing.p1
                  anchors.rightMargin: Style.spacing.p1
                  spacing: Style.spacing.p1

                  Text {
                    text: NetworkData.signalIcon(entry.modelData.signalStrength)
                    color: entry.modelData.connected ? Style.colors.accent : Style.colors.white
                    font.family: Style.font.symbols
                    font.pointSize: Style.font.small
                  }

                  Text {
                    Layout.fillWidth: true
                    text: entry.modelData.name
                    elide: Text.ElideRight
                    color: entry.modelData.connected ? Style.colors.brightWhite : Style.colors.white
                    font.family: Style.font.main
                    font.pointSize: Style.font.small
                  }

                  Text {
                    visible: entry.secured
                    text: "󰌾"
                    color: Style.colors.gray6
                    font.family: Style.font.symbols
                    font.pointSize: Style.font.tiny
                  }

                  Text {
                    text: {
                      if (entry.modelData.stateChanging) return "…"
                      if (entry.modelData.connected) return "connected"
                      if (entry.modelData.known) return "saved"
                      // Warn before the click, so it isn't a surprise that this
                      // one opens the editor instead of a password box.
                      if (entry.enterprise) return "802.1X"
                      return ""
                    }
                    color: entry.modelData.connected ? Style.colors.accent : Style.colors.gray6
                    font.family: Style.font.main
                    font.pointSize: Style.font.tiny
                  }
                }
              }

              // ── Inline password entry ──────────────────────────────────
              Loader {
                Layout.fillWidth: true
                Layout.leftMargin: Style.spacing.p3
                Layout.rightMargin: Style.spacing.p1
                Layout.bottomMargin: active ? Style.spacing.p0 : 0
                // `root.active` matters as well as `prompting`: pskFor is shared
                // across monitors now, so without it the off-screen panel would
                // build a second field for the same row and grab focus.
                active: entry.prompting && root.active

                sourceComponent: TextField {
                  id: psk
                  echoMode: TextInput.Password
                  leftPadding: Style.spacing.p1
                  renderType: TextField.NativeRendering
                  cursorVisible: activeFocus
                  color: Style.colors.brightWhite
                  placeholderTextColor: entry.failed ? Style.colors.brightRed : Style.colors.gray6
                  font.family: Style.font.light
                  font.pointSize: Style.font.small
                  placeholderText: entry.failed ? `  ${NetworkData.errorText}` : "  Password"

                  // The row was clicked to get here, so the field is what the
                  // user is after -- unlike the calendar's quick-add, which is
                  // incidental to a panel opened for a glance.
                  Component.onCompleted: {
                    psk.text = NetworkData.pskText
                    psk.forceActiveFocus()
                  }
                  onTextChanged: NetworkData.pskText = psk.text

                  background: Rectangle {
                    color: "transparent"
                    border.color: {
                      if (entry.failed) return Style.colors.brightRed
                      return psk.activeFocus ? Style.colors.gray6 : Style.colors.gray3
                    }

                    Behavior on border.color {
                      ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
                    }
                  }

                  onAccepted: {
                    if (psk.text === "") return
                    entry.modelData.connectWithPsk(psk.text)
                    NetworkData.dismiss()
                  }

                  Keys.onEscapePressed: NetworkData.dismiss()
                }
              }
            }
          }
        }

        // Empty state. A plain child of the ListView would sit inside its
        // scrolling contentItem, so it's a sibling overlay.
        Text {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.p2 * 2
          visible: list.count === 0
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          color: Style.colors.gray4
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
          text: {
            if (!Networking.wifiHardwareEnabled) return "Wi-Fi is blocked by a hardware switch."
            if (!Networking.wifiEnabled) return "Wi-Fi is off."
            if (NetworkData.wifiDevice === null) return "No wireless device."
            return "Scanning…"
          }
        }
      }

      BorderRect {
        Layout.fillWidth: true
        implicitHeight: Style.bar.borderWidth
        color: Style.colors.gray3
        borderWidth: 0
      }

      // ── Footer ───────────────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p0

        IconButton {
          glyph: "󰑓"
          label: "rescan"
          onActivated: NetworkData.rescan()
        }

        Item { Layout.fillWidth: true }

        IconButton {
          glyph: "󰒓"
          label: "settings"
          onActivated: root.openEditor()
        }
      }
    }
  }
}
