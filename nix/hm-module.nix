{ inputs, ... }: {
  flake.homeModules.default = { config, pkgs, lib, ... }:
  let
    cfg = config.programs.nyx;
    inherit (lib) mkOption types;
    keybinds = import ./_keybinds { inherit lib; };

    gslapper = import ./_helpers/gslapper.nix {
      inherit pkgs lib;
      gslapper = inputs.gslapper.packages.${pkgs.stdenv.hostPlatform.system}.gslapper;
    };

    theming = import ./_theme {
      inherit pkgs lib;
      hyprland = cfg.hyprlandPackage;
      inherit (cfg.theme) targets matugenType;
      defaultTheme = {
        inherit (cfg.theme) source scheme accent mode;
        wallpaper = "";
      };
    };

    helpers = import ./_helpers {
      inherit pkgs lib gslapper;
      inherit (cfg) lockCommand;
      inherit (theming) theme;
      hyprland = cfg.hyprlandPackage;
      wallpaperDir = cfg.wallpaper.directory;
      defaultWallpaper = cfg.wallpaper.default;
      screenshotDir = cfg.screenshotDirectory;
      clipboardMaxItems = cfg.clipboard.maxItems;
      emojiType = cfg.emoji.type;
      bitwardenClear = cfg.bitwarden.clearAfter;
    };

    shell = import ./_package {
      inherit pkgs lib helpers;
      inherit (theming) theme;
      inherit (cfg) outputs terminal;
      iconTheme = cfg.iconTheme.name;
      hyprland = cfg.hyprlandPackage;
    };

    role = description: mkOption {
      type = types.str;
      default = "";
      inherit description;
    };

    target = types.submodule {
      options = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Whether to render this target.";
        };
        input = mkOption {
          type = types.path;
          description = "matugen template.";
        };
        output = mkOption {
          type = types.str;
          description = "Where the rendered file is written.";
        };
        hook = mkOption {
          type = types.nullOr types.str;
          default = null;
          description = "Arguments to nyx-theme-hook after rendering.";
        };
      };
    };

    builtinTargets = import ./_theme/targets.nix {
      configHome = config.xdg.configHome;
      stateHome = config.xdg.stateHome;
    };
  in {
    options.programs.nyx = {
      enable = lib.mkEnableOption "the nyx Quickshell desktop shell";

      package = mkOption {
        type = types.package;
        readOnly = true;
        default = shell;
        description = "The configured `nyx-shell` launcher.";
      };

      hyprlandPackage = mkOption {
        type = types.package;
        default = pkgs.hyprland;
        description = "Hyprland providing hyprctl; should match the running compositor.";
      };

      outputs = {
        primary = role "Output for notification toasts. Empty follows the focused output.";
        left = role "Output in the left role, if any.";
        right = role "Output in the right role, if any.";
      };

      iconTheme = {
        name = mkOption {
          type = types.str;
          default = "Papirus-Dark";
          description = "Icon theme for app, tray and launcher icons.";
        };
        package = mkOption {
          type = types.package;
          default = pkgs.papirus-icon-theme;
          description = "Package providing `iconTheme.name`.";
        };
      };

      terminal = mkOption {
        type = types.str;
        default = "kitty";
        description = "Terminal for run-in-terminal launcher entries.";
      };

      lockCommand = mkOption {
        type = types.str;
        default = "loginctl lock-session";
        description = "Command run by the power menu's Lock entry.";
      };

      screenshotDirectory = mkOption {
        type = types.str;
        default = "${config.home.homeDirectory}/Pictures";
        description = "Where screenshots are saved.";
      };

      wallpaper = {
        directory = mkOption {
          type = types.str;
          description = "Root of the wallpaper picker; stills and videos.";
        };
        default = mkOption {
          type = types.str;
          default = "";
          description = "Wallpaper, relative to `directory`, for outputs without a saved choice.";
        };
      };

      clipboard.maxItems = mkOption {
        type = types.ints.positive;
        default = 500;
        description = "History entries kept; pins do not count.";
      };

      emoji.type = mkOption {
        type = types.bool;
        default = false;
        description = "Also type the picked emoji into the focused window, besides copying it.";
      };

      bitwarden.clearAfter = mkOption {
        type = types.ints.unsigned;
        default = 30;
        description = "Seconds before a copied secret is cleared from the clipboard; 0 keeps it.";
      };

      keybinds = {
        enable = mkOption {
          type = types.bool;
          default = true;
          description = "Bind nyx's shortcuts in Hyprland and list them in the system panel.";
        };
        modifier = mkOption {
          type = types.str;
          default = "SUPER";
          description = "What MOD stands for in `keybinds.binds`.";
        };
        binds = mkOption {
          default = keybinds.defaults;
          description = ''
            Binds in order. Each sets `shortcut` (a global shortcut the shell
            registers) or `command` (run with `exec_cmd`), the `keys` as Hyprland
            writes them with MOD for the modifier, and a `label` for the panel.
          '';
          type = types.listOf (types.submodule {
            options = {
              keys = mkOption { type = types.str; };
              label = mkOption { type = types.str; };
              shortcut = mkOption { type = types.nullOr types.str; default = null; };
              command = mkOption { type = types.nullOr types.str; default = null; };
              release = mkOption { type = types.bool; default = false; };
              nonConsuming = mkOption { type = types.bool; default = false; };
              locked = mkOption { type = types.bool; default = false; };
              repeating = mkOption { type = types.bool; default = false; };
              hidden = mkOption { type = types.bool; default = false; description = "Bound, but not listed."; };
            };
          });
        };
      };

      theme = {
        source = mkOption {
          type = types.enum [ "scheme" "wallpaper" ];
          default = "scheme";
          description = ''
            Initial theme source. Later choices made with `nyx-theme` persist in
            $XDG_STATE_HOME/nyx/theme.json and take precedence.
          '';
        };
        scheme = mkOption {
          type = types.str;
          default = "gruvbox-dark-medium";
          description = "base16 scheme name; `nyx-theme schemes` lists them.";
        };
        accent = mkOption {
          type = types.enum (map (n: "base0${n}") [ "8" "9" "A" "B" "C" "D" "E" "F" ]);
          default = "base0D";
          description = "base16 slot used as the primary colour of a scheme.";
        };
        mode = mkOption {
          type = types.enum [ "dark" "light" ];
          default = "dark";
          description = "Mode for wallpaper-generated themes.";
        };
        matugenType = mkOption {
          type = types.str;
          default = "scheme-tonal-spot";
          description = "matugen scheme type for wallpaper-generated themes.";
        };
        targets = mkOption {
          type = types.attrsOf target;
          default = { };
          description = "Templates to render. Built-ins can be disabled or overridden; new ones added.";
        };
      };
    };

    config = lib.mkIf cfg.enable {
      programs.nyx.theme.targets = lib.mapAttrs (_: lib.mapAttrs (_: lib.mkDefault)) builtinTargets;

      home.packages = [ shell gslapper theming.theme cfg.iconTheme.package ] ++ helpers.all;

      home.activation.nyxTheme = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        run ${lib.getExe theming.theme} apply || echo "nyx: theme apply failed" >&2
      '';

      wayland.windowManager.hyprland.extraConfig = lib.mkIf cfg.keybinds.enable
        (lib.mkAfter (keybinds.lua { inherit (cfg.keybinds) modifier binds; }));
      xdg.configFile."nyx/keybinds.json" = lib.mkIf cfg.keybinds.enable {
        text = keybinds.json { inherit (cfg.keybinds) modifier binds; };
      };

      programs.kitty.extraConfig = lib.mkIf cfg.theme.targets.kitty.enable (lib.mkAfter "include themes/nyx.conf");
      gtk.gtk3.extraCss = lib.mkIf cfg.theme.targets.gtk3.enable ''@import url("nyx.css");'';
      gtk.gtk4.extraCss = lib.mkIf cfg.theme.targets.gtk4.enable ''@import url("nyx.css");'';

      assertions = [{
        assertion = !config.services.cliphist.enable;
        message = "programs.nyx records clipboard history itself; disable services.cliphist.";
      }];

      # Same watchers as services.cliphist, storing through nyx-clipboard so
      # entries get arrival times.
      systemd.user.services = lib.genAttrs [ "nyx-clipboard" "nyx-clipboard-images" ] (name: {
        Unit = {
          Description = "nyx clipboard history (${name})";
          PartOf = [ config.wayland.systemd.target ];
          After = [ config.wayland.systemd.target ];
        };
        Service = {
          ExecStart = lib.concatStringsSep " " ([ "${pkgs.wl-clipboard}/bin/wl-paste" ]
            ++ lib.optionals (name == "nyx-clipboard-images") [ "--type" "image" ]
            ++ [ "--watch" (lib.getExe helpers.clipboard) "store" ]);
          Restart = "on-failure";
        };
        Install.WantedBy = [ config.wayland.systemd.target ];
      });

      # Raw ascii output parsed by services/AudioData.qml.
      xdg.configFile."cava/nyx.ini".text = ''
        [general]
        bars = 48
        # The range music fills; the default spreads bars to 20 kHz.
        lower_cutoff_freq = 50
        higher_cutoff_freq = 12000

        [output]
        method = raw
        channels = mono
        data_format = ascii
        ascii_max_range = 100
      '';
    };
  };
}
