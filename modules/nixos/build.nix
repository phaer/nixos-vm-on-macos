{
  lib,
  config,
  pkgs,
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
    };

  # Instantiate our nixpkgs version once more, this time for darwin.
  # This is needed so that we get binaries for darwin, not linux for
  # all of the dependencies the script below, such as bash # to vfkit.
  # With blueprint there's currently no nicer way to pass this through
  # as far as i know.
  config.virtualisation.host.pkgs = import pkgs.path {
    system = "${config.nixpkgs.hostPlatform.qemuArch}-darwin";
  };

  config.system.build.vm =
    let
      cfg = config.virtualisation;

      hostPkgs = cfg.host.pkgs;

      kernel = "${config.system.build.toplevel}/kernel";
      initrd = "${config.system.build.toplevel}/initrd";
      cmdline = lib.concatStringsSep " " (
        config.boot.kernelParams or [ ] ++ [ "init=${config.system.build.toplevel}/init" ]
      );
      rosetta = lib.optionalString cfg.rosetta.enable "--device rosetta,mountTag=rosetta";
      macAddress = lib.optionalString (cfg.macAddress != null) ",mac=${cfg.macAddress}";
      sharedDirectories = lib.optionalString (cfg.sharedDirectories != null) (
        lib.concatStringsSep "\\\n" (
          lib.mapAttrsToList (
            name: value: "--device \"virtio-fs,sharedDir=${value.source},mountTag=${name}\""
          ) cfg.sharedDirectories
        )
      );
      graphics = lib.optionalString cfg.graphics ''
        --device virtio-gpu,width=${toString cfg.resolution.x},height=${toString cfg.resolution.y} \
        --device virtio-input,pointing \
        --device virtio-input,keyboard \
        --gui \
      '';

    in
    hostPkgs.writeShellApplication {
      name = "vfkit-vm";
      runtimeInputs = [
        hostPkgs.vfkit
      ];
      text = ''
        #!${hostPkgs.runtimeShell}
        set -euo pipefail

        echo "Starting VM"

        TMPDIR="$(mktemp --directory --suffix="vfkit-nixos-vm")"
        trap "rm -rf $TMPDIR" EXIT

        mkdir -p "$TMPDIR/xchg"

        ${lib.optionalString cfg.useHostCerts ''
          mkdir -p "$TMPDIR/certs"
          if [ -e "$NIX_SSL_CERT_FILE" ]; then
            cp -L "$NIX_SSL_CERT_FILE" "$TMPDIR"/certs/ca-certificates.crt
          else
            echo \$NIX_SSL_CERT_FILE should point to a valid file if virtualisation.useHostCerts is enabled.
          fi
        ''}

        vfkit \
        --bootloader "linux,kernel=${kernel},initrd=${initrd},cmdline=\"${cmdline}\"" \
          --device "virtio-net,nat${macAddress}" \
          --device virtio-serial,stdio \
          --device virtio-rng \
          --device virtio-fs,sharedDir=/nix/store/,mountTag=nix-store \
          ${sharedDirectories} \
          ${graphics} \
          ${rosetta} \
          --cpus ${toString cfg.cores} \
          --memory ${toString cfg.memorySize}
      '';
    };
}
