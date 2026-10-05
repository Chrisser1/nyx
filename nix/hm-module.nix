{ inputs, ... }: {
  flake.homeModules.default = { config, pkgs, lib, ... }:
  let
    cfg = config.programs.nyx;

    gslapper = import ./_helpers/gslapper.nix {
      inherit pkgs lib;
      gslapper = inputs.gslapper.packages.${pkgs.stdenv.hostPlatform.system}.gslapper;
    };

    helpers = import ./_helpers {
      inherit pkgs lib gslapper;
      inherit (cfg) lockCommand;
      hyprland = cfg.hyprlandPackage;
      wallpaperDir = cfg.wallpaper.directory;
      defaultWallpaper = cfg.wallpaper.default;
      screenshotDir = cfg.screenshotDirectory;
    };

    shell = import ./_package {
      inherit pkgs lib helpers;
      inherit (cfg) outputs terminal;
      hyprland = cfg.hyprlandPackage;
    };

    role = description: lib.mkOption {
      type = lib.types.str;
      default = "";
      inherit description;
    };
  in {
    options.programs.nyx = {
      enable = lib.mkEnableOption "the nyx Quickshell desktop shell";

      package = lib.mkOption {
        type = lib.types.package;
        readOnly = true;
        default = shell;
        description = "The configured `nyx-shell` launcher.";
      };

      hyprlandPackage = lib.mkOption {
        type = lib.types.package;
        default = pkgs.hyprland;
        description = "Hyprland providing hyprctl; should match the running compositor.";
      };

      outputs = {
        primary = role "Output for notification toasts. Empty follows the focused output.";
        left = role "Output in the left role, if any.";
        right = role "Output in the right role, if any.";
      };

      terminal = lib.mkOption {
        type = lib.types.str;
        default = "kitty";
        description = "Terminal for run-in-terminal launcher entries.";
      };

      lockCommand = lib.mkOption {
        type = lib.types.str;
        default = "loginctl lock-session";
        description = "Command run by the power menu's Lock entry.";
      };

      screenshotDirectory = lib.mkOption {
        type = lib.types.str;
        default = "${config.home.homeDirectory}/Pictures";
        description = "Where screenshots are saved.";
      };

      wallpaper = {
        directory = lib.mkOption {
          type = lib.types.str;
          description = "Root of the wallpaper picker; stills and videos.";
        };
        default = lib.mkOption {
          type = lib.types.str;
          default = "";
          description = "Wallpaper, relative to `directory`, for outputs without a saved choice.";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      home.packages = [ shell gslapper ] ++ helpers.all;

      services.cliphist = {
        enable = lib.mkDefault true;
        allowImages = lib.mkDefault true;
      };

      # Raw ascii output parsed by services/AudioData.qml.
      xdg.configFile."cava/nyx.ini".text = ''
        [general]
        bars = 48

        [output]
        method = raw
        channels = mono
        data_format = ascii
        ascii_max_range = 100
      '';
    };
  };
}
