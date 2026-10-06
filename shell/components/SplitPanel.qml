// Centred overlay: filterable list on the left, details for the selection on
// the right. Users supply the entries, how a row reads, the detail content and
// its actions.
//
// Keys: type to filter, Up/Down to move, Enter emits accepted(); other keys go
// to keyPressed() first.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.config

Item {
  id: root

  required property bool active
  required property string title
  property string placeholder: "Filter…"
  property string emptyText: "Nothing here"
  property string detailTitle: ""
  property string detailSubtitle: ""
  // Already filtered by `query`.
  property var entries: []
  readonly property alias query: filter.text
  readonly property var current: list.currentIndex >= 0 && list.currentIndex < root.entries.length
    ? root.entries[list.currentIndex] : null

  property var rowGlyph: entry => ""
  property var rowGlyphColor: entry => Style.colors.accent
  property var rowTitle: entry => ""
  property var rowSubtitle: entry => ""

  property alias headerActions: headerRow.data
  property alias actions: actionRow.data
  default property alias detail: detailArea.data

  signal accepted(var entry)
  signal closeRequested()
  // Set event.accepted to consume a key.
  signal keyPressed(var event)

  anchors.fill: parent
  visible: card.opacity > 0

  onActiveChanged: {
    if (!root.active) return;
    filter.text = "";
    list.currentIndex = 0;
    filter.forceActiveFocus();
  }

  BorderRect {
    id: card

    anchors.centerIn: parent
    width: Math.min(Style.clipboard.width, parent.width - Style.spacing.p5 * 2)
    height: Math.min(Style.clipboard.height, parent.height - Style.bar.height - Style.spacing.p5 * 2)
    color: Style.colors.black
    borderColor: Style.colors.gray3
    borderWidth: Style.bar.borderWidth

    opacity: root.active ? 1 : 0
    scale: root.active ? 1 : 0.97
    Behavior on opacity { NumberAnimation { duration: Style.durations.small; easing.type: Easing.OutCubic } }
    Behavior on scale { NumberAnimation { duration: Style.durations.small; easing.type: Easing.OutCubic } }

    // Keeps clicks from reaching shell.qml's close-on-click-outside.
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.AllButtons
    }

    RowLayout {
      anchors.fill: parent
      anchors.margins: Style.spacing.p4
      spacing: Style.spacing.p4

      ColumnLayout {
        Layout.preferredWidth: card.width * 0.38
        Layout.maximumWidth: card.width * 0.38
        Layout.fillHeight: true
        spacing: Style.spacing.p3

        RowLayout {
          id: headerRow
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: root.title
            color: Style.colors.accent
            font.family: Style.font.main
            font.pointSize: Style.font.xl
            font.bold: true
          }
        }

        TextField {
          id: filter
          Layout.fillWidth: true
          implicitHeight: Style.font.size4 + Style.spacing.p3 * 2
          leftPadding: Style.spacing.p3
          placeholderText: root.placeholder
          renderType: TextField.NativeRendering
          color: Style.colors.brightWhite
          placeholderTextColor: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.large
          background: Rectangle {
            color: Style.colors.gray1
            border.width: Style.bar.borderWidth
            border.color: filter.activeFocus ? Style.colors.accent : Style.colors.gray3
          }
          onTextChanged: list.currentIndex = 0

          Keys.onPressed: event => {
            root.keyPressed(event);
            if (event.accepted) return;
            if (event.key === Qt.Key_Down) {
              list.incrementCurrentIndex();
            } else if (event.key === Qt.Key_Up) {
              list.decrementCurrentIndex();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              if (root.current) root.accepted(root.current);
            } else {
              return;
            }
            event.accepted = true;
          }
        }

        ListView {
          id: list
          Layout.fillWidth: true
          Layout.fillHeight: true
          clip: true
          model: root.entries
          boundsBehavior: Flickable.StopAtBounds
          highlightMoveDuration: 0
          ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

          delegate: Rectangle {
            id: row
            required property var modelData
            required property int index
            readonly property bool selected: ListView.isCurrentItem

            width: ListView.view.width
            height: Style.clipboard.rowHeight
            color: row.selected ? Style.colors.accent : rowArea.containsMouse ? Style.colors.gray2 : "transparent"

            RowLayout {
              anchors.fill: parent
              anchors.leftMargin: Style.spacing.p3
              anchors.rightMargin: Style.spacing.p3
              spacing: Style.spacing.p3

              Text {
                Layout.preferredWidth: Style.font.size4 * 1.6
                horizontalAlignment: Text.AlignHCenter
                text: root.rowGlyph(row.modelData)
                color: row.selected ? Style.colors.onAccent : root.rowGlyphColor(row.modelData)
                font.family: Style.font.symbols
                font.pixelSize: Style.font.size4 * 1.4
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                  Layout.fillWidth: true
                  text: root.rowTitle(row.modelData)
                  elide: Text.ElideRight
                  maximumLineCount: 1
                  color: row.selected ? Style.colors.onAccent : Style.colors.brightWhite
                  font.family: Style.font.main
                  font.pointSize: Style.font.large
                  font.bold: true
                }
                Text {
                  Layout.fillWidth: true
                  text: root.rowSubtitle(row.modelData)
                  elide: Text.ElideRight
                  color: row.selected ? Style.colors.onAccent : Style.colors.white
                  font.family: Style.font.main
                  font.pointSize: Style.font.normal
                }
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: list.currentIndex = row.index
              onDoubleClicked: root.accepted(row.modelData)
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.entries.length === 0
            text: root.query ? "No matches" : root.emptyText
            color: Style.colors.brightBlack
            font.family: Style.font.main
            font.pointSize: Style.font.large
          }
        }
      }

      Rectangle {
        Layout.fillHeight: true
        implicitWidth: Style.bar.borderWidth
        color: Style.colors.gray3
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: Style.spacing.p3

        RowLayout {
          Layout.fillWidth: true
          spacing: Style.spacing.p2

          Text {
            Layout.fillWidth: true
            text: root.detailTitle
            elide: Text.ElideRight
            color: Style.colors.accent
            font.family: Style.font.main
            font.pointSize: Style.font.xl
            font.bold: true
          }

          RowLayout {
            id: actionRow
            spacing: Style.spacing.p2
          }

          IconButton {
            glyph: "\u{F0156}"
            tip: "Close (Esc)"
            onActivated: root.closeRequested()
          }
        }

        Text {
          Layout.fillWidth: true
          visible: root.detailSubtitle !== ""
          text: root.detailSubtitle
          elide: Text.ElideRight
          color: Style.colors.white
          font.family: Style.font.main
          font.pointSize: Style.font.large
        }

        Item {
          id: detailArea
          Layout.fillWidth: true
          Layout.fillHeight: true
        }
      }
    }
  }
}
