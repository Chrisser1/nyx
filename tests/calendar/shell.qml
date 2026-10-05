// Calendar panel with no calendar: the add-calendar form shows by itself,
// adds a CalDAV calendar (password over stdin) and gives way to the month.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.calendar

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function shot(name) {
    if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/${name}.png`));
  }

  FileView {
    id: password
    path: `${Quickshell.env("STUB_DIR")}/password`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  FileView {
    id: calls
    path: `${Quickshell.env("STUB_DIR")}/calls`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  function count(item, name) {
    let n = item.objectName === name ? 1 : 0;
    for (const c of item.children) n += root.count(c, name);
    return n;
  }

  readonly property var steps: [
    { what: "open", ready: () => true,
      act: () => GlobalState.openCalendar("TEST") },
    { what: "form shown without a calendar", settle: 5,
      ready: () => Calendar.refreshed && !Calendar.available,
      act: () => {
        if (!Calendar.setupShown) root.fail("setup form not shown by itself");
        root.shot("calendar-setup");
        Calendar.addCalDav("Home", "https://cloud.example.org/dav/", "me", "s3cret");
      } },
    { what: "calendar added", settle: 3, ready: () => !Calendar.addingCalendar && Calendar.available,
      act: () => {
        if (password.text().trim() !== "s3cret") root.fail(`password on stdin: ${password.text()}`);
        if (Calendar.setupShown) root.fail("form still shown after adding");
        if (Calendar.calendarError !== "") root.fail(`unexpected error: ${Calendar.calendarError}`);
        Calendar.openSetup();
      } },
    { what: "form reopened from the header", settle: 3, ready: () => Calendar.setupShown && Calendar.googleCalendars.length === 2,
      act: () => {
        const rows = root.count(panel, "googleCalendar");
        if (rows !== 2) root.fail(`google calendar rows: ${rows}`);
        const family = Calendar.googleCalendars[1];
        if (family.name !== "Family" || family.added) root.fail("family calendar listed as not added");
        root.shot("calendar-google");
        Calendar.toggleGoogle(Calendar.googleCalendars[0]);
        Calendar.toggleGoogle(family);
      } },
    { what: "family calendar added", settle: 3, ready: () => !Calendar.googleBusy && calls.text().includes("add-google"),
      act: () => {
        if (!calls.text().includes("add-google /caldav/v2/x@group.calendar.google.com/events Family")) root.fail(`add call: ${calls.text()}`);
        if (calls.text().includes("add-google /caldav/v2/me@gmail.com/events")) root.fail("the main calendar was toggled");
        Calendar.closeSetup();
        if (Calendar.setupShown) root.fail("Back did not close the form");
        root.shot("calendar");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1200
    implicitHeight: 720
    color: "black"

    CalendarPanel {
      id: panel
      monitorId: "TEST"
    }
  }

  Timer {
    interval: 100
    repeat: true
    running: true
    onTriggered: {
      const s = root.steps[root.step];
      if (s.ready() && root.waited >= (s.settle ?? 0)) {
        root.waited = 0;
        root.step++;
        s.act();
      } else if (++root.waited > 150) {
        root.fail(`timed out waiting for: ${s.what}`);
      }
    }
  }
}
