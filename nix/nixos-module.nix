{ ... }: {
  # System services a home-manager module cannot enable.
  flake.nixosModules.default = { config, pkgs, lib, ... }:
  let
    cfg = config.programs.nyx;
  in {
    options.programs.nyx.calendar.enable = lib.mkEnableOption ''
      Evolution Data Server for the calendar panel. Accounts (Google etc.) are
      added from the calendar panel (Google through Evolution's sign-in, CalDAV by address)
    '';

    config = lib.mkIf cfg.calendar.enable {
      services.gnome.evolution-data-server.enable = true;
      # Account setup (OAuth) UI.
      programs.evolution.enable = true;
      environment.systemPackages = [ pkgs.gnome-calendar ];
    };
  };
}
