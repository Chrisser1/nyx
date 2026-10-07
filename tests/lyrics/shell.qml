// LyricsData: LRC parsing, which line is playing at a position, and how a
// nyx-lyrics result becomes a state. No network and no player involved.
import QtQuick
import Quickshell
import qs.services

ShellRoot {
  id: root

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  // Qt.exit before the event loop runs is ignored, so run from a timer.
  Timer {
    interval: 100
    running: true
    onTriggered: root.run()
  }

  function run() {
    const lrc = "[ar:Someone]\n[00:12.50] second\n[00:01.00]first\n[01:02.25][00:30.00]chorus\n[00:40.00]";
    const lines = LyricsData.parseLrc(lrc);

    if (lines.map(l => l.text).join("|") !== "first|second|chorus||chorus") fail(`order and text: ${JSON.stringify(lines)}`);
    if (lines[0].time !== 1 || lines[1].time !== 12.5) fail("times");
    if (lines[4].time !== 62.25) fail(`minutes: ${lines[4].time}`);
    if (LyricsData.parseLrc("just words\nno stamps").length !== 0) fail("unstamped text is not a line");

    if (LyricsData.indexAt(lines, 0.5) !== -1) fail("before the first line");
    if (LyricsData.indexAt(lines, 1) !== 0) fail("on the first stamp");
    if (LyricsData.indexAt(lines, 29.99) !== 1) fail("between lines");
    if (LyricsData.indexAt(lines, 35) !== 2) fail("mid-song");
    if (LyricsData.indexAt(lines, 999) !== 4) fail("after the last line");
    if (LyricsData.indexAt([], 5) !== -1) fail("no lines");

    const synced = LyricsData.resolve({ synced: "[00:01.00]a", plain: "a" });
    if (synced.state !== "synced" || synced.lines.length !== 1) fail("synced wins over plain");
    const plain = LyricsData.resolve({ synced: "", plain: "one\ntwo" });
    if (plain.state !== "plain" || plain.lines.length !== 2 || plain.lines[0].time !== -1) fail("plain lines are unstamped");
    if (LyricsData.resolve({}).state !== "none") fail("nothing is none");

    console.log("PASS");
    Qt.exit(0);
  }
}
