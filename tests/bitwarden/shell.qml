// Launcher Bitwarden mode: vault entries and their copy commands, and the
// locked and unconfigured states.
import QtQuick
import Quickshell
import qs
import qs.services
import qs.modules.launcher

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  function entry(id) {
    return LauncherData.vaultEntries.find(e => e.id === id);
  }

  readonly property var steps: [
    { what: "open bitwarden mode", ready: () => true,
      act: () => GlobalState.openLauncher({ id: "TEST", mode: "bitwarden" }) },
    { what: "vault listed", ready: () => LauncherData.vaultState === "unlocked",
      act: () => {
        if (LauncherData.vaultEntries.map(e => e.name).join() !== "GitHub,Wifi,Sync vault,Lock vault") root.fail("entries");
        const github = root.entry("nyx-bw-u1");
        if (github.script.slice(-2).join() !== "u1,password") root.fail("login copies the password");
        if (github.actions.map(a => a.script[3]).join() !== "username,totp,notes") root.fail("login drawer");
        if (github.genericName !== "chris" || github.categories.join() !== "Dev,Login") root.fail("login labels");
        if (root.entry("nyx-bw-u2").script[3] !== "notes") root.fail("note copies the note");
        if (LauncherData.bitwardenData.length !== 4) root.fail("search data");
        LauncherData.launch(root.entry("nyx-bw-lock"));
      } },
    { what: "locked", settle: 3, ready: () => true,
      act: () => LauncherData.refreshBitwarden() },
    { what: "unlock card", ready: () => LauncherData.vaultState === "locked",
      act: () => {
        if (LauncherData.vaultEntries.length !== 1 || !LauncherData.vaultEntries[0].unlockVault) root.fail("unlock card");
        GlobalState.closeLauncher();
        LauncherData.unlockVault("TEST");
      } },
    { what: "reopened after unlock", ready: () => GlobalState.launcherOpen && GlobalState.launcherMode === "bitwarden",
      act: () => {
        Quickshell.execDetached(["rm", "-f", `${Quickshell.env("STUB_DIR")}/cfg/email`]);
      } },
    { what: "email removed", settle: 3, ready: () => true,
      act: () => LauncherData.refreshBitwarden() },
    { what: "setup form", settle: 3, ready: () => LauncherData.vaultState === "unconfigured",
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
        GlobalState.closeLauncher();
        LauncherData.loginVault("TEST", "me@example.com");
      } },
    { what: "reopened after login", ready: () => GlobalState.launcherOpen && GlobalState.launcherMode === "bitwarden",
      act: () => LauncherData.refreshBitwarden() },
    { what: "logged in", ready: () => LauncherData.vaultState === "unlocked",
      act: () => {
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1440
    implicitHeight: 400
    color: "black"

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
