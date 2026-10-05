// Window switcher: focus-history order, cycling, wrap-around and closing.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.switcher

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function expect(index, address) {
    if (!GlobalState.switcherOpen) root.fail(`closed, expected ${address}`);
    if (WindowSwitcher.index !== index || WindowSwitcher.selected?.address !== address)
      root.fail(`selected ${WindowSwitcher.index}:${WindowSwitcher.selected?.address}, expected ${index}:${address}`);
  }

  function client(address, cls, title, history, hidden = false) {
    return { address, class: cls, title, focusHistoryID: history, mapped: true, hidden, workspace: { name: "1" } };
  }

  readonly property var steps: [
    { what: "start", ready: () => true,
      act: () => {
        HyprlandData.windowList = [
          root.client("0xa", "kitty", "shell", 2),
          root.client("0xb", "firefox", "browser", 0),
          root.client("0xc", "org.kde.okular", "paper.pdf", 1),
          root.client("0xd", "steam", "hidden", 3, true)
        ];
        WindowSwitcher.next();
        GlobalState.switcherMonitorId = "TEST";
        if (WindowSwitcher.windows.map(w => w.address).join() !== "0xb,0xc,0xa") root.fail("order");
        root.expect(1, "0xc");
        HyprlandData.windowList = [];
        if (WindowSwitcher.windows.length !== 3) root.fail("snapshot changed while open");
      } },
    // The panel has to render the first press before the next one arrives.
    { what: "first press shown", settle: 5, ready: () => true,
      act: () => {
        if (panel.shownIndex !== 1) root.fail(`first press highlights ${panel.shownIndex}, selection 1`);
        WindowSwitcher.next();
      } },
    { what: "second press shown", settle: 5, ready: () => true,
      act: () => {
        if (panel.shownIndex !== 2) root.fail(`second press highlights ${panel.shownIndex}, selection 2`);
        root.expect(2, "0xa");
        WindowSwitcher.next();
        root.expect(0, "0xb");
        WindowSwitcher.previous();
        root.expect(2, "0xa");
      } },
    { what: "render", settle: 5, ready: () => true,
      act: () => {
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/switcher.png`));
      } },
    { what: "screenshot", settle: 5, ready: () => true,
      act: () => {
        WindowSwitcher.commit();
        if (GlobalState.switcherOpen) root.fail("commit left it open");
        WindowSwitcher.commit();
        HyprlandData.windowList = [root.client("0xa", "kitty", "shell", 0), root.client("0xb", "firefox", "web", 1)];
        WindowSwitcher.previous();
        root.expect(1, "0xb");
        GlobalState.closeAll();
        if (GlobalState.switcherOpen) root.fail("closeAll left it open");
        HyprlandData.windowList = [];
        WindowSwitcher.next();
        if (GlobalState.switcherOpen) root.fail("opened with no windows");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1200
    implicitHeight: 400
    color: "black"

    WindowSwitcherPanel {
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
