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
- `nix/` flake-parts modules: package, home-manager and NixOS modules, checks
