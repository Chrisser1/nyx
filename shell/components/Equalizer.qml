// A few bouncing columns summarising the cava bars (0..1 each): the bars are
// split into `count` groups and each column shows its group's loudest bar, so a
// single peak still moves it.

import qs.config
import QtQuick

Item {
  id: root
  property var bars: []
  property int count: 8
  property color color: Style.colors.accent
  property real columnWidth: 3
  property real gap: 2

  // The tallest a column can be, as a fraction of the height; the rest is the floor.
  readonly property real floor: 2

  implicitWidth: root.count * root.columnWidth + (root.count - 1) * root.gap

  function level(index) {
    const n = root.bars.length
    if (n === 0) return 0
    const from = Math.floor(index * n / root.count)
    const to = Math.max(from + 1, Math.floor((index + 1) * n / root.count))
    let peak = 0
    for (let i = from; i < to; i++) peak = Math.max(peak, root.bars[i])
    return Math.min(1, peak)
  }

  Repeater {
    model: root.count

    Rectangle {
      required property int index
      readonly property real value: root.level(index)

      x: index * (root.columnWidth + root.gap)
      anchors.bottom: parent.bottom
      width: root.columnWidth
      height: Math.max(root.floor, value * root.height)
      color: root.color

      Behavior on height { NumberAnimation { duration: 60 } }
    }
  }
}
