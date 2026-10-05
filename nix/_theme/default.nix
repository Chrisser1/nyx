# matugen config plus the nyx-theme commands that render it.
{ pkgs, lib, hyprland, targets, defaultTheme, matugenType }:
let
  script = import ../_helpers/script.nix { inherit pkgs; };

  hook = script "theme-hook" (with pkgs; [ procps dconf gnused gnugrep hyprland coreutils ]) { };

  schemes = "${pkgs.base16-schemes}/share/themes";

  # id, name, variant and base00..base0F of every scheme, for the theme picker.
  schemesIndex = pkgs.runCommand "nyx-schemes.json" { nativeBuildInputs = [ pkgs.yq-go pkgs.jq ]; } ''
    for f in ${schemes}/*.yaml; do
      yq -o json "$f" | jq -c --arg id "$(basename "$f" .yaml)" '{
        id: $id,
        name: (.name // $id),
        variant: (.variant // "dark"),
        colors: [.palette | to_entries | sort_by(.key)[] | select(.key | test("^base0[0-9A-F]$")) | .value]
      }'
    done | jq -s 'sort_by(.id)' > $out
  '';

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
    NYX_SCHEMES_DIR = schemes;
    NYX_SCHEMES_INDEX = "${schemesIndex}";
    NYX_BASE16_JQ = "${../../theme/base16.jq}";
    NYX_DEFAULT_THEME = "${pkgs.writeText "nyx-default-theme.json" (builtins.toJSON defaultTheme)}";
  };
}
