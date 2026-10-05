// Bar equalizer: cava frames become columns, show while sound plays and fade
// after it stops. A fake cava prints fixed frames. Saves a screenshot to $OUT.
import QtQuick
import Quickshell
import qs
import qs.components
import qs.services
import qs.modules.bar

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  readonly property var steps: [
    { what: "silent at first", ready: () => true,
      act: () => {
        if (AudioData.sounding) root.fail("sounding before any sound");
        if (visual.visible) root.fail("equalizer visible in silence");
        GlobalState.mediaOpen = true;
      } },
    { what: "cava frames parsed", ready: () => AudioData.bars.length === 4,
      act: () => {
        if (AudioData.bars.join() !== "0,0.5,1,0.2") root.fail(`bars: ${AudioData.bars}`);
      } },
    { what: "sounding", settle: 5, ready: () => AudioData.sounding && visual.opacity === 1,
      act: () => {
        if (!(eq.level(1) > eq.level(0))) root.fail(`levels: ${eq.level(0)} ${eq.level(1)}`);
        if (Math.abs(eq.level(0) - 0.25) > 0.001 || Math.abs(eq.level(1) - 0.6) > 0.001) root.fail("column levels are group averages");
        if (Quickshell.env("OUT")) row.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/equalizer.png`));
        GlobalState.mediaOpen = false;
      } },
    { what: "faded after the sound stops", settle: 3, ready: () => !AudioData.sounding && !visual.visible,
      act: () => {
        if (AudioData.bars.length !== 0) root.fail("bars cleared when cava stops");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 200
    implicitHeight: 60
    color: "black"

    Row {
      id: row
      anchors.fill: parent
      Equalizer { id: eq; count: 2; width: 40; height: 40; bars: AudioData.bars }
      SoundVisual { id: visual; height: 60; width: 40 }
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
