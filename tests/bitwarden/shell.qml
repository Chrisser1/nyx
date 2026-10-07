// Bitwarden: the vault panel (listing, suggestions, copying and typing, lock and
// unlock) and the launcher's login form for a vault that is not set up.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.bitwarden
import qs.modules.launcher

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function entry(id) { return VaultData.entries.find(e => e.id === id) }
  function names(list) { return list.map(e => e.name).join() }

  FileView {
    id: clip
    path: `${Quickshell.env("STUB_DIR")}/clip`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  FileView {
    id: typed
    path: `${Quickshell.env("STUB_DIR")}/typed`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  readonly property var steps: [
    { what: "open the panel", ready: () => true,
      act: () => {
        VaultData.hint = "Sign in - GitHub - Mozilla Firefox firefox";
        GlobalState.openBitwarden("TEST");
      } },
    { what: "vault listed", settle: 3, ready: () => VaultData.state === "unlocked" && panel.entries.length === 2,
      act: () => {
        if (root.names(VaultData.entries) !== "GitHub,Wifi") root.fail("entries");
        if (root.names(VaultData.filter("")) !== "GitHub,Wifi") root.fail("suggestion first");
        VaultData.hint = "wifi settings";
        if (root.names(VaultData.filter("")) !== "Wifi,GitHub") root.fail(`suggestion follows the window: ${root.names(VaultData.filter(""))}`);
        if (root.names(VaultData.filter("hub")) !== "GitHub") root.fail("filter by name");
        if (root.names(VaultData.filter("chris")) !== "GitHub") root.fail("filter by user");
        if (root.names(VaultData.filter("dev github")) !== "GitHub") root.fail("filter by folder and site");
        VaultData.hint = "";
        if (root.names(VaultData.filter("")) !== "GitHub,Wifi") root.fail("no hint keeps vault order");
        if (VaultData.site("https://www.login.example.co.uk/x") !== "login") root.fail("site of a url");
        if (panel.current?.name !== "GitHub" || !panel.isLogin || panel.mainField !== "password") root.fail("first entry selected");
        VaultData.copy(root.entry("u1"), "password");
      } },
    { what: "password copied", settle: 3, ready: () => clip.text() === "hunter2",
      act: () => {
        panel.use("username", true);
        if (GlobalState.bitwardenOpen) root.fail("typing leaves the panel open");
      } },
    { what: "username typed", settle: 3, ready: () => typed.text() === "chris",
      act: () => {
        if (clip.text() !== "hunter2") root.fail("typing touched the clipboard");
        GlobalState.openBitwarden("TEST");
        VaultData.lock();
      } },
    { what: "locked", settle: 3, ready: () => VaultData.state === "locked",
      act: () => {
        if (panel.entries.length !== 0 || !panel.emptyText.includes("unlock")) root.fail(`locked panel: ${panel.emptyText}`);
        if (VaultData.email !== "me@example.com") root.fail(`email read back: ${VaultData.email}`);
        if (LauncherData.setupEntries("")[0].loginEmail !== VaultData.email) root.fail("login card offers the stored email");
        panel.setup();
      } },
    { what: "unlocked again", settle: 3, ready: () => VaultData.state === "unlocked",
      act: () => {
        if (panel.entries.length !== 2) root.fail("entries back after unlocking");
        GlobalState.closeAll();
        Quickshell.execDetached(["rm", "-f", `${Quickshell.env("STUB_DIR")}/cfg/email`]);
      } },
    { what: "email removed", settle: 3, ready: () => true,
      act: () => VaultData.refresh() },
    { what: "setup form", settle: 3, ready: () => VaultData.state === "unconfigured",
      act: () => {
        if (!LauncherData.vaultNeedsSetup) root.fail("setup state");
        if (LauncherData.setupEntries("me@example.com")[0].loginEmail !== "me@example.com") root.fail("login card takes the email");
        if (LauncherData.setupEntries("nope")[0].loginEmail !== "") root.fail("login card rejects a non-email");
        if (LauncherData.setupEntries("").map(e => e.setRegion).filter(Boolean).join() !== "com,eu") root.fail("region cards");
        const url = LauncherData.setupEntries("https://vault.example.org");
        if (url[url.length - 1].setRegion !== "https://vault.example.org" || url[0].loginEmail !== "") root.fail("server url card");
        if (!LauncherData.setupEntries("")[1].name.startsWith("● ")) root.fail("default region marked");
        LauncherData.vaultRegion = "eu";
        if (!LauncherData.setupEntries("")[2].name.startsWith("● ")) root.fail("chosen region marked");
        LauncherData.loginVault("TEST", "me@example.com");
      } },
    { what: "panel open after login", ready: () => GlobalState.bitwardenOpen && VaultData.state === "unlocked",
      act: () => {
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1440
    implicitHeight: 700
    color: "black"

    BitwardenPanel {
      id: panel
      monitorId: "TEST"
    }

    Launcher {
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
