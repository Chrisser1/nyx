// Tailnet panel: status, ordering, filtering, actions and the stopped state.
// Saves a screenshot to $OUT when set.
import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.modules.tailnet

ShellRoot {
  id: root

  property int step: 0
  property int waited: 0

  function fail(what) {
    console.error(`FAIL ${what}`);
    Qt.exit(1);
  }

  FileView {
    id: calls
    path: `${Quickshell.env("STUB_DIR")}/calls`
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
  }

  readonly property var steps: [
    { what: "status loaded", ready: () => TailnetData.nodes.length === 4,
      act: () => {
        if (TailnetData.nodes.map(n => n.host).join() !== "laptop,pc-1,server,pixel") root.fail("order");
        if (TailnetData.exitNode?.host !== "server") root.fail("exit node");
        if (TailnetData.online !== 2) root.fail("online count");
        if (TailnetData.filter("android").map(n => n.host).join() !== "pixel") root.fail("filter by os");
        if (TailnetData.filter("100.64.0.3").length !== 1) root.fail("filter by ip");
        if (TailnetData.peers.find(p => p.host === "pc-1").tailscaleSsh !== true) root.fail("tailscale ssh offered");
        if (TailnetData.peers.find(p => p.host === "server").tailscaleSsh !== false) root.fail("tailscale ssh not offered");
        GlobalState.openTailnet("TEST");
      } },
    { what: "panel open", settle: 5, ready: () => panel.current?.self === true,
      act: () => {
        if (Quickshell.env("OUT")) panel.grabToImage(r => r.saveToFile(`${Quickshell.env("OUT")}/tailnet.png`));
        panel.toggleExitNode();
        TailnetData.useExitNode(TailnetData.exitNode ? null : TailnetData.peers[1]);
        TailnetData.setRunning(false);
      } },
    { what: "ssh tested", ready: () => true,
      act: () => TailnetData.checkSsh(TailnetData.peers.find(p => p.host === "pc-1")) },
    { what: "ssh test result", ready: () => TailnetData.checking === "" && Object.keys(TailnetData.sshChecks).length === 1,
      act: () => {
        const r = Object.values(TailnetData.sshChecks)[0];
        if (!r.ok || r.login !== "root@pc-1.tail0.ts.net") root.fail(`ssh login: ${JSON.stringify(r)}`);
        if (r.errors.length !== 1) root.fail("the refused login is reported");
        if (panel.sshRows(TailnetData.peers.find(p => p.host === "pc-1"))[0].value !== "Works as root@pc-1.tail0.ts.net") root.fail("ssh row");
      } },
    { what: "ping", ready: () => true,
      act: () => TailnetData.ping(TailnetData.peers.find(p => p.host === "pc-1")) },
    { what: "ping result", ready: () => TailnetData.pinging === "" && Object.keys(TailnetData.pings).length === 1,
      act: () => {
        const r = Object.values(TailnetData.pings)[0];
        if (!r.ok || r.avg !== 20 || !r.direct) root.fail(`ping: ${JSON.stringify(r)}`);
        const row = panel.pingRows(TailnetData.peers.find(p => p.host === "pc-1"))[0];
        if (row.value !== "20 ms, direct") root.fail(`ping row: ${row.value}`);
        TailnetData.refreshShares();
      } },
    { what: "shares listed", ready: () => TailnetData.shares.length === 2,
      act: () => {
        const s = TailnetData.shares;
        if (s[0].url !== "https://pc.tail0.ts.net" || !s[0].funnel) root.fail(`funnel share: ${JSON.stringify(s[0])}`);
        if (s[1].url !== "http://pc.tail0.ts.net:8080" || s[1].funnel) root.fail(`tailnet share: ${JSON.stringify(s[1])}`);
      } },
    { what: "actions run", ready: () => calls.text().trim() === "set --exit-node=\ndown",
      act: () => {} },
    { what: "send files", ready: () => true,
      act: () => TailnetData.send(TailnetData.peers.find(p => p.host === "pc-1"), ["/tmp/x.txt"]) },
    { what: "files sent", ready: () => TailnetData.notice === "Sent" && calls.text().includes("file cp /tmp/x.txt 100.64.0.4:"),
      act: () => {
        TailnetData.share(3000);
        TailnetData.unshare({ port: 3000, scheme: "http", funnel: false });
        TailnetData.unshare({ port: 443, scheme: "https", funnel: true });
      } },
    { what: "share calls", ready: () => calls.text().includes("funnel --https=443 off"),
      act: () => {
        const t = calls.text();
        if (!t.includes("serve --bg --http=3000 3000") || !t.includes("serve --http=3000 off")) root.fail(`share calls: ${t}`);
        TailnetData.receive();
      } },
    { what: "receive", ready: () => TailnetData.notice === "moved 2/2 files",
      act: () => {
        GlobalState.closeAll();
        if (GlobalState.tailnetOpen) root.fail("closeAll left it open");
        console.log("PASS");
        Qt.exit(0);
      } }
  ]

  FloatingWindow {
    implicitWidth: 1200
    implicitHeight: 720
    color: "black"

    TailnetPanel {
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
