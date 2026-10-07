// Bar open-window label: as wide as its text, capped, so the widget after it
// follows closely. Saves a screenshot to $OUT when set.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
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

  function shot(name) {
    if (Quickshell.env("OUT")) row.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/${name}.png`));
  }

  function show(title, desc) {
    ContextData.data = { title, desc, icon: "" };
  }

  property real shortWidth: 0

  readonly property var steps: [
    { what: "short name", ready: () => true,
      act: () => root.show("Kitty", "~") },
    { what: "measured", settle: 3, ready: () => context.width > 0,
      act: () => {
        root.shortWidth = context.width;
        root.shot("context-short");
        root.show("Firefox", "A very long page title that goes on and on and on, far past anything sensible for a bar");
      } },
    { what: "long name", settle: 3, settle: 3, ready: () => true,
      act: () => {
        if (context.width !== root.shortWidth) root.fail(`width changed with the title: ${root.shortWidth} -> ${context.width}`);
        if (context.width !== Style.bar.contextMaxWidth) root.fail(`not the fixed width: ${context.width}`);
        if (next.x < context.width) root.fail("the next widget overlaps the label");
        root.shot("context-long");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 900
    implicitHeight: 60
    color: "black"

    RowLayout {
      id: row
      anchors.fill: parent
      spacing: Style.spacing.p1

      Loader {
        id: context
        Layout.fillHeight: true
        Layout.preferredWidth: Style.bar.contextMaxWidth
        sourceComponent: Context { }
      }
      Rectangle { id: next; implicitWidth: 40; Layout.fillHeight: true; color: "red" }
      Item { Layout.fillWidth: true }
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
