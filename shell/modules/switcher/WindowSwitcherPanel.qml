// Alt+Tab overlay: live window previews, most recently focused first.
//
// Hold Alt and press Tab / Shift+Tab (or the arrows) to move; releasing Alt,
// Enter or a click focuses the selection.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell.Wayland
import Quickshell.Widgets
import qs
import qs.components
import qs.config
import qs.services
import qs.utils

Item {
  id: root
  required property string monitorId

  readonly property bool active: GlobalState.switcherOpen
    && GlobalState.switcherMonitorId === root.monitorId

  anchors.fill: parent
  visible: card.opacity > 0

  // What the list highlights, which must always be the switcher's selection.
  readonly property int shownIndex: list.currentIndex

  onActiveChanged: if (root.active) list.forceActiveFocus()

  BorderRect {
    id: card

    readonly property int padding: Style.spacing.p4

    anchors.centerIn: parent
    width: Math.min(list.contentWidth, parent.width - Style.spacing.p5 * 2 - padding * 2) + padding * 2
    height: Style.switcher.cardHeight + padding * 2
    color: Style.colors.black
    borderColor: Style.colors.gray3
    borderWidth: Style.bar.borderWidth

    opacity: root.active ? 1 : 0
    scale: root.active ? 1 : 0.97
    Behavior on opacity { NumberAnimation { duration: Style.durations.tiny; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Style.durations.tiny; easing.type: Easing.OutCubic } }

    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    ListView {
      id: list

      anchors.fill: parent
      anchors.margins: card.padding
      orientation: ListView.Horizontal
      spacing: Style.spacing.p3
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      highlightMoveDuration: Style.durations.tiny
      highlightRangeMode: ListView.ApplyRange
      preferredHighlightBegin: width / 2 - Style.switcher.cardWidth / 2
      preferredHighlightEnd: width / 2 + Style.switcher.cardWidth / 2

      model: root.active ? WindowSwitcher.windows : []
      currentIndex: WindowSwitcher.index
      // A model reset puts currentIndex back to 0 and drops the binding; restore it.
      onCountChanged: currentIndex = Qt.binding(() => WindowSwitcher.index)

      Keys.onPressed: event => {
        const back = event.modifiers & Qt.ShiftModifier;
        if (event.key === Qt.Key_Backtab || (event.key === Qt.Key_Tab && back) || event.key === Qt.Key_Left) {
          WindowSwitcher.previous();
        } else if (event.key === Qt.Key_Tab || event.key === Qt.Key_Right) {
          WindowSwitcher.next();
        } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
          WindowSwitcher.commit();
        } else {
          return;
        }
        event.accepted = true;
      }
      // Hyprland's release bind does the same; whichever arrives first wins.
      Keys.onReleased: event => {
        if (event.key === Qt.Key_Alt || event.key === Qt.Key_Meta) WindowSwitcher.commit();
      }

      delegate: Rectangle {
        id: tile
        required property var modelData
        required property int index
        readonly property bool selected: ListView.isCurrentItem
        readonly property var toplevel: WindowSwitcher.toplevel(tile.modelData.address)

        width: Style.switcher.cardWidth
        height: ListView.view.height
        color: tile.selected ? Style.colors.gray2 : tileArea.containsMouse ? Style.colors.gray1 : "transparent"
        border.width: Style.bar.borderWidth
        border.color: tile.selected ? Style.colors.accent : Style.colors.gray3

        ColumnLayout {
          anchors.fill: parent
          anchors.margins: Style.spacing.p2
          spacing: Style.spacing.p2

          Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ScreencopyView {
              id: preview
              anchors.fill: parent
              captureSource: tile.toplevel?.wayland ?? null
              live: root.active
              constraintSize: Qt.size(width, height)
            }

            IconImage {
              visible: !preview.hasContent
              anchors.centerIn: parent
              implicitSize: parent.height * 0.4
              source: Icons.lookupIcon(tile.modelData.class)
            }
          }

          RowLayout {
            Layout.fillWidth: true
            spacing: Style.spacing.p2

            IconImage {
              implicitSize: Style.font.size4 * 1.4
              source: Icons.lookupIcon(tile.modelData.class)
            }

            Text {
              Layout.fillWidth: true
              text: tile.modelData.title || tile.modelData.class
              elide: Text.ElideRight
              color: tile.selected ? Style.colors.brightWhite : Style.colors.white
              font.family: Style.font.main
              font.pointSize: Style.font.normal
              font.bold: tile.selected
            }

            Text {
              text: tile.modelData.workspace?.name ?? ""
              color: Style.colors.brightBlack
              font.family: Style.font.main
              font.pointSize: Style.font.small
            }
          }
        }

        MouseArea {
          id: tileArea
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            WindowSwitcher.index = tile.index;
            WindowSwitcher.commit();
          }
        }
      }
    }
  }
}
