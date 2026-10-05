# Converts a tinted-theming base16 scheme (as JSON) into matugen render data.
# Usage: jq --arg accent base0D -f base16.jq scheme.json

def channel: ascii_downcase | explode | map(if . >= 97 then . - 87 else . - 48 end) | .[0] * 16 + .[1];
def rgb: ltrimstr("#") | [.[0:2], .[2:4], .[4:6]] | map(channel);
def byte: (if . < 0 then 0 elif . > 255 then 255 else . end) | round | [(. / 16 | floor), (. % 16)]
  | map(if . < 10 then . + 48 else . + 87 end) | implode;
# mix(a; b; t): t = 0 gives a, t = 1 gives b.
def mix(a; b; t): [(a | rgb), (b | rgb)] | transpose | map(.[0] + (.[1] - .[0]) * t | byte) | "#" + join("");
def entry: { color: . } as $c | { default: $c, dark: $c, light: $c };

.palette as $p
| ((.variant // "dark") == "dark") as $dark
| (if $dark then "#000000" else "#ffffff" end) as $shade
| ($p[$accent] // error("unknown accent \($accent)")) as $primary
| {
    primary: $primary,
    on_primary: $p.base00,
    primary_container: mix($p.base01; $primary; 0.3),
    on_primary_container: $primary,
    secondary: $p.base0C,
    on_secondary: $p.base00,
    secondary_container: mix($p.base01; $p.base0C; 0.3),
    on_secondary_container: $p.base0C,
    tertiary: $p.base0E,
    on_tertiary: $p.base00,
    tertiary_container: mix($p.base01; $p.base0E; 0.3),
    on_tertiary_container: $p.base0E,
    error: $p.base08,
    on_error: $p.base00,
    error_container: mix($p.base01; $p.base08; 0.3),
    on_error_container: $p.base08,
    background: $p.base00,
    on_background: $p.base05,
    surface: $p.base00,
    on_surface: $p.base05,
    surface_variant: $p.base02,
    on_surface_variant: $p.base04,
    surface_dim: mix($p.base00; $shade; 0.3),
    surface_bright: $p.base02,
    surface_container_lowest: mix($p.base00; $shade; 0.3),
    surface_container_low: mix($p.base00; $p.base01; 0.35),
    surface_container: mix($p.base00; $p.base01; 0.7),
    surface_container_high: $p.base01,
    surface_container_highest: $p.base02,
    surface_tint: $primary,
    outline: $p.base03,
    outline_variant: $p.base02,
    shadow: "#000000",
    scrim: "#000000",
    inverse_surface: $p.base05,
    inverse_on_surface: $p.base00,
    inverse_primary: $primary,
    source_color: $primary
  } as $colors
| {
    mode: (if $dark then "dark" else "light" end),
    is_dark_mode: $dark,
    scheme: .name,
    colors: ($colors | map_values(entry)),
    base16: ($p | with_entries(select(.key | test("^base0[0-9A-F]$")) | .key |= ascii_downcase) | map_values(entry))
  }
