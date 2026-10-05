// Bitwarden vault: entries on the left, what is in the selection on the right.
// Entries that look like the window you came from are listed first.
//
// Keys: Enter copies the password (or the note), Ctrl+U the username, Ctrl+T the
// TOTP code; add Shift to type into the window you came from instead.

pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.components
import qs.config
import qs.services

SplitPanel {
  id: root
  required property string monitorId

  readonly property bool unlocked: VaultData.state === "unlocked"
  readonly property bool isLogin: root.current?.type === "Login"
  // What copying "the" secret means: the password, or the note for a note.
  readonly property string mainField: root.isLogin ? "password" : "notes"

  active: GlobalState.bitwardenOpen && GlobalState.bitwardenMonitorId === root.monitorId
  title: "Bitwarden"
  placeholder: "Filter vault…"
  emptyText: {
    switch (VaultData.state) {
    case "": return "Reading the vault…";
    case "locked": return "The vault is locked. Press Enter to unlock.";
    case "unlocked": return "The vault is empty";
    default: return "Not logged in. Press Enter to log in.";
    }
  }
  entries: root.unlocked ? VaultData.filter(root.query) : []
  detailTitle: root.current?.name ?? ""
  detailSubtitle: root.current ? [root.current.user, root.current.folder].filter(Boolean).join("  •  ") : ""

  rowGlyph: e => e.type === "Login" ? "\u{F0306}" : "\u{F0219}"
  rowGlyphColor: e => VaultData.suggested(e) ? Style.colors.green : Style.colors.brightBlack
  rowTitle: e => e.name
  rowSubtitle: e => [VaultData.suggested(e) && !root.query ? "Suggested" : "", e.user, root.host(e.uri)].filter(Boolean).join("  •  ")

  onActiveChanged: if (root.active) VaultData.refresh()
  onCloseRequested: GlobalState.closeBitwarden()
  onAccepted: root.use(root.mainField, false)

  onKeyPressed: event => {
    const ctrl = event.modifiers & Qt.ControlModifier;
    const shift = event.modifiers & Qt.ShiftModifier;
    const enter = event.key === Qt.Key_Return || event.key === Qt.Key_Enter;
    if (!root.unlocked && enter) root.setup();
    else if (root.unlocked && enter && shift) root.use(root.mainField, true);
    else if (ctrl && event.key === Qt.Key_U) root.use("username", shift);
    else if (ctrl && event.key === Qt.Key_T) root.use("totp", shift);
    else return;
    event.accepted = true;
  }

  function host(uri) {
    return (uri || "").replace(/^[a-z]+:\/\//i, "").split(/[\/?#]/)[0].replace(/^www\./i, "");
  }

  // Copies, or types into the window the panel was opened over. Typing closes
  // the panel first so focus is back where the text should go.
  function use(field, type) {
    if (!root.current) return;
    if (type) {
      const entry = root.current;
      GlobalState.closeBitwarden();
      VaultData.type(entry, field);
    } else {
      VaultData.copy(root.current, field);
      GlobalState.closeBitwarden();
    }
  }

  // Unlocks a locked vault; one that is not logged in goes to the launcher's form.
  function setup() {
    if (VaultData.state === "locked") {
      VaultData.unlock();
    } else if (VaultData.needsSetup) {
      GlobalState.openLauncher({ id: root.monitorId, mode: "bitwarden" });
    }
  }

  headerActions: [
    IconButton {
      visible: root.unlocked
      glyph: "\u{F0450}"
      label: "Sync"
      onActivated: VaultData.sync()
    },
    IconButton {
      visible: root.unlocked
      glyph: "\u{F033E}"
      label: "Lock"
      onActivated: VaultData.lock()
    },
    IconButton {
      visible: VaultData.state !== "" && !root.unlocked
      glyph: "\u{F0306}"
      label: VaultData.state === "locked" ? "Unlock" : "Log in"
      onActivated: root.setup()
    }
  ]

  actions: [
    IconButton {
      visible: root.current !== null
      glyph: "\u{F018F}"
      label: root.isLogin ? "Pass" : "Note"
      onActivated: root.use(root.mainField, false)
    },
    IconButton {
      visible: root.isLogin
      glyph: "\u{F0004}"
      label: "User"
      onActivated: root.use("username", false)
    },
    IconButton {
      visible: root.isLogin
      glyph: "\u{F0150}"
      label: "TOTP"
      onActivated: root.use("totp", false)
    },
    IconButton {
      visible: root.isLogin
      glyph: "\u{F030C}"
      label: "Type pass"
      onActivated: root.use("password", true)
    },
    IconButton {
      visible: root.isLogin
      glyph: "\u{F030C}"
      label: "Type user"
      onActivated: root.use("username", true)
    }
  ]

  ColumnLayout {
    anchors.fill: parent
    spacing: Style.spacing.p3
    visible: root.current !== null

    FieldList {
      Layout.fillWidth: true
      fields: {
        const e = root.current;
        if (!e) return [];
        return [
          { label: "Type", value: e.type },
          { label: "User", value: e.user || "—", copy: e.user || "" },
          { label: "Site", value: e.uri || "—", copy: e.uri || "" },
          { label: "Folder", value: e.folder || "—" }
        ];
      }
      onCopied: text => Quickshell.clipboardText = text
    }

    Item { Layout.fillHeight: true }

    Text {
      Layout.fillWidth: true
      text: root.isLogin
        ? "Enter copies the password · Ctrl+U username · Ctrl+T TOTP\nAdd Shift to type it into the window you came from"
        : "Enter copies the note"
      wrapMode: Text.Wrap
      color: Style.colors.brightBlack
      font.family: Style.font.main
      font.pointSize: Style.font.small
    }
  }
}
