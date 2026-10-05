# Builds scripts/nyx-<name>.sh into a shellchecked `nyx-<name>`.
{ pkgs }:
name: runtimeInputs: runtimeEnv:
pkgs.writeShellApplication {
  name = "nyx-${name}";
  inherit runtimeInputs runtimeEnv;
  text = builtins.readFile ../../scripts/nyx-${name}.sh;
  # jq programs are single-quoted on purpose.
  excludeShellChecks = [ "SC2016" ];
}
