// Shared Bluetooth state for the bar widget (modules/bar/BluetoothWidget.qml)
// and the system panel (modules/system/SysPanel.qml).
//
// Bluetooth.devices is a lazily-populated ObjectModel: reading `.values` from a
// plain binding does not fill it, and it does not re-trigger bindings when it
// changes underneath. The Instantiator below forces it and bumps a generation
// counter that the derived bindings depend on. This is the same trap
// services/NetworkData.qml documents at length for Networking.devices.
//
// It lives here rather than in the widget because SysPanel is built once per
// monitor -- shell.qml wraps the whole UI in a Variants over Quickshell.screens
// -- so a tracker owned by the panel would exist N times over. The discovery
// lifecycle below is here for the same reason, and it matters more: N panels
// writing `discovering` would race, and the loser could leave the adapter
// sweeping forever.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import Quickshell.Io
import qs
import qs.config

Singleton {
  id: root

  readonly property var adapter: Bluetooth.defaultAdapter
  readonly property bool hasAdapter: root.adapter !== null
  readonly property bool enabled: root.adapter?.enabled ?? false

  // Bumped by the tracker so the bindings below re-evaluate on population.
  property int deviceGeneration: 0

  // A sweep turns up devices the whole time it runs, so the queue is topped up
  // every time the set changes rather than once when scanning starts.
  onDeviceGenerationChanged: root.enqueueUnnamed()

  readonly property var devices: {
    root.deviceGeneration;   // dependency, forces re-evaluation
    return Bluetooth.devices?.values ?? [];
  }

  readonly property var connectedDevices: root.devices.filter(d => d.connected)

  function isKnown(device: var): bool {
    return (device?.paired ?? false) || (device?.bonded ?? false);
  }

  // ── Names ──────────────────────────────────────────────────────────────
  //
  // `name` is BlueZ's Alias and `deviceName` its Name. When a remote never told
  // us what it is called, BlueZ does NOT leave Alias empty -- it synthesises one
  // from the address, which is where rows like "22-23-ef-35-33" come from. So
  // `deviceName` being empty, not the shape of `name`, is what says "no name".

  readonly property var addressAliasRe: /^[0-9A-Fa-f]{2}([-:][0-9A-Fa-f]{2}){1,5}$/

  function hasName(device: var): bool {
    if ((device?.deviceName ?? "") !== "") return true;
    // A hand-set alias on a device that never reported a name is still a real
    // name; BlueZ's address-shaped stand-in is not.
    const alias = device?.name ?? "";
    return alias !== "" && !root.addressAliasRe.test(alias);
  }

  // Address comes back canonical (AA:BB:CC:DD:EE:FF) -- the dash form only ever
  // came from the synthesised alias.
  function displayName(device: var): string {
    return root.hasName(device) ? device.name : (device?.address ?? "");
  }

  // Everything BlueZ remembers: connected first, then the rest alphabetically,
  // so the row you came to click doesn't move as states change.
  readonly property var knownDevices: {
    return root.devices.filter(d => root.isKnown(d)).sort((a, b) => {
      if (a.connected !== b.connected) return a.connected ? -1 : 1;
      return (a.name ?? "").localeCompare(b.name ?? "");
    });
  }

  // Everything else -- devices that only exist because a sweep found them.
  // Named first: the four rows on screen should be the ones worth reading, with
  // the addresses that never answered sinking below the fold.
  readonly property var nearbyDevices: {
    root.nameGeneration;   // resolving a name re-sorts the list
    return root.devices.filter(d => !root.isKnown(d)).sort((a, b) => {
      const named = root.hasName(a) - root.hasName(b);
      if (named !== 0) return -named;
      return root.displayName(a).localeCompare(root.displayName(b));
    });
  }

  // ── Discovery ──────────────────────────────────────────────────────────
  //
  // Modelled on NetworkData's wifi scanner, with one difference: a bluetooth
  // sweep takes the radio off-channel hard enough for a connected A2DP headset
  // to hear it, so it is opt-in rather than tied to the panel simply being open.

  // The only thing the panel writes. Everything else is derived from it.
  property bool scanRequested: false

  // Derived, never assigned: closing the panel or killing the radio ends the
  // sweep without any caller having to remember to. A panel that wrote
  // `discovering` directly would leave it on when it was destroyed.
  readonly property bool scanning: root.scanRequested && GlobalState.sysOpen && root.enabled

  onScanningChanged: {
    root.applyScanner()
    if (root.scanning) {
      scanTimeout.restart()
      root.probeBudget = root.maxProbesPerScan
      root.pumpNames()
    } else {
      scanTimeout.stop()
      root.cancelProbe()
    }
  }
  onAdapterChanged: root.applyScanner()

  // The adapter the sweep was last handed to, so it can be stopped again.
  // Without this, an adapter swapped out from under us (dongle re-plug, BlueZ
  // restart) keeps discovering for the life of the process.
  property var scannedAdapter: null

  function applyScanner(): void {
    const a = root.adapter;
    const prev = root.scannedAdapter;
    if (prev && prev !== a)
      prev.discovering = false;
    if (a)
      a.discovering = root.scanning;
    root.scannedAdapter = root.scanning ? a : null;
  }

  // Give the sweep back on the way out rather than relying on the process
  // dying. Normal open/close is handled by `scanning` above; this is for the
  // shell being reloaded or shut down mid-scan.
  Component.onDestruction: {
    if (root.scannedAdapter)
      root.scannedAdapter.discovering = false;
  }

  // Adopt an adapter that is somehow already sweeping when we arrive, so the
  // stop above has something to act on. Guarded rather than an unconditional
  // reconcile: writing `discovering = false` to an idle adapter makes BlueZ
  // answer "No discovery started" and log a warning on every shell start.
  //
  // Not a cure for a reload mid-scan: BlueZ scopes its discovery client to the
  // process, which outlives the reload, and quickshell's per-adapter bookkeeping
  // then refuses the stop. That sweep ends when the process does.
  Component.onCompleted: {
    if (root.adapter?.discovering ?? false) {
      root.scannedAdapter = root.adapter;
      root.applyScanner();
    }
  }

  // ── Name resolution ────────────────────────────────────────────────────
  //
  // BlueZ fills in a device's Name from whatever the remote volunteers: an
  // inquiry response for classic devices, the Complete Local Name in an
  // advertisement for LE ones. Plenty of devices volunteer nothing, and there is
  // no "resolve the name" call on org.bluez.Device1 -- nor any generic DBus
  // client in quickshell's QML -- so an actual Remote Name Request means
  // shelling out to hcitool.
  //
  // That only works for BR/EDR. An LE-only device, and anything using a rotating
  // privacy address (most phones, most beacons), will never answer it. Hence the
  // attempt budget and the permanent `silent` mark: asking a beacon forever is
  // pure radio noise, and "no response" is the honest thing to show.

  // address -> { attempts: int, state: "asking" | "named" | "silent" }
  property var nameState: ({})
  // Bumped on every transition; bindings that read nameState depend on it, the
  // same way the device bindings depend on deviceGeneration.
  property int nameGeneration: 0

  readonly property int maxNameAttempts: 2
  readonly property int maxProbesPerScan: 8
  // Counts down over a scan so a room full of beacons cannot monopolise the
  // radio. Reset when a sweep starts, not when one ends.
  property int probeBudget: 0

  property var nameQueue: []
  property string probingAddress: ""

  function nameStateFor(device: var): string {
    root.nameGeneration;   // dependency
    return root.nameState[device?.address ?? ""]?.state ?? "";
  }

  function setNameState(address: string, state: string, attempts: int): void {
    const next = Object.assign({}, root.nameState);
    next[address] = { attempts: attempts, state: state };
    root.nameState = next;
    root.nameGeneration++;
  }

  // Called whenever the device set changes -- a sweep turns up new devices the
  // whole time it runs.
  function enqueueUnnamed(): void {
    if (!root.scanning) return;
    // Measured in a busy room: a sweep turns up 120+ devices, and without this
    // the queue kept growing long after the budget was spent, making every
    // generation bump an O(n^2) walk in the UI thread for probes that could
    // never run.
    if (root.probeBudget <= 0) return;

    const fresh = [];
    for (const d of root.devices) {
      const addr = d.address ?? "";
      if (addr === "" || root.hasName(d)) continue;
      const rec = root.nameState[addr];
      // "named" and "silent" are terminal. Not clearing them between sweeps is
      // the whole point: a device that stayed quiet is not asked again.
      if (rec && (rec.state === "named" || rec.state === "silent")) continue;
      if (addr === root.probingAddress || root.nameQueue.includes(addr)) continue;
      fresh.push(d);
    }

    // BlueZ only knows an icon for a device that reported a class of device,
    // which is a classic inquiry response -- exactly the devices `hcitool name`
    // can reach. Spend the budget on those first. This reorders rather than
    // excludes: an address that merely looks like an LE random one is still
    // asked, just last.
    fresh.sort((a, b) => ((b.icon ?? "") !== "") - ((a.icon ?? "") !== ""));
    root.nameQueue = [...root.nameQueue, ...fresh.map(d => d.address)];
    root.pumpNames();
  }

  function pumpNames(): void {
    if (root.probingAddress !== "") return;          // one at a time
    if (!root.scanning || root.probeBudget <= 0) return;
    if (root.nameQueue.length === 0) return;

    const addr = root.nameQueue[0];
    root.nameQueue = root.nameQueue.slice(1);

    // It may have named itself while it sat in the queue.
    const device = root.devices.find(d => d.address === addr);
    if (!device || root.hasName(device)) {
      root.pumpNames();
      return;
    }

    root.probeBudget--;
    root.probingAddress = addr;
    root.setNameState(addr, "asking", root.nameState[addr]?.attempts ?? 0);
    // Cleared per probe rather than trusting the collector to reset between
    // runs: a stale `text` would put the previous device's name on this one.
    root.probeOutput = "";
    probeTimeout.restart();
    nameProbe.exec([Host.hcitool, "name", addr]);
  }

  function finishProbe(resolved: string): void {
    const addr = root.probingAddress;
    if (addr === "") return;
    probeTimeout.stop();
    root.probingAddress = "";

    const name = (resolved ?? "").trim();
    if (name !== "") {
      // Writing `name` sets the BlueZ alias, so the device stays readable later
      // without asking again.
      const device = root.devices.find(d => d.address === addr);
      if (device) device.name = name;
      root.setNameState(addr, "named", root.nameState[addr]?.attempts ?? 0);
    } else {
      // A name request pages the device while an inquiry is running, so one
      // failure can be timing rather than silence. The second attempt is for
      // that; after it, stop asking.
      const attempts = (root.nameState[addr]?.attempts ?? 0) + 1;
      if (attempts < root.maxNameAttempts) {
        root.setNameState(addr, "", attempts);
        root.nameQueue = [...root.nameQueue, addr];
      } else {
        root.setNameState(addr, "silent", attempts);
      }
    }

    root.pumpNames();
  }

  function cancelProbe(): void {
    probeTimeout.stop();
    root.nameQueue = [];
    if (root.probingAddress !== "") {
      // Drop the "asking…" label rather than leaving it stuck on a row for a
      // probe that is no longer running.
      root.setNameState(root.probingAddress, "", root.nameState[root.probingAddress]?.attempts ?? 0);
      root.probingAddress = "";
      nameProbe.signal(15);
    }
  }

  // Whatever the in-flight probe printed, reset before each one.
  property string probeOutput: ""

  Process {
    id: nameProbe
    stdout: StdioCollector {
      id: nameOut
      onStreamFinished: root.probeOutput = nameOut.text
    }
    // Driven off `exited` rather than the collector's streamFinished, because
    // the two are not ordered against each other and a probe that fails -- an
    // unreachable device, a non-zero exit, our own SIGTERM below -- produces no
    // stdout at all, so streamFinished alone would never settle it. The short
    // delay lets the collector finish filling `text` first.
    onExited: settleProbe.restart()
  }

  Timer {
    id: settleProbe
    interval: 50
    onTriggered: root.finishProbe(root.probeOutput)
  }

  Timer {
    id: probeTimeout
    interval: 4000
    onTriggered: {
      if (root.probingAddress !== "") nameProbe.signal(15);
    }
  }

  // BlueZ never stops on its own, and a forgotten sweep is exactly the cost
  // this whole design is avoiding. Long enough to walk over and power on a
  // headset, short enough not to matter if it is left running.
  Timer {
    id: scanTimeout
    interval: 60000
    onTriggered: root.scanRequested = false
  }

  // freedesktop icon names (BluetoothDevice.icon) mapped onto the Nerd Font
  // glyphs the rest of the bar uses. Anything unrecognised falls back to the
  // generic bluetooth mark.
  function glyphFor(device: var): string {
    const icon = device?.icon ?? "";
    if (icon.includes("headset") || icon.includes("headphone")) return "󰋎";
    if (icon.includes("audio")) return "󰓃";
    if (icon.includes("mouse")) return "󰦋";
    if (icon.includes("keyboard")) return "󰌌";
    if (icon.includes("phone")) return "󰄜";
    if (icon.includes("computer")) return "󰟀";
    if (icon.includes("gaming") || icon.includes("joystick")) return "󰊗";
    if (icon.includes("printer")) return "󰐪";
    if (icon.includes("camera")) return "󰄀";
    if (icon.includes("watch")) return "󰖉";
    return "";
  }

  Instantiator {
    model: Bluetooth.devices
    delegate: QtObject {
      required property var modelData
      readonly property bool conn: modelData?.connected ?? false
      readonly property bool isPaired: modelData?.paired ?? false
      readonly property bool isBonded: modelData?.bonded ?? false
      readonly property bool isPairing: modelData?.pairing ?? false
      readonly property real charge: modelData?.battery ?? 0
      readonly property int connState: modelData?.state ?? BluetoothDeviceState.Disconnected
      onConnChanged: root.deviceGeneration++
      onIsPairedChanged: root.deviceGeneration++
      onIsBondedChanged: root.deviceGeneration++
      onIsPairingChanged: root.deviceGeneration++
      onChargeChanged: root.deviceGeneration++
      onConnStateChanged: root.deviceGeneration++
      Component.onCompleted: root.deviceGeneration++
      Component.onDestruction: root.deviceGeneration++
    }
  }
}
