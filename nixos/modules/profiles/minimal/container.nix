/*
  A minimal set of NixOS modules that produces a container payload.

  Sibling to profiles/minimal/bootable.nix for systems that run as
  containers (systemd-nspawn, LXC, OCI base images via dockerTools)
  rather than booting real hardware. No kernel, no initrd, no
  bootloader, no hardware management.

  Usage as an nspawn machine:

      systemd-nspawn -b -D $(nix-build -A config.system.build.toplevel) \
        $(nix-build -A config.system.build.toplevel)/init

  Usage as an OCI layer (via dockerTools):

      pkgs.dockerTools.streamLayeredImage {
        name = "my-nixos";
        contents = [ config.system.build.toplevel ];
        config.Cmd = [ "${config.system.build.toplevel}/init" ];
      }

  Notably absent vs profiles/minimal/bootable.nix: kernel, modprobe,
  stage-1, UKI/bootloader, all initrd modules, udev, filesystems,
  console, getty, networkd, resolved, network-interfaces.

  `boot.isContainer` is declared inline (as a local option) and
  defaulted to `true`, so the profile does not pull in the full
  virtualisation/nixos-containers.nix module (which provides
  host-side container management tooling we do not need for a guest
  payload). Other modules that read `config.boot.isContainer` do so
  defensively via `or false`, thanks to the cross-module guards in
  pr/safe-cross-module-reads.

  See also: nixos/tests/minimal-container.nix
*/
{ lib, modulesPath, ... }:
{

  # Declare boot.isContainer locally so we don't pull in
  # virtualisation/nixos-containers.nix just for this option. Most
  # readers access it via `config.boot.isContainer or false`, which
  # short-circuits when this option isn't declared, but setting it
  # here to `true` lets container-aware modules (stage-2, systemd.nix,
  # filesystems.nix, …) take their container code paths.
  options.boot.isContainer = lib.mkOption {
    type = lib.types.bool;
    default = true;
    description = ''
      Whether this NixOS system is a container payload rather than a
      bootable OS. Defaults to `true` in the minimal container
      profile.
    '';
  };

  # Disable the kernel/initrd config paths in modules that are
  # imported for their option declarations but whose actual config
  # shouldn't run in a container. This mirrors what
  # virtualisation/container-config.nix does for the full NixOS
  # container module (which we don't import here to avoid its other
  # dependencies).
  config = {
    boot.kernel.enable = lib.mkDefault false;
  };

  imports = [
    # Module system plumbing
    (modulesPath + "/misc/nixpkgs.nix")
    (modulesPath + "/misc/assertions.nix")
    (modulesPath + "/misc/lib.nix")
    (modulesPath + "/misc/ids.nix")
    (modulesPath + "/misc/extra-arguments.nix")
    (modulesPath + "/misc/meta.nix")
    (modulesPath + "/misc/version.nix")
    (modulesPath + "/misc/passthru.nix")

    # Activation & toplevel
    (modulesPath + "/system/activation/nixos-init.nix")
    (modulesPath + "/system/activation/pre-switch-check.nix")
    (modulesPath + "/system/activation/top-level.nix")
    (modulesPath + "/system/activation/activation-script.nix")
    (modulesPath + "/system/activation/activatable-system.nix")
    (modulesPath + "/system/activation/bootspec.nix")
    (modulesPath + "/system/activation/specialisation.nix")

    # Stage 1/2 + systemd.
    #
    # stage-1.nix and systemd/initrd.nix are imported even though
    # containers do not boot through them. They declare
    # boot.initrd.* options that many other modules in the profile
    # (tmpfiles, dbus, users-groups, ...) set unconditionally. With
    # boot.isContainer = true, the initrd itself is not built, but
    # the option declarations satisfy _module.check.
    (modulesPath + "/system/boot/kernel.nix")
    (modulesPath + "/system/boot/stage-1.nix")
    (modulesPath + "/system/boot/stage-2.nix")
    (modulesPath + "/system/boot/systemd.nix")
    (modulesPath + "/system/boot/systemd/tmpfiles.nix")
    (modulesPath + "/system/boot/systemd/journald.nix")
    (modulesPath + "/system/boot/systemd/logind.nix")
    (modulesPath + "/system/boot/systemd/user.nix")
    (modulesPath + "/system/boot/systemd/initrd.nix")
    (modulesPath + "/system/boot/systemd/sysusers.nix")

    # /etc, environment, programs
    (modulesPath + "/system/etc/etc-activation.nix")
    (modulesPath + "/config/shells-environment.nix")
    (modulesPath + "/config/system-environment.nix")
    (modulesPath + "/config/system-path.nix")
    (modulesPath + "/config/locale.nix")
    (modulesPath + "/config/i18n.nix")
    (modulesPath + "/config/terminfo.nix")
    (modulesPath + "/config/sysctl.nix")
    (modulesPath + "/config/nsswitch.nix")
    (modulesPath + "/programs/environment.nix")
    (modulesPath + "/programs/bash/bash.nix")
    (modulesPath + "/programs/shadow.nix")

    # Users & security
    (modulesPath + "/config/users-groups.nix")
    (modulesPath + "/security/pam.nix")
    (modulesPath + "/security/wrappers/default.nix")

    # Services
    (modulesPath + "/services/system/userborn.nix")
    (modulesPath + "/services/system/nscd.nix")

    # filesystems.nix declares system.build.earlyMountScript (read by
    # activation-script and stage-2) and the fileSystems option itself,
    # used to generate /etc/fstab. In containers fileSystems is typically
    # empty — the host handles mounts — but the declarations are still
    # needed.
    (modulesPath + "/tasks/filesystems.nix")

    # systemd.nix. It does NOT pull in network-interfaces.nix, so we
    # keep the profile light.
  ];
}
