# Test that the minimal/container.nix profile evaluates and builds
# a system toplevel via lib.nixos.evalModules.
#
# This is a build-time test (instantiation + build), not a runtime test.
# For a runtime test, use `nixos/tests/minimal-container-runtime.nix`
# which boots the toplevel in systemd-nspawn.
#
# Usage:
#   nix-build nixos/tests/minimal-container.nix
{
  pkgs ? import ../.. { },
}:
let
  nixosLib = import (pkgs.path + "/nixos/lib/default.nix") {
    featureFlags.minimalModules = { };
  };

  nixos = nixosLib.evalModules {
    modules = [
      ../modules/profiles/minimal/container.nix
      {
        nixpkgs.pkgs = pkgs;
        system.stateVersion = "26.05";
      }
    ];
  };
in
{
  inherit (nixos.config.system.build) toplevel;
}
