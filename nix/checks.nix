{ inputs, ... }: {
  perSystem = { pkgs, lib, system, config, ... }:
  let
    helpers = import ./_helpers {
      inherit pkgs lib;
      gslapper = inputs.gslapper.packages.${system}.gslapper;
      hyprland = pkgs.hyprland;
      lockCommand = "true";
      wallpaperDir = "${wallpapers}";
      defaultWallpaper = "";
      screenshotDir = "/tmp";
    };

    wallpapers = pkgs.runCommand "nyx-test-wallpapers" { } ''
      mkdir -p $out/a $out/b
      touch $out/a/still.png $out/b/clip.mp4 $out/b/notes.txt
    '';
  in {
    checks = {
      shell = config.packages.default;
      helpers = pkgs.runCommand "nyx-helpers-test" { nativeBuildInputs = helpers.all; NYX_WALLPAPER_DIR = "${wallpapers}"; } ''
        bash ${./_helpers/test.sh}
        touch $out
      '';
    };
  };
}
