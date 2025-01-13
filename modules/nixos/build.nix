{
  lib,
  config,
  ...
}:
{
  imports = [
    ./from-qemu-vm.nix
  ];

  options =
    let
      inherit (lib) mkOption types;
    in
    {
      virtualisation.macAddress = mkOption {
        default = null;
        example = "00:11:22:33:44:55";
        type = types.nullOr (types.str);
        description = ''
          MAC address of the virtual machine. Leave empty to generate a random one.
        '';
      };
      virtualisation.ephemeral = mkOption {
        default = true;
        type = types.bool;
        description = ''
          Whether the VM should run without persistent storage, i.e. from tmpfs.
        '';
      };

    };

  config.system.build.vm =
    let
      cfg = config.virtualisation;

      # Instantiate our nixpkgs version once more, this time for darwin.
      # This is needed so that we get binaries for darwin, not linux for
      # all of the dependencies the script below, such as bash # to vfkit.
      pkgsDarwin = import config.nixpkgs.flake.source {
        system = "${config.nixpkgs.hostPlatform.qemuArch}-darwin";
      };

      kernel = "${config.system.build.toplevel}/kernel";
      initrd = "${config.system.build.toplevel}/initrd";
      cmdline = lib.concatStringsSep " " (
        config.boot.kernelParams or [ ] ++ [ "init=${config.system.build.toplevel}/init" ]
      );
      macAddress = lib.optionalString (cfg.macAddress != null)
        ",mac=${cfg.macAddress}";
      rosetta = lib.optionalString cfg.rosetta.enable
        "--device rosetta,mountTag=rosetta";
      disk = lib.optionalString (!cfg.ephemeral)
        "--device \"virtio-blk,path=$PWD/disk.img\"";
      makeDiskImage = lib.optionalString (!cfg.ephemeral)
        "truncate -s ${toString cfg.diskSize}M disk.img";
    in
    pkgsDarwin.writeShellApplication {
      name = "vfkit-vm";
      runtimeInputs = [
        pkgsDarwin.vfkit
      ];
      text = ''
        ${makeDiskImage}
        vfkit \
        --bootloader "linux,kernel=${kernel},initrd=${initrd},cmdline=\"${cmdline}\"" \
          --device "virtio-net,nat${macAddress}" \
          --device virtio-serial,stdio \
          --device virtio-rng \
          ${rosetta} \
          ${disk} \
          --device virtio-fs,sharedDir=/nix/store/,mountTag=nix-store \
          --cpus ${toString cfg.cores} \
          --memory ${toString cfg.memorySize}
      '';
    };
}
