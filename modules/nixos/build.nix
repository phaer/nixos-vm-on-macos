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
        lib.concatStringsSep " \\\n" (
          lib.mapAttrsToList (
            name: value: "--device virtio-fs,sharedDir=${value.source},mountTag=${name}"
          ) cfg.sharedDirectories
        )
      );
      graphics = lib.optionalString cfg.graphics ''
        --device virtio-gpu,width=${toString cfg.resolution.x},height=${toString cfg.resolution.y} \
        --device virtio-input,pointing \
        --device virtio-input,keyboard \
        --gui \
      '';

      regInfo = hostPkgs.closureInfo { rootPaths = config.virtualisation.additionalPaths; };

      useWritableStoreImage = cfg.writableStore && !cfg.writableStoreUseTmpfs;

    in
    hostPkgs.writeShellApplication {
      name = "vfkit-vm";
      runtimeInputs = [
        hostPkgs.vfkit
        hostPkgs.coreutils
      ];
      text = ''
        #!${hostPkgs.runtimeShell}
        set -euo pipefail

        ${lib.optionalString useWritableStoreImage ''
          if [ ! -f store-writable.img ]
          then
            # FIXME make customizable, use virtualisation.diskSize (currently used for / in tmpfs)
            truncate -s 20G store-writable.img
          fi
        ''}

        echo "Starting vfkit VM"

        TMPDIR="$(mktemp --directory --suffix="vfkit-nixos-vm")"
        trap 'rm -rf $TMPDIR' EXIT

        mkdir -p "$TMPDIR/xchg"

        ${lib.optionalString (cfg.useNixStoreImage) ''
           echo "Creating Nix store image..."

           ${hostPkgs.gnutar}/bin/tar --create \
             --absolute-names \
             --verbatim-files-from \
             --transform 'flags=rSh;s|/nix/store/||' \
             --transform 'flags=rSh;s|~nix~case~hack~[[:digit:]]\+||g' \
             --files-from ${
               hostPkgs.closureInfo {
                 rootPaths = [
                   config.system.build.toplevel
                   regInfo
                 ];
               }
             }/store-paths \
             | ${hostPkgs.erofs-utils}/bin/mkfs.erofs \
               --quiet \
               --force-uid=0 \
               --force-gid=0 \
               -L nix-store \
               -U eb176051-bd15-49b7-9e6b-462e0b467019 \
               -T 0 \
               --tar=f \
               "$TMPDIR"/store.img

          echo "Created Nix store image."
        ''}

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
          ${lib.optionalString cfg.mountHostNixStore "--device virtio-fs,sharedDir=/nix/store/,mountTag=nix-store"} \
          ${lib.optionalString cfg.useNixStoreImage "--device nvme,path=\"$TMPDIR\"/store.img"} \
          ${lib.optionalString useWritableStoreImage "--device nvme,path=store-writable.img"} \
          ${sharedDirectories} \
          ${graphics} \
          ${rosetta} \
          --cpus ${toString cfg.cores} \
          --memory ${toString cfg.memorySize}
      '';
    };
}
