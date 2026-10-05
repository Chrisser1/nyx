// Now-playing card, dropped from the bar when the media widget is clicked.
// Album art, track info, elapsed/total on a seekable progress bar that doubles
// as an audio visualizer, and shuffle / previous / play-pause / next / repeat.
//
// Built on the same sliding-Item idiom as modules/network/WifiPanel.qml: it
// lives inside shell.qml's fullscreen "main" panel, and GlobalState.overlayOpen
// is what flips that panel's input mask so the contents become clickable. It
// hangs under the widget rather than off a corner -- the widget passes its
// window x in through GlobalState.mediaAnchorX.
//
// The player and the position ticker live in services/MediaData.qml, since
// shell.qml builds one of these per monitor.

pragma ComponentBehavior: Bound

import qs
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris

Item {
  id: root
  required property string monitorId

  readonly property var player: MediaData.player
  readonly property real panelHeight: content.implicitHeight + Style.spacing.p2 * 2

  anchors.top: parent.top
  anchors.topMargin: Style.bar.height

  // Centred under the widget, but never off the edge of the screen.
  x: Math.max(Style.spacing.p1,
    Math.min(GlobalState.mediaAnchorX - width / 2, parent.width - width - Style.spacing.p1))

  implicitWidth: Style.media.width
  implicitHeight: root.panelHeight

  // The slide happens inside these bounds.
  clip: true

  readonly property bool active: GlobalState.mediaOpen
    && GlobalState.mediaMonitorId === root.monitorId

  // Only render while on-screen or mid-transition.
  visible: panel.y > -root.panelHeight

  // Not reactive on its own; MediaData's timer fires positionChanged() while
  // the panel is open, which re-evaluates this.
  readonly property real position: root.player?.position ?? 0
  readonly property real length: root.player?.length ?? 0
  readonly property bool hasLength: (root.player?.lengthSupported ?? false) && root.length > 0
  readonly property bool seekable: root.hasLength && (root.player?.canSeek ?? false)
    && (root.player?.positionSupported ?? false)

  component TransportButton: Rectangle {
    id: btn
    required property string glyph
    property bool available: true
    // Toggles (shuffle, repeat) tint while engaged.
    property bool engaged: false
    property int glyphSize: Style.font.size4
    signal activated()

    implicitWidth: btn.glyphSize + Style.spacing.p2 * 2
    implicitHeight: btn.glyphSize + Style.spacing.p1 * 2
    color: area.containsMouse && btn.available ? Style.colors.gray2 : "transparent"

    Behavior on color {
      ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
    }

    Text {
      anchors.centerIn: parent
      text: btn.glyph
      color: {
        if (!btn.available) return Style.colors.gray4
        if (btn.engaged) return Style.colors.accent
        return area.containsMouse ? Style.colors.brightWhite : Style.colors.white
      }
      font.family: Style.font.symbols
      font.pixelSize: btn.glyphSize
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: btn.available ? Qt.PointingHandCursor : Qt.ArrowCursor
      onClicked: if (btn.available) btn.activated()
    }
  }

  BorderRect {
    id: panel

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: root.panelHeight

    // 0 == fully open, -panelHeight == fully hidden behind the bar.
    y: root.active ? 0 : -root.panelHeight

    color: Style.colors.black
    borderColor: Style.colors.gray2
    borderWidth: Style.bar.borderWidth

    Behavior on y {
      NumberAnimation {
        duration: Style.durations.small
        easing.type: Easing.InOutCubic
      }
    }

    // Swallow clicks so they don't reach shell.qml's close-on-click-outside.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    ColumnLayout {
      id: content
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: Style.spacing.p2
      spacing: Style.spacing.p1

      // ── Art ──────────────────────────────────────────────────────────
      Rectangle {
        Layout.alignment: Qt.AlignHCenter
        implicitWidth: Style.media.artSize
        implicitHeight: Style.media.artSize
        color: Style.colors.gray1
        clip: true

        Image {
          id: art
          anchors.fill: parent
          source: root.player?.trackArtUrl ?? ""
          fillMode: Image.PreserveAspectCrop
          asynchronous: true
          cache: true
          sourceSize.width: Style.media.artSize
          sourceSize.height: Style.media.artSize
        }

        Text {
          anchors.centerIn: parent
          visible: art.status !== Image.Ready
          text: "󰝚"
          color: Style.colors.gray4
          font.family: Style.font.symbols
          font.pixelSize: Style.media.artSize / 4
        }
      }

      // ── Track info ───────────────────────────────────────────────────
      ColumnLayout {
        Layout.fillWidth: true
        Layout.topMargin: Style.spacing.p1
        spacing: 0

        Text {
          Layout.fillWidth: true
          text: root.player?.trackTitle || "Unknown"
          elide: Text.ElideRight
          color: Style.colors.brightWhite
          font.family: Style.font.main
          font.pointSize: Style.font.normal
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.player?.trackArtist ?? ""
          elide: Text.ElideRight
          color: Style.colors.white
          font.family: Style.font.main
          font.pointSize: Style.font.small
        }
        Text {
          Layout.fillWidth: true
          visible: text !== ""
          text: root.player?.trackAlbum ?? ""
          elide: Text.ElideRight
          color: Style.colors.gray6
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
      }

      // ── Progress + visualizer ────────────────────────────────────────
      // One column per cava bar (AudioData.bars, 0..1), coloured up to the
      // playhead. In silence every column sits at the floor height, so it
      // still reads as a plain progress bar. Rectangles rather than a Canvas,
      // for the same reason as components/Sparkline.qml.
      Item {
        id: strip
        Layout.fillWidth: true
        implicitHeight: Style.media.visualizerHeight

        readonly property var bars: AudioData.bars
        readonly property int count: Math.max(1, strip.bars.length)
        readonly property real gap: 1
        readonly property real columnWidth: (strip.width - strip.gap * (strip.count - 1)) / strip.count
        readonly property real progress: root.hasLength
          ? Math.min(1, Math.max(0, root.position / root.length))
          : 0

        // Floor line, visible before cava has produced a frame.
        Rectangle {
          visible: strip.bars.length === 0
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          height: Style.media.progressHeight
          color: Style.colors.gray3

          Rectangle {
            anchors.left: parent.left
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            width: parent.width * strip.progress
            color: Style.colors.accent
          }
        }

        Repeater {
          model: strip.bars.length

          Rectangle {
            required property int index
            readonly property real value: strip.bars[index] ?? 0

            x: index * (strip.columnWidth + strip.gap)
            anchors.bottom: parent.bottom
            width: strip.columnWidth
            height: Math.max(Style.media.progressHeight, value * strip.height)
            // A column counts as played once its centre is behind the playhead.
            color: (index + 0.5) / strip.count <= strip.progress
              ? Style.colors.accent
              : Style.colors.gray3
          }
        }

        MouseArea {
          anchors.fill: parent
          enabled: root.seekable
          cursorShape: root.seekable ? Qt.PointingHandCursor : Qt.ArrowCursor
          onClicked: mouse => {
            root.player.position = root.length * Math.min(1, Math.max(0, mouse.x / parent.width))
          }
        }
      }

      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p1

        Text {
          text: MediaData.formatTime(root.position)
          visible: root.player?.positionSupported ?? false
          color: Style.colors.gray6
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
        Item { Layout.fillWidth: true }
        Text {
          text: MediaData.formatTime(root.length)
          visible: root.hasLength
          color: Style.colors.gray6
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
        }
      }

      // ── Transport ────────────────────────────────────────────────────
      RowLayout {
        Layout.alignment: Qt.AlignHCenter
        spacing: Style.spacing.p2

        TransportButton {
          glyph: root.player?.shuffle ? "󰒝" : "󰒞"
          engaged: root.player?.shuffle ?? false
          available: (root.player?.canControl ?? false) && (root.player?.shuffleSupported ?? false)
          onActivated: root.player.shuffle = !root.player.shuffle
        }
        TransportButton {
          glyph: "󰒮"
          available: root.player?.canGoPrevious ?? false
          onActivated: root.player.previous()
        }
        TransportButton {
          glyph: root.player?.isPlaying ? "󰏤" : "󰐊"
          glyphSize: Style.font.size4 * 1.5
          available: root.player?.canTogglePlaying ?? false
          onActivated: root.player.togglePlaying()
        }
        TransportButton {
          glyph: "󰒭"
          available: root.player?.canGoNext ?? false
          onActivated: root.player.next()
        }
        // Cycles off -> playlist -> track, the three states MPRIS has.
        TransportButton {
          readonly property int loop: root.player?.loopState ?? MprisLoopState.None
          glyph: {
            if (loop === MprisLoopState.Track) return "󰑘"
            if (loop === MprisLoopState.Playlist) return "󰑖"
            return "󰑗"
          }
          engaged: loop !== MprisLoopState.None
          available: (root.player?.canControl ?? false) && (root.player?.loopSupported ?? false)
          onActivated: {
            if (loop === MprisLoopState.None) root.player.loopState = MprisLoopState.Playlist
            else if (loop === MprisLoopState.Playlist) root.player.loopState = MprisLoopState.Track
            else root.player.loopState = MprisLoopState.None
          }
        }
      }
    }
  }
}
