// Bar notification button: a bell, with no count while nothing is stored.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import qs.modules.bar

ShellRoot {
  id: root

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function find(item, name) {
    if (item.objectName === name) return item;
    for (const c of item.children) {
      const found = root.find(c, name);
      if (found) return found;
    }
    return null;
  }

  FloatingWindow {
    implicitWidth: 120
    implicitHeight: 60
    color: "black"

    NotificationButton {
      id: button
      monitorId: "TEST"
    }
  }

  Timer {
    interval: 800
    running: true
    onTriggered: {
      const bell = root.find(button, "bell");
      if (!bell || bell.text !== "\u{F009C}") root.fail(`bell glyph: ${bell?.text}`);
      if (root.find(button, "badge").visible) root.fail("count shown with no notifications");
      if (Quickshell.env("OUT")) button.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/notify.png`));
      console.log("PASS");
      Qt.exit(0);
    }
  }
}
