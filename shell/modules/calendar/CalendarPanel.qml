// Month grid + agenda, dropped from the bar when the clock is clicked.
//
// Built on the same sliding-Item idiom as modules/launcher/Launcher.qml rather
// than a PopupWindow: it lives inside shell.qml's fullscreen "main" panel, and
// GlobalState.overlayOpen is what flips that panel's input mask so the contents
// become clickable. Unlike the launcher it does not bump the exclusion zone --
// this floats over the windows instead of pushing them up.

pragma ComponentBehavior: Bound

import qs
import qs.components
import qs.config
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland

Item {
  id: root
  required property string monitorId

  anchors.top: parent.top
  anchors.topMargin: Style.bar.height
  anchors.right: parent.right
  anchors.rightMargin: Style.spacing.p1

  implicitWidth: Style.calendar.width
  implicitHeight: Style.calendar.height

  // The slide happens inside these bounds.
  clip: true

  readonly property bool active: GlobalState.calendarOpen
    && GlobalState.calendarMonitorId === root.monitorId

  // Only render while on-screen or mid-transition.
  visible: panel.y > -Style.calendar.height

  onActiveChanged: {
    if (root.active) {
      Calendar.refresh()
    } else {
      quickAdd.focus = false
    }
  }

  Connections {
    target: Calendar
    function onAdded() { quickAdd.text = "" }
  }

  GlobalShortcut { // qmllint disable unresolved-type
    appid: "nyx"
    name: "toggleCalendar"
    description: "Toggles the calendar panel"
    onPressed: {
      if (Hyprland.focusedMonitor?.name === root.monitorId) {
        GlobalState.toggleCalendar(root.monitorId)
      }
    }
  }

  component IconButton: Rectangle {
    id: btn
    required property string glyph
    property string tip: ""
    signal activated()

    implicitWidth: Style.font.size4 + Style.spacing.p1 * 2
    implicitHeight: Style.font.size4 + Style.spacing.p0 * 2
    color: area.containsMouse ? Style.colors.gray2 : "transparent"

    Behavior on color {
      ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
    }

    Text {
      anchors.centerIn: parent
      text: btn.glyph
      color: area.containsMouse ? Style.colors.brightWhite : Style.colors.white
      font.family: Style.font.symbols
      font.pixelSize: Style.font.size2
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: btn.activated()
    }

    Tip {
      text: btn.tip
      hovered: area.containsMouse
    }
  }

  BorderRect {
    id: panel

    anchors.left: parent.left
    anchors.right: parent.right
    implicitHeight: Style.calendar.height

    // 0 == fully open, -Style.calendar.height == fully hidden behind the bar.
    y: root.active ? 0 : -Style.calendar.height

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
      visible: !Calendar.setupShown
      anchors.fill: parent
      anchors.margins: Style.spacing.p2
      spacing: Style.spacing.p1

      // ── Header: month nav ────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: Style.spacing.p0

        IconButton {
          glyph: "󰅁"
          tip: "Previous month"
          onActivated: Calendar.prevMonth()
        }

        Text {
          Layout.fillWidth: true
          horizontalAlignment: Text.AlignHCenter
          text: Calendar.monthLabel
          color: Style.colors.brightWhite
          font.family: Style.font.main
          font.pointSize: Style.font.normal
        }

        IconButton {
          glyph: "󰅂"
          tip: "Next month"
          onActivated: Calendar.nextMonth()
        }

        IconButton {
          glyph: "󰃭"
          tip: "Jump to today"
          onActivated: Calendar.goToday()
        }

        IconButton {
          glyph: "󰐕"
          tip: "Calendar setup"
          onActivated: Calendar.openSetup()
        }

        IconButton {
          glyph: "󰏌"
          tip: "Open in calendar app"
          onActivated: {
            Calendar.openExternal()
            GlobalState.closeCalendar()
          }
        }
      }

      BorderRect {
        Layout.fillWidth: true
        implicitHeight: Style.bar.borderWidth
        color: Style.colors.gray3
        borderWidth: 0
      }

      // ── Weekday header ───────────────────────────────────────────────
      RowLayout {
        Layout.fillWidth: true
        spacing: 0
        Repeater {
          model: Calendar.weekdays
          delegate: Text {
            required property string modelData
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: modelData
            color: Style.colors.gray5
            font.family: Style.font.main
            font.pointSize: Style.font.tiny
          }
        }
      }

      // ── Month grid ───────────────────────────────────────────────────
      GridLayout {
        Layout.fillWidth: true
        columns: 7
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
          model: Calendar.days

          delegate: Rectangle {
            id: cell
            required property var modelData

            readonly property bool selected: Calendar.sameDay(cell.modelData.date, Calendar.selectedDate)

            Layout.fillWidth: true
            implicitHeight: Style.calendar.cellSize * 0.72

            color: {
              if (cell.modelData.isToday) return Style.colors.accent
              if (cell.selected) return Style.colors.gray2
              if (cellArea.containsMouse) return Style.colors.gray1
              return "transparent"
            }

            Behavior on color {
              ColorAnimation { duration: Style.durations.tiny; easing.type: Easing.OutQuad }
            }

            ColumnLayout {
              anchors.centerIn: parent
              spacing: 1

              Text {
                Layout.alignment: Qt.AlignHCenter
                text: cell.modelData.day
                color: {
                  if (cell.modelData.isToday) return Style.colors.brightWhite
                  if (!cell.modelData.inMonth) return Style.colors.gray4
                  return Style.colors.white
                }
                font.family: Style.font.main
                font.pointSize: Style.font.small
              }

              // Event marker. Kept at a constant height so the row doesn't
              // shift when a day gains or loses events.
              Rectangle {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 4
                implicitHeight: 4
                radius: 2
                visible: cell.modelData.eventCount > 0
                color: cell.modelData.isToday ? Style.colors.brightWhite : Style.colors.accent
              }
              Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 4
                implicitHeight: 4
                visible: cell.modelData.eventCount === 0
              }
            }

            MouseArea {
              id: cellArea
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: Calendar.selectedDate = cell.modelData.date
            }
          }
        }
      }

      BorderRect {
        Layout.fillWidth: true
        implicitHeight: Style.bar.borderWidth
        color: Style.colors.gray3
        borderWidth: 0
      }

      // ── Agenda for the selected day ──────────────────────────────────
      Text {
        Layout.fillWidth: true
        text: Qt.formatDateTime(Calendar.selectedDate, "dddd dd MMMM")
        color: Style.colors.gray5
        font.family: Style.font.main
        font.pointSize: Style.font.tiny
      }

      Item {
        Layout.fillWidth: true
        Layout.fillHeight: true

        ListView {
          id: agenda
          anchors.fill: parent
          clip: true
          spacing: Style.spacing.p0
          model: Calendar.selectedEvents

          delegate: RowLayout {
            required property var modelData
            width: agenda.width
            spacing: Style.spacing.p1

            Text {
              Layout.alignment: Qt.AlignTop
              Layout.preferredWidth: 44
              text: modelData.allDay ? "all day" : modelData.startTime
              color: Style.colors.gray5
              font.family: Style.font.main
              font.pointSize: Style.font.tiny
            }
            Text {
              Layout.fillWidth: true
              text: modelData.title
              color: Style.colors.brightWhite
              elide: Text.ElideRight
              font.family: Style.font.main
              font.pointSize: Style.font.small
            }
          }
        }

        // Empty / not-set-up state. A plain child of the ListView would sit
        // inside its scrolling contentItem, so it's a sibling overlay.
        Text {
          anchors.centerIn: parent
          width: parent.width - Style.spacing.p2 * 2
          visible: agenda.count === 0
          horizontalAlignment: Text.AlignHCenter
          wrapMode: Text.WordWrap
          color: Style.colors.gray4
          font.family: Style.font.main
          font.pointSize: Style.font.tiny
          text: {
            if (Calendar.loading) return "Loading…"
            if (!Calendar.available) return "No calendar yet"
            return "No events"
          }
        }
      }

      // ── Quick add ────────────────────────────────────────────────────
      // Google's natural-language quickAdd, so "coffee tomorrow 9am" works.
      // Not auto-focused on open: the panel is mostly a glance, and grabbing
      // the keyboard every time you check the date would be worse than a click.
      TextField {
        id: quickAdd
        Layout.fillWidth: true
        enabled: Calendar.available && !Calendar.adding
        leftPadding: Style.spacing.p1
        renderType: TextField.NativeRendering
        cursorVisible: activeFocus
        color: Style.colors.brightWhite
        placeholderTextColor: Calendar.addError ? Style.colors.brightRed : Style.colors.gray6
        font.family: Style.font.light
        font.pointSize: Style.font.small
        placeholderText: {
          if (!Calendar.available) return "  Not connected"
          if (Calendar.adding) return "  Adding…"
          if (Calendar.addError) return `  ${Calendar.addError}`
          return "  Quick add — e.g. coffee tomorrow 9am"
        }

        background: Rectangle {
          color: "transparent"
          border.color: quickAdd.activeFocus ? Style.colors.gray6 : Style.colors.gray3

          Behavior on border.color {
            ColorAnimation { duration: Style.durations.small; easing.type: Easing.OutQuad }
          }
        }

        onAccepted: Calendar.addEvent(text)
        Keys.onEscapePressed: GlobalState.closeCalendar()
      }
    }

    CalendarSetup {
      visible: Calendar.setupShown
      anchors.fill: parent
      anchors.margins: Style.spacing.p2
    }
  }
}
