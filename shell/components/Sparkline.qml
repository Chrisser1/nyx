// A minimal bar-chart sparkline: one column per sample, oldest on the left.
//
// Rectangles rather than a Canvas on purpose -- Canvas repaints its whole
// surface on every value change. The column widths are derived from the item's
// width, so the caller sizes it with Layout.preferredWidth like any other widget.
//
// The Repeater's model is a fixed count, not the samples array: an array model
// destroys and recreates every column on each tick, whereas this only rebinds
// heights. Samples are also only taken up while the chart is visible, so the
// copies on closed panels (one per monitor) do no work at all.

import QtQuick
import qs.config

Item {
  id: root

  // Newest sample last.
  property var values: []
  property int maxSamples: 60
  // 0 means autoscale to the largest sample in view -- what throughput wants,
  // since there is no meaningful ceiling on a link's rate. A fixed 1.0 is right
  // for the 0..1 ratios ResourceUsage publishes.
  property real maxValue: 1.0
  property color tint: Style.colors.accent
  property real gap: 1

  implicitWidth: Style.system.sparkWidth
  implicitHeight: Style.system.sparkHeight

  // Left-padded with zeroes so the chart grows in from the right while history
  // fills up, instead of a handful of samples stretching across the whole width.
  property var samples: []
  property real ceiling: 1

  function update(): void {
    const tail = (root.values ?? []).slice(-root.maxSamples);
    const padded = new Array(Math.max(0, root.maxSamples - tail.length)).fill(0).concat(tail);
    if (root.maxValue > 0) {
      root.ceiling = root.maxValue;
    } else {
      const peak = Math.max(0, ...padded);
      root.ceiling = peak > 0 ? peak : 1;
    }
    root.samples = padded;
  }

  onValuesChanged: if (root.visible) root.update()
  onVisibleChanged: if (root.visible) root.update()
  Component.onCompleted: root.update()

  readonly property real columnWidth: Math.max(
    1, (root.width - root.gap * (root.maxSamples - 1)) / root.maxSamples)

  Row {
    anchors.fill: parent
    spacing: root.gap

    Repeater {
      model: root.maxSamples

      delegate: Item {
        required property int index
        width: root.columnWidth
        height: root.height

        Rectangle {
          anchors.bottom: parent.bottom
          width: parent.width
          // A 1px floor so an idle stretch still reads as a baseline rather
          // than a hole in the chart.
          height: Math.max(1, Math.min(1, (root.samples[index] ?? 0) / root.ceiling) * parent.height)
          color: root.tint
        }
      }
    }
  }
}
