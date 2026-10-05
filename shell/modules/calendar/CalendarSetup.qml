// Add-calendar form: a Google account through Evolution's sign-in, or a CalDAV
// calendar (Nextcloud, iCloud, Fastmail...) from its address and password.
// Shown in place of the month grid.

pragma ComponentBehavior: Bound

import qs
import qs.config
import qs.services
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
  id: root
  spacing: Style.spacing.p1

  readonly property bool valid: name.text.trim() !== "" && address.text.trim() !== ""
    && user.text.trim() !== "" && password.text !== ""

  function submit() {
    if (!root.valid || Calendar.addingCalendar) return
    Calendar.addCalDav(name.text.trim(), address.text.trim(), user.text.trim(), password.text)
  }

  component Field: TextField {
    Layout.fillWidth: true
    leftPadding: Style.spacing.p1
    renderType: TextField.NativeRendering
    color: Style.colors.brightWhite
    placeholderTextColor: Style.colors.gray6
    font.family: Style.font.light
    font.pointSize: Style.font.small
    enabled: !Calendar.addingCalendar
    background: Rectangle {
      color: "transparent"
      border.color: parent.activeFocus ? Style.colors.gray6 : Style.colors.gray3
    }
    Keys.onReturnPressed: root.submit()
  }

  component Button: Rectangle {
    id: btn
    property alias text: label.text
    property bool primary: false
    property bool enabled: true
    signal activated()
    Layout.fillWidth: true
    implicitHeight: label.implicitHeight + Style.spacing.p2 * 2
    color: area.containsMouse && btn.enabled ? Style.colors.gray2 : "transparent"
    border.width: Style.bar.borderWidth
    border.color: btn.primary && btn.enabled ? Style.colors.accent : Style.colors.gray3
    opacity: btn.enabled ? 1 : 0.5

    Text {
      id: label
      anchors.centerIn: parent
      color: Style.colors.brightWhite
      font.family: Style.font.main
      font.pointSize: Style.font.small
    }

    MouseArea {
      id: area
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: if (btn.enabled) btn.activated()
    }
  }

  Text {
    Layout.fillWidth: true
    text: Calendar.available ? "Add a calendar" : "No calendar yet. Add one:"
    color: Style.colors.brightWhite
    font.family: Style.font.main
    font.pointSize: Style.font.normal
  }

  Button {
    text: "Google account"
    onActivated: Calendar.openAccounts()
  }

  // Everything the Google account can see; shared calendars are added here.
  Text {
    Layout.fillWidth: true
    visible: Calendar.googleCalendars.length > 0
    text: "Google calendars"
    color: Style.colors.brightWhite
    font.family: Style.font.main
    font.pointSize: Style.font.small
  }

  Repeater {
    model: Calendar.googleCalendars

    RowLayout {
      id: entry
      required property var modelData
      objectName: "googleCalendar"
      Layout.fillWidth: true
      spacing: Style.spacing.p1

      Text {
        Layout.fillWidth: true
        text: entry.modelData.name
        elide: Text.ElideRight
        color: entry.modelData.added ? Style.colors.brightWhite : Style.colors.gray5
        font.family: Style.font.main
        font.pointSize: Style.font.small
      }
      Button {
        objectName: "googleToggle"
        Layout.fillWidth: false
        implicitWidth: Style.font.size4 * 4
        text: entry.modelData.primary ? "Main" : entry.modelData.added ? "Remove" : "Add"
        primary: !entry.modelData.added
        enabled: !entry.modelData.primary && !Calendar.googleBusy
        onActivated: Calendar.toggleGoogle(entry.modelData)
      }
    }
  }

  Text {
    Layout.fillWidth: true
    visible: Calendar.googleError !== ""
    text: Calendar.googleError
    wrapMode: Text.WordWrap
    color: Style.colors.brightRed
    font.family: Style.font.main
    font.pointSize: Style.font.tiny
  }

  Text {
    Layout.fillWidth: true
    text: "or CalDAV (Nextcloud, iCloud, Fastmail), using the calendar's own address"
    wrapMode: Text.WordWrap
    color: Style.colors.gray5
    font.family: Style.font.main
    font.pointSize: Style.font.tiny
  }

  Field { id: name; placeholderText: "  Name"; text: "CalDAV" }
  Field { id: address; placeholderText: "  https://cloud.example.org/remote.php/dav/calendars/me/personal/" }
  Field { id: user; placeholderText: "  Username" }
  Field { id: password; placeholderText: "  Password"; echoMode: TextInput.Password }

  Text {
    Layout.fillWidth: true
    visible: Calendar.calendarError !== ""
    text: Calendar.calendarError
    wrapMode: Text.WordWrap
    color: Style.colors.brightRed
    font.family: Style.font.main
    font.pointSize: Style.font.tiny
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Style.spacing.p1

    Button {
      text: "Back"
      onActivated: Calendar.closeSetup()
    }
    Button {
      text: Calendar.addingCalendar ? "Adding…" : "Add calendar"
      primary: true
      enabled: root.valid && !Calendar.addingCalendar
      onActivated: root.submit()
    }
  }

  Item { Layout.fillHeight: true }

  Connections {
    target: Calendar
    function onCalendarAdded() { password.text = "" }
  }
}
