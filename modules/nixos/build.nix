{
  lib,
  config,
  ...
}:
{
  imports = [
    ./from-qemu-vm.nix
  ];

  system.build.vm =
    let
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

      rosetta = lib.optionalString config.virtualisation.rosetta.enable "--device rosetta,mountTag=rosetta";

    in
    pkgsDarwin.writeShellApplication {
      name = "vfkit-vm";
      runtimeInputs = [
        pkgsDarwin.vfkit
      ];
      text = ''
        vfkit \
        --bootloader "linux,kernel=${kernel},initrd=${initrd},cmdline=\"${cmdline}\"" \
          --device virtio-net,nat \
          --device virtio-serial,stdio \
          --device virtio-rng \
          ${rosetta} \
          --device virtio-fs,sharedDir=/nix/store/,mountTag=nix-store \
          --cpus ${toString config.virtualisation.cores} \
          --memory ${toString config.virtualisation.memorySize}
      '';
    };
}
