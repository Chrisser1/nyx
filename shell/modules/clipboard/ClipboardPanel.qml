// Centred clipboard history: filterable list on the left, preview on the right.
//
// Keys: type to filter, Up/Down to move, Enter to copy, Shift+Delete to delete,
// Ctrl+P to pin.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs
import qs.components
import qs.config
import qs.services

Item {
  id: root
  required property string monitorId

  readonly property bool active: GlobalState.clipboardOpen
    && GlobalState.clipboardMonitorId === root.monitorId
  property string query: ""
  readonly property var shown: ClipboardData.filter(root.query)
  readonly property var current: list.currentIndex >= 0 && list.currentIndex < root.shown.length
    ? root.shown[list.currentIndex] : null
  readonly property string currentText: root.current?.id === ClipboardData.detailId ? ClipboardData.detailText : ""

  anchors.fill: parent
  visible: card.opacity > 0

  onActiveChanged: {
    if (!root.active) return;
    filter.text = "";
    list.currentIndex = 0;
    ClipboardData.refresh();
    filter.forceActiveFocus();
  }
  onCurrentChanged: ClipboardData.select(root.current)

  function title(entry) {
    if (!entry) return "";
    if (entry.kind === "image") return "Image";
    return entry.preview.trim() || "(whitespace)";
  }

  function kindLabel(entry) {
    if (!entry) return "";
    if (entry.kind === "image") return "Image";
    if (root.isUrl(entry.preview)) return "Link";
    if (root.isColor(entry.preview)) return "Colour";
    return "Text";
  }

  function glyph(entry) {
    switch (root.kindLabel(entry)) {
    case "Image": return "\u{F02E9}";
    case "Link": return "\u{F0339}";
    case "Colour": return "\u{F0266}";
    default: return "\u{F0219}";
    }
  }

  function isUrl(text) { return /^https?:\/\/\S+$/.test(text.trim()); }
  function isColor(text) { return /^#(?:[0-9a-f]{3}|[0-9a-f]{6}|[0-9a-f]{8})$/i.test(text.trim()); }

  function ago(time) {
    if (!time) return "";
    const seconds = Math.floor(Date.now() / 1000) - time;
    if (seconds < 60) return "just now";
    if (seconds < 3600) return `${Math.floor(seconds / 60)} min ago`;
    if (seconds < 86400) return `${Math.floor(seconds / 3600)} h ago`;
    if (seconds < 172800) return "yesterday";
    return Qt.formatDate(new Date(time * 1000), "d MMM");
  }

  function bytes(text) {
    const n = unescape(encodeURIComponent(text)).length;
    if (n < 1024) return `${n} B`;
    if (n < 1048576) return `${(n / 1024).toFixed(1)} KiB`;
    return `${(n / 1048576).toFixed(1)} MiB`;
  }

  function meta(entry, full) {
    if (!entry) return "";
    const parts = [entry.pinned ? "Pinned" : root.ago(entry.time)];
    if (entry.kind === "image") {
      parts.push(entry.size);
      if (full) parts.push(`${entry.width}×${entry.height}`);
    } else if (full && root.currentText) {
      parts.push(root.bytes(root.currentText));
      const lines = root.currentText.split("\n").length;
      if (lines > 1) parts.push(`${lines} lines`);
    }
    return parts.filter(Boolean).join("  •  ");
  }

  function accept() {
    if (!root.current) return;
    ClipboardData.copy(root.current);
    GlobalState.closeClipboard();
  }

  function remove() {
    if (root.current) ClipboardData.remove(root.current);
  }

  function togglePin() {
    if (root.current) ClipboardData.togglePin(root.current);
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
          Layout.fillWidth: true

          Text {
            Layout.fillWidth: true
            text: "Clipboard"
            color: Style.colors.accent
            font.family: Style.font.main
            font.pointSize: Style.font.xl
            font.bold: true
          }

          IconButton {
            id: wipe
            property bool armed: false
            glyph: "\u{F00E2}"
            label: wipe.armed ? "Wipe history?" : ""
            danger: true
            checked: wipe.armed
            onActivated: {
              if (!wipe.armed) {
                wipe.armed = true;
                disarm.restart();
              } else {
                wipe.armed = false;
                ClipboardData.wipe();
              }
            }

            Timer {
              id: disarm
              interval: 3000
              onTriggered: wipe.armed = false
            }
          }
        }

        TextField {
          id: filter
          Layout.fillWidth: true
          implicitHeight: Style.font.size4 + Style.spacing.p3 * 2
          leftPadding: Style.spacing.p3
          placeholderText: "Filter clipboard…"
          renderType: TextField.NativeRendering
          color: Style.colors.brightWhite
          placeholderTextColor: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.large
          onTextChanged: {
            root.query = filter.text;
            list.currentIndex = 0;
          }

          background: Rectangle {
            color: Style.colors.gray1
            border.width: Style.bar.borderWidth * 2
            border.color: filter.activeFocus ? Style.colors.accent : Style.colors.gray3
          }

          Keys.onPressed: event => {
            if (event.key === Qt.Key_Down) {
              list.incrementCurrentIndex();
            } else if (event.key === Qt.Key_Up) {
              list.decrementCurrentIndex();
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.accept();
            } else if (event.key === Qt.Key_Delete && event.modifiers & Qt.ShiftModifier) {
              root.remove();
            } else if (event.key === Qt.Key_P && event.modifiers & Qt.ControlModifier) {
              root.togglePin();
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
          spacing: Style.spacing.p0
          model: root.shown
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
                text: root.glyph(row.modelData)
                color: row.selected ? Style.colors.onAccent : Style.colors.accent
                font.family: Style.font.symbols
                font.pixelSize: Style.font.size4 * 1.4
              }

              ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                Text {
                  Layout.fillWidth: true
                  text: root.title(row.modelData)
                  elide: Text.ElideRight
                  maximumLineCount: 1
                  color: row.selected ? Style.colors.onAccent : Style.colors.brightWhite
                  font.family: Style.font.main
                  font.pointSize: Style.font.large
                  font.bold: true
                }
                Text {
                  Layout.fillWidth: true
                  text: root.meta(row.modelData, false)
                  elide: Text.ElideRight
                  color: row.selected ? Style.colors.onAccent : Style.colors.white
                  font.family: Style.font.main
                  font.pointSize: Style.font.normal
                }
              }

              Text {
                visible: row.modelData.pinned
                text: "\u{F0403}"
                color: row.selected ? Style.colors.onAccent : Style.colors.accent
                font.family: Style.font.symbols
                font.pixelSize: Style.font.size3
              }
            }

            MouseArea {
              id: rowArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: list.currentIndex = row.index
              onDoubleClicked: root.accept()
            }
          }

          Text {
            anchors.centerIn: parent
            visible: root.shown.length === 0
            text: root.query ? "No matches" : "Clipboard is empty"
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
            text: root.current ? `${root.kindLabel(root.current)} Clipboard Entry` : ""
            elide: Text.ElideRight
            color: Style.colors.accent
            font.family: Style.font.main
            font.pointSize: Style.font.xl
            font.bold: true
          }

          IconButton {
            visible: root.current !== null && root.isUrl(root.current.preview)
            glyph: "\u{F03CC}"
            onActivated: {
              Qt.openUrlExternally(root.current.preview.trim());
              GlobalState.closeClipboard();
            }
          }
          IconButton {
            visible: root.current !== null
            glyph: "\u{F018F}"
            onActivated: root.accept()
          }
          IconButton {
            visible: root.current !== null
            glyph: root.current?.pinned ? "\u{F0931}" : "\u{F0403}"
            checked: root.current?.pinned ?? false
            onActivated: root.togglePin()
          }
          IconButton {
            visible: root.current !== null
            glyph: "\u{F01B4}"
            danger: true
            onActivated: root.remove()
          }
          IconButton {
            glyph: "\u{F0156}"
            onActivated: GlobalState.closeClipboard()
          }
        }

        Text {
          Layout.fillWidth: true
          text: root.meta(root.current, true)
          color: Style.colors.white
          font.family: Style.font.main
          font.pointSize: Style.font.large
        }

        Rectangle {
          Layout.fillWidth: true
          Layout.fillHeight: true
          color: Style.colors.gray1
          border.width: Style.bar.borderWidth
          border.color: Style.colors.gray3
          clip: true

          Image {
            id: preview
            anchors.fill: parent
            anchors.margins: Style.spacing.p4
            visible: root.current?.kind === "image"
            source: visible && ClipboardData.detailImage ? `file://${ClipboardData.detailImage}` : ""
            sourceSize.width: width * 2
            sourceSize.height: height * 2
            fillMode: Image.PreserveAspectFit
            asynchronous: true
            cache: false
          }

          Rectangle {
            visible: root.current !== null && root.isColor(root.current.preview)
            anchors.top: parent.top
            anchors.right: parent.right
            anchors.margins: Style.spacing.p4
            width: Style.clipboard.rowHeight
            height: Style.clipboard.rowHeight
            color: visible ? root.current.preview.trim() : "transparent"
            border.width: Style.bar.borderWidth
            border.color: Style.colors.gray6
          }

          ScrollView {
            anchors.fill: parent
            anchors.margins: Style.spacing.p4
            visible: root.current !== null && root.current.kind === "text"

            TextArea {
              readOnly: true
              selectByMouse: true
              wrapMode: TextEdit.WrapAnywhere
              text: root.currentText
              color: Style.colors.brightWhite
              selectionColor: Style.colors.accent
              selectedTextColor: Style.colors.onAccent
              font.family: Style.font.main
              font.pointSize: Style.font.large
              background: null
            }
          }
        }

        Text {
          visible: ClipboardData.detailTruncated && root.current?.kind === "text"
          text: "Preview truncated; copying uses the full entry."
          color: Style.colors.brightBlack
          font.family: Style.font.main
          font.pointSize: Style.font.normal
        }
      }
    }
  }
}
