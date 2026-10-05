// ┌────────────────────────────────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░█▀█░▀█▀░█▀█░█▀▀░█░█░▀█▀░█▀▄░█▀▀░█▀▄░█▀█░▀█▀░█▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░█▀▀░░█░░█▀▀░█▀▀░█▄█░░█░░█▀▄░█▀▀░█░█░█▀█░░█░░█▀█░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░▀░░░▀▀▀░▀░░░▀▀▀░▀░▀░▀▀▀░▀░▀░▀▀▀░▀▀░░▀░▀░░▀░░▀░▀░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀────────────────────────────────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>                               ├┤
// ││ Repo    : https://github.com/roosta/dotfiles                         ││
// ││ Site    : https://www.roosta.sh                                      ││
// ├┤ License : GNU General Public License v3                              ├┤
// ┆└──────────────────────────────────────────────────────────────────────┘┆
// Description: Handles the singleton state for Pipewire, and helper
// functions for audio manipulation. Also handles cava visualizer data.

pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell.Io
import Quickshell
import qs
import qs.config
import QtQuick

// qmllint disable unused-imports
// Dont know why qmllint cant se is usage (Paths)
import qs.utils

import Quickshell.Services.Pipewire
import Quickshell.Hyprland

Singleton {
  id: root

  property bool ready: Pipewire.defaultAudioSink?.ready ?? false
  property PwNode sink: Pipewire.defaultAudioSink
  property PwNode source: Pipewire.defaultAudioSource

  readonly property var pwNodes: Pipewire.nodes.values
  property list<PwNode> streamNodes: pwNodes.filter(n => n.isStream)
  // "Something is capturing the microphone" must not count our own plumbing:
  // the rnnoise filter-chain (modules/features/system/noise-cancellation.nix)
  // registers capture.rnnoise_source as a passive input stream that is live for
  // the whole session, and cava is a capture client this service spawns itself.
  // Matched on `name` rather than `properties` because name is a constant
  // property, readable without a PwObjectTracker binding.
  function isRealCapture(n) {
    return n?.name !== "cava" && !/^capture\./.test(n?.name ?? "")
  }
  property list<PwNode> audioIn: streamNodes.filter(s => !s.isSink && s?.audio && root.isRealCapture(s))


  property real volume: sink?.audio.volume ?? 0
  property var bars: []

  // Whether anything is making sound: the cava levels, held for a moment so
  // gaps between tracks do not flicker the bar's equalizer.
  property bool sounding: false
  readonly property real soundThreshold: 0.04
  onBarsChanged: {
    if (root.bars.some(b => b > root.soundThreshold)) {
      root.sounding = true
      soundHold.restart()
    }
  }

  Timer {
    id: soundHold
    interval: 1500
    onTriggered: root.sounding = false
  }

  // cava only runs while an app has a playback stream open or a player is
  // playing, so an idle desktop costs nothing.
  readonly property bool playbackActive: (MediaData.player?.isPlaying ?? false)
    || root.streamNodes.some(s => s.isSink)

  PwObjectTracker {
    objects: [root.sink, root.source]
  }

  // https://github.com/end-4/dots-hyprland/blob/446504ad427297dcbe5ee4a3d5bda1c458207cd9/dots/.config/quickshell/ii/services/Audio.qml#L60
  function incrementVolume() {
    if (!sink?.audio?.volume) { return }
    const currentVolume = volume;
    const step = currentVolume < 0.1 ? 0.01 : 0.02;
    sink.audio.volume = Math.min(1, sink.audio.volume + step);
  }

  // https://github.com/end-4/dots-hyprland/blob/446504ad427297dcbe5ee4a3d5bda1c458207cd9/dots/.config/quickshell/ii/services/Audio.qml#L66
  function decrementVolume() {
    if (!sink?.audio?.volume) { return }
    const currentVolume = volume;
    const step = currentVolume < 0.1 ? 0.01 : 0.02;
    sink.audio.volume = Math.max(0, sink.audio.volume - step);
  }

  function toggleMute() {
    sink.audio.muted = !sink.audio.muted
  }

  function toggleSourceMute() {
    if (!source?.audio) { return }
    source.audio.muted = !source.audio.muted
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "incrementVolume"
    description: "Increases the volume by one step"
    onPressed: {
      root.incrementVolume()
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleMute"
    description: "Turn mute on or off"
    onPressed: {
      root.toggleMute()
    }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "decrementVolume"
    description: "Increases the volume by one step"
    onPressed: {
      root.decrementVolume()
    }
  }


  // Use cava to provde data for visualizers, populating root.bars with parsed
  // integers for each bar if there is audio data. The media panel and the bar
  // equalizer draw them, so cava runs while the panel is open or sound plays,
  // which also restarts it should it ever have died.
  Process {
    id: cava
    command: [Host.cava, "-p", `${Paths.config}/cava/nyx.ini`]
    running: GlobalState.mediaOpen || root.playbackActive
    onRunningChanged: if (!running) root.bars = []

    stdout: SplitParser {
      splitMarker: "\n"
      onRead: data => {
        // data is like "42;78;13;99;50;..."
        root.bars = data.split(";")
        .filter(s => s.length > 0)
        .map(s => parseInt(s) / 100.0)
      }
    }
  }
}
