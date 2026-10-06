# nyx: session handoff (2026-10-05)

## Context

nyx (`~/repos/nyx`, GPLv3) is my own Quickshell 0.3.1 shell. It replaces noctalia.

- **Consumed by** `~/nixos` as flake input `nyx = "git+ssh://git@github.com/Chrisser1/nyx"`. To test local edits before pushing, rebuild with `--override-input nyx path:/home/chris/repos/nyx`.
- **Wiring:** `modules/features/desktop/nyx.nix` (homeModules.nyx and nixosModules.nyx). Both profiles use nyx. noctalia (`modules/features/desktop/noctalia/`, the flake input and its config) is kept but not imported: to re-enable it, add `self.nixosModules.noctalia` to `modules/hosts/shared.nix` and swap `homeModules.nyx` for `noctalia-desktop` in `profiles.nix`.
- **Rebuild:** `nh os switch ~/nixos -- --impure`. It needs sudo, so I run it myself. `--impure` is needed because of `secrets. nix`. I just run the `rebuild` command, as that is the same.
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

## Open

- Notifications stay too long and i cannot remove all notifications at once.
- When booting in and starting my headset, even though noice cancelling was on and the headset microphone was selected i had to reselect it for it to apply.
- Calender in the bar can have an improved look, see image.
- The colors and visual for computer stats can be improved, especially colors, see second image.

