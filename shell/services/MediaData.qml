// Shared MPRIS state for the bar widget (modules/bar/MediaWidget.qml) and the
// media dropdown (modules/media/MediaPanel.qml).
//
// Mpris.players is lazily populated like Networking.devices; the tracker below
// forces it and re-triggers the bindings. See services/NetworkData.qml. It
// lives here rather than in the widget because the panel is built once per
// monitor, so a tracker owned by it would exist N times over.

pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import QtQml.Models
import Quickshell
import Quickshell.Services.Mpris
import qs

Singleton {
  id: root

  property int playerGeneration: 0
  readonly property var players: {
    root.playerGeneration;
    return Mpris.players?.values ?? [];
  }

  // Prefer whatever is actually playing; otherwise fall back to the first player
  // so a paused track still shows.
  readonly property var player: root.players.find(p => p.isPlaying) ?? root.players[0] ?? null
  readonly property bool active: root.player !== null

  readonly property string label: {
    if (!root.active) return "";
    const title = root.player.trackTitle || "Unknown";
    const artist = root.player.trackArtist || "";
    return artist ? `${artist} — ${title}` : title;
  }

  // Seconds -> m:ss, or h:mm:ss past the hour.
  function formatTime(seconds: real): string {
    const s = Math.max(0, Math.floor(seconds || 0));
    const h = Math.floor(s / 3600);
    const m = Math.floor((s % 3600) / 60);
    const ss = String(s % 60).padStart(2, "0");
    return h > 0 ? `${h}:${String(m).padStart(2, "0")}:${ss}` : `${m}:${ss}`;
  }

  Instantiator {
    model: Mpris.players
    delegate: QtObject {
      required property var modelData
      readonly property bool playing: modelData?.isPlaying ?? false
      onPlayingChanged: root.playerGeneration++
      Component.onCompleted: root.playerGeneration++
      Component.onDestruction: root.playerGeneration++
    }
  }

  // `position` is not reactive -- MPRIS only signals jumps, not linear
  // progress -- so poke it while someone is looking at it.
  Timer {
    interval: 1000
    repeat: true
    running: GlobalState.mediaOpen && (root.player?.isPlaying ?? false)
    onTriggered: root.player?.positionChanged()
  }

  // Nothing left to show: don't leave an empty panel hanging.
  onActiveChanged: if (!root.active) GlobalState.closeMedia()
}
