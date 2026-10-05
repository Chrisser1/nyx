// The shell's palette, as a flat set of base16-style slots.
//
// Values below are Srcery (roosta's original palette), used as the fallback so
// the shell renders correctly before any theme has been generated. The Nix module
// overwrites this file via matugen whenever the wallpaper changes, mapping
// Material-You tokens onto the same slot names — so the mapping lives in one
// template instead of being spread across every widget.
//
// Widgets refer to these as `Style.colors.<slot>`.

pragma Singleton
import Quickshell

Singleton {
  id: root

  // Background ladder, darkest to lightest.
  readonly property string hardBlack: "#0E0D0C"
  readonly property string black: "#121110"
  readonly property string gray1: "#1C1B19"
  readonly property string gray2: "#262522"
  readonly property string gray3: "#312F2C"
  readonly property string gray4: "#3B3935"
  readonly property string gray5: "#45433E"
  readonly property string gray6: "#504D47"

  // Foreground ladder.
  readonly property string brightBlack: "#917E6B"
  readonly property string white: "#C5B088"
  readonly property string brightWhite: "#FCE8C3"

  // Accents.
  readonly property string red: "#EF2F27"
  readonly property string green: "#519F50"
  readonly property string yellow: "#FBB829"
  readonly property string blue: "#2C78BF"
  readonly property string magenta: "#E02C6D"
  readonly property string cyan: "#0AAEB3"
  readonly property string orange: "#FF5F00"

  readonly property string brightRed: "#F75341"
  readonly property string brightGreen: "#98BC37"
  readonly property string brightYellow: "#FED06E"
  readonly property string brightBlue: "#68A8E4"
  readonly property string brightMagenta: "#FF5C8F"
  readonly property string brightCyan: "#2BE4D0"
  readonly property string brightOrange: "#FF8700"

  // Semantic aliases, for the few places that want intent rather than a slot.
  // The base16 slots above stay complete even where nothing reads them yet --
  // a palette with holes in it is worse than an unused name.
  readonly property string fg: root.white
  readonly property string accent: root.magenta
}
