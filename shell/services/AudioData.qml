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

  // Devices and per-app streams for modules/audio/AudioPanel.qml. A node's
  // `audio` stays null until it is tracked, so everything audio-typed is
  // tracked below. Our own plumbing (rnnoise, cava) is left out.
  function isAudio(n) { return (n.type & PwNodeType.Audio) !== 0 }
  function isPlumbing(n) { return /^(capture|effect_|cava)/.test(n.name ?? "") }
  property var sinks: pwNodes.filter(n => root.isAudio(n) && !n.isStream && n.isSink && !root.isPlumbing(n))
  property var sources: pwNodes.filter(n => root.isAudio(n) && !n.isStream && !n.isSink && !root.isPlumbing(n) && root.isMic(n))
  property var appStreams: pwNodes.filter(n => root.isAudio(n) && n.isStream && n.isSink && !root.isPlumbing(n))

  PwObjectTracker {
    objects: [...root.sinks, ...root.sources, ...root.appStreams]
  }

  // The noise cancelling source (modules/features/system/noise-cancellation.nix)
  // is a filter on a real microphone. Inputs lists real microphones only, and
  // `chainMic`, the one the chain listens to, is stored by `nyx-audio chain`.
  property var noiseNode: pwNodes.find(n => n.name === "rnnoise_source") ?? null
  property bool noiseOn: root.noiseNode !== null && root.source?.name === root.noiseNode.name
  property string chainMic: ""

  function isMic(n) { return n.name !== "rnnoise_source" }

  // Picking a microphone also points the chain at it; the default stays the chain while it is on.
  function pickMic(n) {
    root.chainMic = n.name
    Quickshell.execDetached([Host.audio, "chain", "set", n.name])
    root.setDefaultSource(root.noiseOn ? root.noiseNode : n)
  }

  function setNoiseCancelling(on) {
    const current = root.source && root.isMic(root.source) ? root.source : root.sources[0]
    const mic = root.sources.find(n => n.name === root.chainMic) ?? current
    if (on && root.noiseNode) {
      if (mic) root.pickMic(mic)
      root.setDefaultSource(root.noiseNode)
    } else if (mic) {
      root.setDefaultSource(mic)
    }
  }

  Process {
    command: [Host.audio, "chain"]
    running: true
    stdout: StdioCollector { onStreamFinished: if (root.chainMic === "") root.chainMic = text.trim() }
  }

  // The chain's target is lost when PipeWire restarts, so it is set again
  // whenever the chain node shows up.
  onNoiseNodeChanged: if (root.noiseNode) Quickshell.execDetached([Host.audio, "chain", "apply"])

  function deviceLabel(n) { return n?.nickname || n?.description || n?.name || "" }
  function appLabel(n) {
    return n?.properties?.["application.name"] || n?.properties?.["media.name"] || root.deviceLabel(n)
  }
  function setDefaultSink(n) { Pipewire.preferredDefaultAudioSink = n }
  function setDefaultSource(n) { Pipewire.preferredDefaultAudioSource = n }

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
        // data is like "42;78;13;99;50;...", levels 0..100. The square root lifts quiet
        // passages, which would otherwise barely register.
        root.bars = data.split(";")
        .filter(s => s.length > 0)
        .map(s => Math.sqrt(parseInt(s) / 100.0))
      }
    }
  }
}
