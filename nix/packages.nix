{ inputs, ... }: {
  perSystem = { pkgs, lib, system, ... }:
  let
    gslapper = import ./_helpers/gslapper.nix {
      inherit pkgs lib;
      gslapper = inputs.gslapper.packages.${system}.gslapper;
    };

    # Defaults for the unconfigured build; hosts use homeModules.default.
    theming = import ./_theme {
      inherit pkgs lib;
      hyprland = pkgs.hyprland;
      targets = import ./_theme/targets.nix { configHome = "~/.config"; stateHome = "~/.local/state"; };
      defaultTheme = { source = "scheme"; scheme = "gruvbox-dark-medium"; accent = "base0D"; mode = "dark"; wallpaper = ""; };
      matugenType = "scheme-tonal-spot";
    };

    helpers = import ./_helpers {
      inherit pkgs lib gslapper;
      inherit (theming) theme;
      hyprland = pkgs.hyprland;
      lockCommand = "loginctl lock-session";
      wallpaperDir = "/var/empty";
      defaultWallpaper = "";
      screenshotDir = "/tmp";
      clipboardMaxItems = 500;
    };
  in {
    _module.args.nyx = { inherit theming helpers; };

    packages = {
      default = import ./_package {
        inherit pkgs lib helpers;
        hyprland = pkgs.hyprland;
        outputs = { primary = ""; left = ""; right = ""; };
        terminal = "kitty";
        iconTheme = "Papirus-Dark";
      };
      theme = theming.theme;
    };

    # `qs -p shell` hot-reloads; the checked-in Host.qml resolves helpers from PATH.
    devShells.default = pkgs.mkShell {
      packages = helpers.all ++ [ theming.theme ] ++ (with pkgs; [ quickshell cliphist wl-clipboard matugen jq cava btop brightnessctl ]);
      QT_QPA_PLATFORMTHEME = "qt6ct";
    };
  };
}
