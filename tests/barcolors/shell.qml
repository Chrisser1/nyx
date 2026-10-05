// Bar buttons carry their own colours: audio is green and turns red muted,
// the tray is magenta. Saves a screenshot to $OUT when set.
import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.config
import qs.modules.bar

ShellRoot {
  id: root

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  FloatingWindow {
    implicitWidth: 400
    implicitHeight: 60
    color: "black"

    RowLayout {
      id: row
      anchors.fill: parent
      SystemButton { monitorId: "TEST" }
      AudioButton { id: audio; monitorId: "TEST" }
      TrayButton { id: tray; monitorId: "TEST" }
    }
  }

  Timer {
    interval: 800
    running: true
    onTriggered: {
      audio.muted = false;
      if (audio.tint != Style.colors.green) root.fail(`unmuted audio tint: ${audio.tint}`);
      audio.muted = true;
      if (audio.tint != Style.colors.red) root.fail(`muted audio tint: ${audio.tint}`);
      if (tray.tint != Style.colors.magenta) root.fail(`tray tint: ${tray.tint}`);
      audio.muted = false;
      if (Quickshell.env("OUT")) row.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/barcolors.png`));
      console.log("PASS");
      Qt.exit(0);
    }
  }
}
