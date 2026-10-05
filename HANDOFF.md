# nyx: session handoff (2026-10-05)

Paste this into Claude Code on the other machine as the opening prompt, or say "read ~/repos/nyx/HANDOFF.md and continue".

## Context

nyx (`~/repos/nyx`, GPLv3) is my own Quickshell 0.3.1 shell. It replaces noctalia and started as a copy of erebus' QML.

- **Consumed by** `~/nixos` as flake input `nyx = "git+file:///home/chris/repos/nyx"`. The repo must sit at that exact path.
- **Wiring:** `modules/features/desktop/nyx.nix` (homeModules.nyx and nixosModules.nyx). Both profiles use nyx. noctalia (`modules/features/desktop/noctalia/`, the flake input and its config) is kept but not imported: to re-enable it, add `self.nixosModules.noctalia` to `modules/hosts/shared.nix` and swap `homeModules.nyx` for `noctalia-desktop` in `profiles.nix`.
- **Rebuild:** `nh os switch ~/nixos -- --impure`. It needs sudo, so I run it myself. `--impure` is needed because of `secrets.nix`.
- **Phases 1–5 are done:**
  - scaffold, wiring;
  - matugen theming (`nyx-theme`);
  - clipboard panel;
  - ports: emoji, Alt+Tab, Docker, Tailnet, Bitwarden.
- **Last commits:** nyx `b2afeed`, nixos `80bbbf5`. `nix flake check` passes in nyx.

## Rules

- **Commits:** never add Claude as co-author. Commit only when I ask.
- **Code:** everything is tested and has a clean architecture. Comments are short and only where needed.
- **Workflow:** terse replies. Propose a plan (files and changes) before editing. Call out tradeoffs.
- **Docs:** check current docs before using Hyprland, NixOS or HM options. Hyprland 0.56 uses the Lua config (`hl.bind`, `hl.dsp.*`).
- **Nix style:**
  - `{ pkgs, lib, ... }:` with spaces, on one line;
  - `let` on its own line after `=`;
  - no formatter, format by hand.

## Architecture

| Area | Location |
|---|---|
| Shell entry, global shortcuts (`appid "nyx"`, bound via `hl.dsp.global("nyx:<name>")`) | `shell/shell.qml` |
| Overlay state; `modalOn`, `overlayOn` | `shell/GlobalState.qml` |
| Services (singletons) | `shell/services/` (`LauncherData`, `ClipboardData`, `DockerData`, `TailnetData`, `WindowSwitcher`, …) |
| Shared components | `shell/components/SplitPanel.qml` (list + detail overlay), `FieldList.qml` |
| Serial command runner | `shell/utils/CommandQueue.qml` |
| Launcher and its modes | `shell/modules/launcher/` |
| Bash helpers (`nyx-<name>`) | `scripts/nyx-*.sh`, wrapped in `nix/_helpers/default.nix` |
| Helper paths for the shell | `shell/config/Host.qml`, generated in `nix/_package/default.nix` |
| Checks | `nix/checks.nix` |
| HM options (`programs.nyx.*`) | `nix/hm-module*` |

The launcher modes are apps, power, wallpaper, theme, display, emoji and bitwarden.

**Tests:**
- QML tests are headless: `tests/<name>/shell.qml` runs under quickshell with `QT_QPA_PLATFORM=offscreen`, using step and settle timers and a FloatingWindow. `grabToImage` with `$OUT` saves screenshots.
- CLI wrappers are tested by rebuilding the same script against fakes in `nix/_helpers/stubs/` (`stub` and `stubbed` in `checks.nix`).

**Gotchas:**
- QV4 has no `Array.at`.
- ScriptModel reuses delegates, so look up live values reactively. Don't store them in entries.
- To restart nyx live, don't run `pkill -f nyx-shell-src`. Find the PID with `pgrep -x '.quickshell-wra'` and check its `/proc/<pid>/cmdline`, then run `hyprctl dispatch 'hl.dsp.exec_cmd("nyx-shell -d")'`.

## Open issues (my feedback after rebuilding)

Investigate each, propose a plan, then fix and test.

### 1. Wallpaper previews don't match the on-screen fit

The screen shows the wallpaper fitted to width, but the previews look different.

- **Thumbnails:** `nyx-wallpaper thumbs` caches `$XDG_CACHE_HOME/nyx/wallpapers/<sha1(abs@h480)>.jpg` via ffmpeg `scale=-2:480`.
- **Card:** `LauncherItem.qml` shows them with `Image { fillMode: PreserveAspectCrop }` in the card.
- **Setting the wallpaper:** gslapper does this in `scripts/nyx-wallpaper.sh` (`set-all`).

To do:
- Check gslapper's fit mode.
- Make the preview use the same fit and the monitor's aspect ratio, for example a card preview area at 16:9 using the same fill or fit.

### 2. Emoji search is slow; it should be instant

- **Data:** 1,919 entries. `LauncherData.emojiData = emojiEntries.map(a => ({ name: Fuzzy.prepare(a.search), entry: a }))`.
- **Search:** `Fuzzy.query(q, emojiData)` runs on every keystroke against long name+keyword strings.
- **Delegates:** heavy `LauncherItem` cards, each with a MultiEffect shadow.

Ideas:
- precomputed lowercase prefix or substring matching on the name first, then keywords;
- cap the results;
- a lighter emoji delegate with no shadow;
- avoid re-mapping the data.

Measure before and after.

### 3. Bitwarden login looks bad, and I still need to log in

**Setup:**
- HM sets `programs.rbw` with `email = "chrisgthomsen0310@gmail.com"` and `pinentry = pkgs.pinentry-qt`.
- `scripts/nyx-bitwarden.sh` `list` returns a state of `unconfigured`, `locked` or `unlocked`. Locked shows an "Unlock vault" card, which runs `nyx-bitwarden unlock` through pinentry. Unconfigured shows a "Set up rbw" card, which runs `rbw login` in the terminal.

**Problems:**
- There is no "configured but not logged in" state. The email is set by HM, so it reports `locked` even before `rbw login`.
- The pinentry-qt dialog and/or the cards look bad.

To do:
- Add a proper `login` state and flow. Check `rbw` 1.15 behaviour first (is there a `rbw unlocked` or device-registration check?).
- Make pinentry match the theme (qt6ct palette, or a different pinentry).
- Have me run `! rbw login` to get logged in.

## Later

**Phase 6:**
- Polish the bar layout.
- noctalia is no longer imported but is kept on purpose; do not delete it.

**Theme templates still to add:** vscode, vesktop, obsidian, steam, rofi.

**Still needs live verification:**
- Alt-release commits in the switcher (via the `ALT + ALT_L` release bind and `Keys.onReleased`).
- `tailscale up`/`down` without sudo now that `--operator=chris` is set.
