// Colors.qml: fallback, live reload, and malformed input.
import QtQuick
import Quickshell
import Quickshell.Io
import qs.config

ShellRoot {
  id: root

  property int step: 0

  function expect(actual, wanted, what) {
    if (actual !== wanted) {
      console.error(`FAIL ${what}: got ${actual}, want ${wanted}`);
      Qt.exit(1);
    }
  }

  Timer {
    interval: 300
    repeat: true
    running: true
    onTriggered: {
      switch (root.step++) {
      case 0:
        root.expect(Colors.accent, "#E02C6D", "fallback accent");
        writer.setText(JSON.stringify({ accent: "#b8bb26", black: "#282828", red: "not a colour" }));
        break;
      case 3:
        root.expect(Colors.accent, "#b8bb26", "reloaded accent");
        root.expect(Colors.black, "#282828", "reloaded black");
        root.expect(Colors.red, "#EF2F27", "invalid value falls back");
        root.expect(Colors.brightRed, Colors.red, "bright slot alias");
        writer.setText("{ broken");
        break;
      case 6:
        root.expect(Colors.accent, "#b8bb26", "malformed file keeps last theme");
        console.log("PASS");
        Qt.exit(0);
      }
    }
  }

  FileView {
    id: writer
    path: `${Quickshell.env("XDG_STATE_HOME")}/nyx/colors.json`
  }
}
