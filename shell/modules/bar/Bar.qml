// ┌───────────────────────────────────────────────┐
// │█▀▀▀▀▀▀▀▀█░░░░░░░░█▀▄░█▀█░█▀▄░░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░░░░█▀▄░█▀█░█▀▄░░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀█░░░░░░░░▀▀░░▀░▀░▀░▀░░░░░░░░█▀▀▀▀▀▀▀▀█│
// │█▀▀▀▀▀▀▀▀▀───────────────────────────▀▀▀▀▀▀▀▀▀█│
// ├┤ Author  : Daniel Berg <mail@roosta.sh>      ├┤
// ││ Repo    : https://github.com/roosta/dotfiles││
// ││ Site    : https://www.roosta.sh             ││
// ├┤ License : GNU General Public License v3     ├┤
// ┆└─────────────────────────────────────────────┘┆

import QtQuick
import qs.components
import qs.services
import QtQuick.Controls
import QtQuick.Layouts
import qs.config
pragma ComponentBehavior: Bound

Item {
  id: root
  required property string monitorId

  z: 1
  implicitHeight: Style.bar.height

  signal decrementCurrentIndex()
  signal incrementCurrentIndex()
  signal drawerNext()
  signal drawerPrev()
  signal accepted()
  signal openDrawer()
  signal closeDrawer()
  signal drawerActivate()

  anchors {
    top: parent.top
    left: parent.left
    right: parent.right
  }

  // One layout for every output. There used to be a Loader here picking between
  // bar variants, but it only ever had this one, and its wrapper Rectangles were
  // transparent and filled their parent.
  BorderRect {
    color: Style.colors.black
    borderColor: Style.colors.gray3
    bottomBorder: 1
    anchors {
      right: parent.right
      left: parent.left
      top: parent.top
      bottom: parent.bottom
    }

    RowLayout {
      anchors.fill: parent
      spacing: 0

      Rectangle {
        Layout.fillWidth: true
        Layout.fillHeight: true
        color: "transparent"
        RowLayout {
          spacing: Style.spacing.p1
          anchors.left: parent.left
          anchors.fill: parent
          LauncherButton {
            monitorId: root.monitorId
            onDecrementCurrentIndex: root.decrementCurrentIndex()
            onIncrementCurrentIndex: root.incrementCurrentIndex()
            onOpenDrawer: root.openDrawer()
            onCloseDrawer: root.closeDrawer()
            onDrawerNext: root.drawerNext()
            onDrawerActivate: root.drawerActivate()
            onDrawerPrev: root.drawerPrev()
            onAccepted: root.accepted()
          }
          Separator {}
          Loader {
            Layout.fillHeight: true
            Layout.fillWidth: true
            active: LauncherData.appsData.length > 0
            sourceComponent: Context { }
          }

          MediaWidget { monitorId: root.monitorId }
        }
      }

      Rectangle {
        color: "transparent"
        Layout.fillHeight: true
        Layout.fillWidth: true
        RowLayout {
          spacing: Style.spacing.p1
          anchors.centerIn: parent
          ShiftButton { direction: -1; monitorId: root.monitorId }
          Workspaces { monitorId: root.monitorId }
          ShiftButton { direction: 1; monitorId: root.monitorId }
        }
      }

      Rectangle {
        Layout.fillHeight: true
        Layout.fillWidth: true
        color: "transparent"
        RowLayout {
          spacing: Style.spacing.p1
          anchors.right: parent.right
          SysmonWidget { }
          NetworkWidget { monitorId: root.monitorId }
          BluetoothWidget { }
          BatteryWidget { }
          Separator {}
          Clock { monitorId: root.monitorId }
          Separator {}
          AlertsIndicator { monitorId: root.monitorId }
          SystemButton { monitorId: root.monitorId }
          AudioButton { monitorId: root.monitorId }
          TrayButton { monitorId: root.monitorId }
          Separator {}
          NotificationButton { monitorId: root.monitorId }
        }
      }
    }
  }
}
