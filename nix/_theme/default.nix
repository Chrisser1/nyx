# matugen config plus the nyx-theme commands that render it.
{ pkgs, lib, hyprland, targets, defaultTheme, matugenType }:
let
  script = import ../_helpers/script.nix { inherit pkgs; };

  hook = script "theme-hook" (with pkgs; [ procps glib gnused gnugrep hyprland ]) { };

  enabled = lib.filterAttrs (_: t: t.enable or true) targets;

  config = (pkgs.formats.toml { }).generate "nyx-matugen.toml" {
    config = { };
    templates = lib.mapAttrs (_: t: {
      input_path = "${t.input}";
      output_path = t.output;
    } // lib.optionalAttrs ((t.hook or null) != null) {
      post_hook = "${lib.getExe hook} ${t.hook}";
    }) enabled;
  };
in {
  inherit hook config;

  theme = script "theme" (with pkgs; [ matugen yq-go jq ffmpeg-headless findutils gnused coreutils ]) {
    NYX_MATUGEN_CONFIG = "${config}";
    NYX_MATUGEN_TYPE = matugenType;
    NYX_SCHEMES_DIR = "${pkgs.base16-schemes}/share/themes";
    NYX_BASE16_JQ = "${../../theme/base16.jq}";
    NYX_DEFAULT_THEME = "${pkgs.writeText "nyx-default-theme.json" (builtins.toJSON defaultTheme)}";
  };
}
