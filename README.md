# nyx

A Quickshell desktop shell for Hyprland (Lua config), packaged as a flake.

## Use

```nix
inputs.nyx.url = "github:Chrisser1/nyx";

# home-manager
imports = [ inputs.nyx.homeModules.default ];
programs.nyx = {
  enable = true;
  wallpaper.directory = "/path/to/wallpapers";
};

# NixOS (calendar backend)
imports = [ inputs.nyx.nixosModules.default ];
programs.nyx.calendar.enable = true;
```

Start it from Hyprland with `nyx-shell -d`. Panels are bound through global
shortcuts, e.g. `hl.bind("SUPER + R", hl.dsp.global("nyx:toggleLauncher"))`.

## Develop

```sh
nix develop
qs -p shell        # hot-reloads on save
nix flake check    # builds the shell, shellchecks and tests the helpers
```

## Layout

- `shell/` QML (`config/Host.qml` is generated on build)
- `scripts/` helper sources, built by `nix/_helpers`
- `theme/` matugen templates and the base16 converter, driven by `nyx-theme`
- `tests/` headless QML tests
- `nix/` flake-parts modules: package, home-manager and NixOS modules, checks

## Theming

```sh
nyx-theme scheme gruvbox-dark-medium base0B   # any base16 scheme, optional accent slot
nyx-theme wallpaper ~/Pictures/wall.png       # Material You from an image or video
nyx-theme mode light
nyx-theme schemes
```

The choice persists in `$XDG_STATE_HOME/nyx/theme.json`; `programs.nyx.theme`
only sets the initial one. Rendered targets are `programs.nyx.theme.targets`.

## Clipboard

`hl.dsp.global("nyx:toggleClipboard")` opens the history: type to filter,
Up/Down to move, Enter to copy, Shift+Delete to delete, Ctrl+P to pin. Pinned
entries survive wipes and the `programs.nyx.clipboard.maxItems` limit. nyx runs
its own cliphist watchers, so `services.cliphist` must be off.

## Emoji

`nyx:toggleEmoji` searches emoji by name and CLDR keyword; Enter copies, the
drawer holds skin tones. Recently used emoji come first. With
`programs.nyx.emoji.type`, the pick is also typed into the focused window.

## Window switcher

Live previews, most recently focused first. Bind `nyx:windowSwitcher` and
`nyx:windowSwitcherBack` to Alt+Tab and Alt+Shift+Tab, and
`nyx:windowSwitcherCommit` to the Alt release:

```lua
hl.bind("ALT + Tab", hl.dsp.global("nyx:windowSwitcher"))
hl.bind("ALT + SHIFT + Tab", hl.dsp.global("nyx:windowSwitcherBack"))
hl.bind("ALT + ALT_L", hl.dsp.global("nyx:windowSwitcherCommit"), { release = true, non_consuming = true })
```
