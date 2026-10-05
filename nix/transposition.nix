{ lib, ... }: {
  # flake-parts has no homeModules output of its own.
  options.flake.homeModules = lib.mkOption {
    type = lib.types.attrsOf lib.types.unspecified;
    default = {};
  };
}
