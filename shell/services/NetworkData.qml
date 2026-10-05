// Shared NetworkManager state for the bar widget (modules/bar/NetworkWidget.qml)
// and the dropdown (modules/network/WifiPanel.qml), via Quickshell.Networking.
//
// NOTE: Networking.devices and device.networks are lazily-populated ObjectModels
// — reading `.values` from a plain binding does NOT fill them (verified: stays
// empty indefinitely). They only populate once something consumes the model,
// hence the tracker Instantiators below, which also bump the generation counters
// so the derived bindings re-evaluate when the models change under them. This
// lives here rather than in each consumer so there is one copy of that
// workaround, not two drifting apart. Same story for Bluetooth.devices and
// Mpris.players.
//
// This singleton also owns the panel's transient state (pskFor, errorFor, ...).
// WifiPanel is instantiated once per monitor -- shell.qml builds the whole UI
// stack inside a Variants over Quickshell.screens -- so anything the panel wrote
// into here from N instances raced: binding evaluation order is unspecified, and
// the losing write could leave the scanner off (list stuck on "Scanning…") or
// unfreeze the list out from under an open password field.
//
// KNOWN UPSTREAM LIMITATION (quickshell 0.3.1): src/network/nm/backend.cpp does
// not watch the org.freedesktop.NetworkManager bus name for owner changes, so
// after `systemctl restart NetworkManager` every property under `Networking` is
// stale for the life of the process and the bar sticks on "disconnected". There
// is no re-init entry point to call from QML. To reset a degraded link without
// that, use the panel's Wi-Fi switch (it drives Networking.wifiEnabled) or
// `nmcli networking off && nmcli networking on` -- neither drops the bus name.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Networking
import qs

Singleton {
  id: root

  // Bumped by the trackers so the bindings below re-evaluate on population.
  property int deviceGeneration: 0
  property int networkGeneration: 0
  // Separate from networkGeneration on purpose: a connect in flight must not
  // resort the list, it only has to freeze it.
  property int busyGeneration: 0

  readonly property var devices: {
    root.deviceGeneration;   // dependency, forces re-evaluation
    return Networking.devices?.values ?? [];
  }

  readonly property var wifiDevice: root.devices.find(d => d.type === DeviceType.Wifi) ?? null

  // Only wifi and wired devices reach this model -- quickshell's registerDevice()
  // drops loopback, tun and wifi-p2p -- but docked both can be up at once, and
  // `find` would then pick whichever NM happened to enumerate first, flipping the
  // bar between the SSID and `enp2s0`. Prefer the wire: that is what carries the
  // traffic when both are connected.
  readonly property var activeDevice: {
    const up = root.devices.filter(d => d.connected);
    return up.find(d => d.type === DeviceType.Wired) ?? up[0] ?? null;
  }

  readonly property bool isWifi: (root.activeDevice?.type ?? DeviceType.None) === DeviceType.Wifi

  readonly property var activeNetwork: {
    root.networkGeneration;  // same, for the per-device network list
    return root.isWifi
      ? ((root.activeDevice?.networks?.values ?? []).find(n => n.connected) ?? null)
      : null;
  }

  // 0.0 - 1.0, like UPower's battery percentage. Not named `signal`: that is a
  // reserved QML declaration keyword.
  readonly property real strength: activeNetwork?.signalStrength ?? 0
  // SSID on wifi; on ethernet the device name is the interface, e.g. enp2s0.
  readonly property string label: root.isWifi ? (activeNetwork?.name ?? "") : (activeDevice?.name ?? "")

  // The bar and the panel both draw this ramp; keep the buckets in one place.
  readonly property var wifiRamp: ["󰤯", "󰤟", "󰤢", "󰤥", "󰤨"]

  function signalIcon(value: real): string {
    return root.wifiRamp[Math.max(0, Math.min(4, Math.floor(value * 5)))];
  }

  // Every visible wifi network, deduped and ordered for the panel: connected
  // first, then saved, then by strength. Hidden APs come through with a blank
  // name and are dropped — there is nothing to click on and no way to join one
  // from a list.
  //
  // Deliberately recomputed only on networkGeneration (membership changes), not
  // on every signalStrength tick: each row binds straight to its own network
  // object, so strengths stay live while the rows hold still under the cursor.
  readonly property var sortedNetworks: {
    root.networkGeneration;
    const all = root.wifiDevice?.networks?.values ?? [];
    const seen = ({});
    const out = [];
    for (const n of all) {
      if (!n || !n.name)
        continue;
      const at = seen[n.name];
      if (at === undefined) {
        seen[n.name] = out.length;
        out.push(n);
      } else if (!out[at].connected && (n.connected || n.signalStrength > out[at].signalStrength)) {
        // Same SSID on another band or another AP: keep whichever one is
        // connected, else the stronger of the two.
        out[at] = n;
      }
    }
    out.sort((a, b) => {
      if (a.connected !== b.connected) return a.connected ? -1 : 1;
      if (a.known !== b.known) return a.known ? -1 : 1;
      return b.signalStrength - a.signalStrength;
    });
    return out;
  }

  // True while any network is mid-connect.
  readonly property bool connecting: {
    root.busyGeneration;
    return (root.wifiDevice?.networks?.values ?? []).some(n => n?.stateChanging ?? false);
  }

  // What the panel actually lists. Held still while `frozen`, because a
  // ListView whose model is a JS array rebuilds *every* delegate when that
  // array is replaced (verified) -- and a scan result landing mid-typing would
  // otherwise destroy the password field, taking the half-typed password and
  // the keyboard focus with it. `connecting` is in here for the same reason:
  // the connect attempt itself bumps networkGeneration, so without it the rows
  // are rebuilt at exactly the moment a failure is coming back.
  property var networks: []
  readonly property bool frozen: root.pskFor !== "" || root.connecting

  onSortedNetworksChanged: root.publish()
  onFrozenChanged: root.publish()

  function publish(): void {
    if (!root.frozen)
      root.networks = root.sortedNetworks;
  }

  // ── Panel state ────────────────────────────────────────────────────────
  // Owned here rather than in WifiPanel because there is one panel per monitor.

  // SSID whose password row is expanded, "" for none. Only ever one at a time:
  // two open fields on screen invites typing the right password into the wrong
  // network.
  property string pskFor: ""
  // Held out of the TextField so it survives the field being rebuilt under us.
  property string pskText: ""
  // Last failure, shown against the row it belongs to.
  property string errorFor: ""
  property string errorText: ""

  function promptFor(name: string): void {
    root.pskFor = name;
    root.pskText = "";
    root.errorFor = "";
    root.errorText = "";
  }

  function dismiss(): void {
    root.pskFor = "";
    root.pskText = "";
    root.errorFor = "";
    root.errorText = "";
  }

  // 802.1X networks (eduroam, DTUsecure and friends) need an identity, an EAP
  // method and usually a CA certificate. None of that fits in a one-line
  // password box, and connectWithPsk() is not the call for them -- the panel
  // hands an unsaved enterprise network to nm-connection-editor instead.
  // Already-saved ones connect() normally, since NM holds the profile.
  function isEnterprise(net: var): bool {
    switch (net?.security) {
    case WifiSecurityType.WpaEap:
    case WifiSecurityType.Wpa2Eap:
    case WifiSecurityType.Wpa3SuiteB192:
    case WifiSecurityType.DynamicWep:
    case WifiSecurityType.Leap:
      return true;
    default:
      return false;
    }
  }

  // Driven by the panel being open: scanning is only worth its airtime and
  // power while someone is looking at the list, and a scan sweep takes the
  // radio off-channel, which a connected link feels. Derived rather than
  // written by the panel so the per-monitor instances cannot race.
  readonly property bool scanning: GlobalState.wifiOpen

  onScanningChanged: root.applyScanner()
  onWifiDeviceChanged: root.applyScanner()

  // The device the scanner was last handed to, so it can be given back. Without
  // this, a device swapped out under us (dongle re-plug, NM device churn) keeps
  // scanning forever.
  property var scannedDevice: null

  function applyScanner(): void {
    const d = root.wifiDevice;
    const prev = root.scannedDevice;
    if (prev && prev !== d)
      prev.scannerEnabled = false;
    if (d)
      d.scannerEnabled = root.scanning;
    root.scannedDevice = root.scanning ? d : null;
  }

  // NetworkManager decides on its own when to re-sweep while a scan client is
  // active, so a manual rescan is a matter of dropping and re-taking the
  // scanner rather than calling anything.
  function rescan(): void {
    const d = root.wifiDevice;
    if (!d || !root.scanning)
      return;
    d.scannerEnabled = false;
    rescanTimer.restart();
  }

  Timer {
    id: rescanTimer
    interval: 120
    onTriggered: root.applyScanner()
  }

  // Non-visual: exists purely to make the models populate and to notice changes.
  // Must be Instantiator, not Repeater -- Repeater requires Item delegates.
  Instantiator {
    model: Networking.devices
    delegate: QtObject {
      id: devTracker
      required property var modelData
      readonly property bool conn: modelData?.connected ?? false
      onConnChanged: root.deviceGeneration++
      Component.onCompleted: root.deviceGeneration++
      Component.onDestruction: root.deviceGeneration++

      // Each device's network list is lazily populated the same way, and nothing
      // consumed it before: without this the connected AP is never found, so the
      // SSID stays empty and signalStrength reads 0 no matter the real strength.
      property var networkTracker: Instantiator {
        model: devTracker.modelData?.networks ?? null
        delegate: QtObject {
          id: netTracker
          required property var modelData
          readonly property bool conn: modelData?.connected ?? false
          // `known` flips on connect-with-password and on forget, and both
          // change where the row sorts.
          readonly property bool saved: modelData?.known ?? false
          readonly property bool busy: modelData?.stateChanging ?? false
          onConnChanged: root.networkGeneration++
          onSavedChanged: root.networkGeneration++
          onBusyChanged: root.busyGeneration++
          Component.onCompleted: {
            root.networkGeneration++;
            root.busyGeneration++;
          }
          Component.onDestruction: {
            root.networkGeneration++;
            root.busyGeneration++;
          }

          // Lives here rather than on the panel's list delegate: a connect
          // attempt bumps networkGeneration, which republishes `networks` and
          // rebuilds every delegate, so a handler owned by the delegate is
          // destroyed before the failure arrives and the click looks like it
          // did nothing at all. Clicking a *saved* network never opened a
          // password field, so nothing froze the list to cover it.
          property var failures: Connections {
            target: netTracker.modelData
            function onConnectionFailed(reason: int): void {
              root.errorFor = netTracker.modelData.name;
              root.errorText = ConnectionFailReason.toString(reason);
              // A missing or wrong secret is the one failure the user can do
              // something about from here, so re-open the field for it --
              // except on 802.1X, where a bare password is not the answer.
              if (reason === ConnectionFailReason.NoSecrets && !root.isEnterprise(netTracker.modelData))
                root.pskFor = netTracker.modelData.name;
            }
          }
        }
      }
    }
  }
}
