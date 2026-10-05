# Built-in theme targets: template, output file and reload hook.
{ configHome, stateHome }:
let
  template = name: ../../theme/templates/${name};
in {
  shell = {
    input = template "shell.json";
    output = "${stateHome}/nyx/colors.json";
  };
  kitty = {
    input = template "kitty.conf";
    output = "${configHome}/kitty/themes/nyx.conf";
    hook = "kitty";
  };
  hyprland = {
    input = template "hyprland.lua";
    output = "${configHome}/hypr/nyx-theme.lua";
    hook = "hyprland ${configHome}/hypr/nyx-theme.lua";
  };
  gtk3 = {
    input = template "gtk.css";
    output = "${configHome}/gtk-3.0/nyx.css";
    hook = "gtk {{mode}}";
  };
  gtk4 = {
    input = template "gtk.css";
    output = "${configHome}/gtk-4.0/nyx.css";
  };
  qt5ct = {
    input = template "qtct.conf";
    output = "${configHome}/qt5ct/colors/nyx.conf";
  };
  qt6ct = {
    input = template "qtct.conf";
    output = "${configHome}/qt6ct/colors/nyx.conf";
    hook = "qt";
  };
  btop = {
    input = template "btop.theme";
    output = "${configHome}/btop/themes/nyx.theme";
    hook = "btop";
  };
}
