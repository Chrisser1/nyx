// Audio panel: outputs, inputs and apps from fake nodes, and open/close.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.audio

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function count(item, name) {
    let n = item.objectName === name ? 1 : 0;
    for (const c of item.children) n += root.count(c, name);
    return n;
  }

  function node(name, label, volume, muted) {
    return { name, nickname: label, description: label, properties: {}, audio: { volume, muted } };
  }

  readonly property var steps: [
    { what: "fake devices", ready: () => true,
      act: () => {
        AudioData.sinks = [root.node("hdmi", "Monitor speakers", 0.4, false), root.node("usb", "Headset", 0.8, true)];
        AudioData.sources = [root.node("mic", "Headset microphone", 1, false)];
        AudioData.appStreams = [{ name: "spotify", properties: { "application.name": "Spotify" }, audio: { volume: 0.5, muted: false } }];
        GlobalState.openAudio("TEST");
      } },
    { what: "rows built", settle: 5, ready: () => panel.visible,
      act: () => {
        if (root.count(panel, "device") !== 3) root.fail(`device rows: ${root.count(panel, "device")}`);
        if (root.count(panel, "app") !== 1) root.fail(`app rows: ${root.count(panel, "app")}`);
        if (AudioData.deviceLabel(AudioData.sinks[0]) !== "Monitor speakers") root.fail("device label");
        if (AudioData.appLabel(AudioData.appStreams[0]) !== "Spotify") root.fail("app label");
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/audio.png`));
      } },
    { what: "screenshot", settle: 5, ready: () => true,
      act: () => {
        GlobalState.openWifi("TEST");
        if (GlobalState.audioOpen) root.fail("opening wifi left audio open");
        GlobalState.toggleAudio("TEST");
        if (!GlobalState.audioOpen || GlobalState.wifiOpen) root.fail("audio did not replace wifi");
        GlobalState.closeAll();
        if (GlobalState.audioOpen) root.fail("closeAll left audio open");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 600
    implicitHeight: 560
    color: "black"

    AudioPanel {
      id: panel
      monitorId: "TEST"
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      const s = root.steps[root.step];
      if (s.ready() && root.waited >= (s.settle ?? 0)) {
        root.waited = 0;
        root.step++;
        s.act();
      } else if (++root.waited > 150) {
        root.fail(`timed out waiting for: ${s.what}`);
      }
    }
  }
}
