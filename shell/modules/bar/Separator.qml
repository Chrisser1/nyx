import qs.config
import QtQuick
import QtQuick.Layouts

Rectangle {
  implicitWidth: Style.bar.borderWidth
  implicitHeight: Style.bar.height - Style.bar.borderWidth
  Layout.bottomMargin: Style.bar.borderWidth
  color: Style.colors.gray3
}
