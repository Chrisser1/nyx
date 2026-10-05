// Palette slots, read from the colors.json nyx-theme renders. The literals are
// the fallback (Srcery) for before any theme exists.

pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
  id: root

  property var theme: ({})

  function slot(name, fallback) {
    const value = root.theme[name];
    return /^#[0-9a-fA-F]{6}$/.test(value) ? value : fallback;
  }

  // Background ladder, darkest to lightest.
  readonly property string hardBlack: slot("hardBlack", "#0E0D0C")
  readonly property string black: slot("black", "#121110")
  readonly property string gray1: slot("gray1", "#1C1B19")
  readonly property string gray2: slot("gray2", "#262522")
  readonly property string gray3: slot("gray3", "#312F2C")
  readonly property string gray4: slot("gray4", "#3B3935")
  readonly property string gray5: slot("gray5", "#45433E")
  readonly property string gray6: slot("gray6", "#504D47")

  // Foreground ladder.
  readonly property string brightBlack: slot("brightBlack", "#917E6B")
  readonly property string white: slot("white", "#C5B088")
  readonly property string brightWhite: slot("brightWhite", "#FCE8C3")

  // Lines and outlines drawn over the background ladder: a share of the
  // foreground mixed into the background, so they stay readable on any scheme
  // (the ladder's own steps are too close together to outline anything).
  function mix(a, b, t) {
    const x = Qt.color(a);
    const y = Qt.color(b);
    return Qt.rgba(x.r + (y.r - x.r) * t, x.g + (y.g - x.g) * t, x.b + (y.b - x.b) * t, 1);
  }
  readonly property color line: root.mix(root.black, root.brightWhite, 0.3)
  readonly property color lineStrong: root.mix(root.black, root.brightWhite, 0.55)

  readonly property string red: slot("red", "#EF2F27")
  readonly property string green: slot("green", "#519F50")
  readonly property string yellow: slot("yellow", "#FBB829")
  readonly property string blue: slot("blue", "#2C78BF")
  readonly property string magenta: slot("magenta", "#E02C6D")
  readonly property string cyan: slot("cyan", "#0AAEB3")
  readonly property string orange: slot("orange", "#FF5F00")

  // Themes carry one value per hue; the bright slots share it.
  readonly property string brightRed: root.red
  readonly property string brightGreen: root.green
  readonly property string brightYellow: root.yellow
  readonly property string brightBlue: root.blue
  readonly property string brightMagenta: root.magenta
  readonly property string brightCyan: root.cyan
  readonly property string brightOrange: root.orange

  readonly property string fg: root.white
  readonly property string accent: slot("accent", "#E02C6D")
  readonly property string onAccent: slot("onAccent", "#121110")
  readonly property string error: slot("error", "#EF2F27")

  FileView {
    path: `${Quickshell.env("XDG_STATE_HOME") || `${Quickshell.env("HOME")}/.local/state`}/nyx/colors.json`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        root.theme = JSON.parse(text());
      } catch (e) {
        console.warn(`nyx: ignoring malformed colors.json: ${e}`);
      }
    }
  }
}
