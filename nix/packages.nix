{ inputs, ... }: {
  perSystem = { pkgs, lib, system, ... }:
  let
    gslapper = import ./_helpers/gslapper.nix {
      inherit pkgs lib;
      gslapper = inputs.gslapper.packages.${system}.gslapper;
    };

    helpers = import ./_helpers {
      inherit pkgs lib gslapper;
      hyprland = pkgs.hyprland;
      lockCommand = "loginctl lock-session";
      wallpaperDir = "/var/empty";
      defaultWallpaper = "";
      screenshotDir = "/tmp";
    };
  in {
    # Unconfigured build; hosts use homeModules.default.
    packages.default = import ./_package {
      inherit pkgs lib helpers;
      hyprland = pkgs.hyprland;
      outputs = { primary = ""; left = ""; right = ""; };
      terminal = "kitty";
    };

    # `qs -p shell` hot-reloads; the checked-in Host.qml resolves helpers from PATH.
    devShells.default = pkgs.mkShell {
      packages = helpers.all ++ (with pkgs; [ quickshell cliphist wl-clipboard matugen jq cava btop brightnessctl ]);
      QT_QPA_PLATFORMTHEME = "qt6ct";
    };
  };
}
