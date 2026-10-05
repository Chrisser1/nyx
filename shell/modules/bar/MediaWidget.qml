// MPRIS media widget with a scrolling title. Clicking drops
// modules/media/MediaPanel.qml out of the bar; player selection lives in
// services/MediaData.qml so the two agree.

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.config

Rectangle {
  id: root
  required property string monitorId

  readonly property var player: MediaData.player
  readonly property bool active: MediaData.active
  readonly property bool panelShown: GlobalState.mediaOpen
    && GlobalState.mediaMonitorId === root.monitorId

  // Fades in and out as players come and go; `visible` drops only once the
  // fade is done so the row reflows once.
  opacity: active ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Style.durations.small; easing.type: Easing.OutCubic } }
  implicitWidth: layout.implicitWidth
  implicitHeight: parent.height
  color: "transparent"

  // Declared before the layout so the play/pause glyph's own MouseArea sits on
  // top of it; everything else on the widget lands here.
  MouseArea {
    id: area
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.BackButton | Qt.ForwardButton
    onClicked: mouse => {
      if (!root.player) return;
      if (mouse.button === Qt.LeftButton) {
        // The panel is a sibling of the bar in the fullscreen "main" window, so
        // window coordinates are its parent's coordinates.
        GlobalState.toggleMedia(root.monitorId, root.mapToItem(null, root.width / 2, 0).x);
      }
      else if (mouse.button === Qt.MiddleButton && root.player.canTogglePlaying) root.player.togglePlaying();
      else if (mouse.button === Qt.ForwardButton && root.player.canGoNext) root.player.next();
      else if (mouse.button === Qt.BackButton && root.player.canGoPrevious) root.player.previous();
    }
    // Scroll to skip tracks.
    onWheel: wheel => {
      if (!root.player) return;
      if (wheel.angleDelta.y > 0 && root.player.canGoNext) root.player.next();
      else if (wheel.angleDelta.y < 0 && root.player.canGoPrevious) root.player.previous();
    }
  }

  RowLayout {
    id: layout
    anchors.verticalCenter: parent.verticalCenter
    spacing: Style.spacing.p1

    Text {
      text: root.player?.isPlaying ? "" : ""
      font.family: Style.font.symbols
      font.pointSize: Style.font.small
      color: Style.colors.brightGreen
      Layout.alignment: Qt.AlignVCenter

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.player?.canTogglePlaying) root.player.togglePlaying()
      }
    }

    // Clipped rather than elided so a long title can scroll on hover.
    Item {
      Layout.alignment: Qt.AlignVCenter
      implicitHeight: title.implicitHeight
      implicitWidth: Math.min(title.implicitWidth, 220)
      clip: true

      Text {
        id: title
        text: MediaData.label
        font.family: Style.font.main
        font.pointSize: Style.font.small
        color: area.containsMouse || root.panelShown ? Style.colors.accent : Style.colors.white

        Behavior on color {
          ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
        }

        // Only animate when the text actually overflows.
        readonly property real overflow: Math.max(0, title.implicitWidth - 220)
        SequentialAnimation on x {
          running: area.containsMouse && title.overflow > 0
          loops: Animation.Infinite
          NumberAnimation { from: 0; to: -title.overflow; duration: 40 * title.overflow; easing.type: Easing.Linear }
          PauseAnimation { duration: 800 }
          NumberAnimation { from: -title.overflow; to: 0; duration: 300; easing.type: Easing.OutQuad }
          PauseAnimation { duration: 800 }
        }
        onTextChanged: x = 0
      }
    }
  }
}
