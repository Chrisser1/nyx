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
      # GLib finds no time zone on NixOS without TZDIR, and GNOME Calendar
      # aborts. The shell (and so the launcher) doesn't reliably inherit it from
      # the session, so the binary sets it itself: the desktop entry's plain
      # `gnome-calendar` then works from the launcher, not just `nyx-calendar open`.
      environment.systemPackages = [
        (lib.hiPrio (pkgs.symlinkJoin {
          name = "gnome-calendar-tzdir";
          paths = [ pkgs.gnome-calendar ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/gnome-calendar --set-default TZDIR /etc/zoneinfo
          '';
        }))
      ];
    };
  };
}
