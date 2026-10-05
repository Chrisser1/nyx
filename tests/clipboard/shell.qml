// ClipboardPanel against a seeded history: selection, previews, filter, pin,
// delete. Saves screenshots to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.clipboard

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function shot(name) {
    if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/${name}.png`));
  }

  // Each step waits for its condition (and `settle` ticks, for previews to
  // paint before a screenshot), then acts and moves on.
  readonly property var steps: [
    { what: "open", ready: () => true, act: () => GlobalState.openClipboard("TEST") },
    { what: "history loaded", settle: 10, ready: () => ClipboardData.entries.length === 4 && ClipboardData.detailImage !== "",
      act: () => {
        if (panel.current.kind !== "image") root.fail("newest entry selected");
        if (!panel.meta(panel.current, true).includes("1362×766")) root.fail("image meta");
        panel.now = panel.current.time + 150;
        if (!panel.meta(panel.current, false).startsWith("2 min ago")) root.fail("time ago follows now");
        panel.now = Date.now() / 1000;
        root.shot("image");
      } },
    { what: "image screenshot", settle: 5, ready: () => true, act: () => panel.query = "notes" },
    { what: "text preview", settle: 5, ready: () => panel.currentText === "Some notes\nsecond line\nthird",
      act: () => {
        if (panel.shown.length !== 1) root.fail("filter");
        if (!panel.meta(panel.current, true).includes("3 lines")) root.fail("text meta");
        root.shot("text");
      } },
    { what: "text screenshot", settle: 5, ready: () => true, act: () => panel.query = "" },
    { what: "filter cleared", ready: () => panel.shown.length === 4 && panel.current?.kind === "image",
      act: () => panel.togglePin() },
    { what: "pinned", ready: () => ClipboardData.entries[0]?.pinned === true,
      act: () => {
        if (ClipboardData.entries.length !== 4) root.fail("pin keeps entry count");
        panel.remove();
      } },
    { what: "deleted", ready: () => ClipboardData.entries.length === 3,
      act: () => {
        if (ClipboardData.entries.some(e => e.pinned)) root.fail("pin deleted");
        panel.query = "no such entry";
      } },
    { what: "no matches", ready: () => panel.shown.length === 0 && panel.current === null,
      act: () => GlobalState.closeClipboard() },
    { what: "closed", ready: () => !panel.visible, act: () => { console.log("PASS"); Qt.exit(0); } }
  ]

  FloatingWindow {
    implicitWidth: 1280
    implicitHeight: 800
    color: "black"

    ClipboardPanel {
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
      } else if (++root.waited > 100) {
        root.fail(`timed out waiting for: ${s.what}`);
      }
    }
  }
}
