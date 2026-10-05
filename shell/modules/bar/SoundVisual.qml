// Live equalizer in the bar while something is making sound. Fades out a
// moment after the sound stops, so a gap between tracks does not flicker it.

import qs.components
import qs.config
import qs.services
import QtQuick

Item {
  id: root

  opacity: AudioData.sounding ? 1 : 0
  visible: opacity > 0
  Behavior on opacity { NumberAnimation { duration: Style.durations.small; easing.type: Easing.OutCubic } }

  implicitWidth: equalizer.implicitWidth
  implicitHeight: parent.height

  Equalizer {
    id: equalizer
    anchors.verticalCenter: parent.verticalCenter
    height: root.height * 0.55
    bars: AudioData.bars
  }
}
