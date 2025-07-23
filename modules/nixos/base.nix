{
  lib,
  pkgs,
  config,
  ...
}:
{
  imports = [
    ./build.nix
  ];

  config = lib.mkMerge [

    ## Nix
    {
      # Let nix know which system to build this for
      nixpkgs.hostPlatform.system = "aarch64-linux";

      # Enable flakes, disable channels.
      nix.channel.enable = lib.mkDefault false;
      nix.settings.experimental-features = [
        "nix-command"
        "flakes"
      ];
    }

    ## Rosetta
    {
      # Enable efficient x86_64 emulation via Apples Rosetta 2 translator.
      # This allows you to build both, x86_64-linux as well as aarch64-linux
      # derivations on the same system with reasonable performance.
      virtualisation.rosetta.enable = lib.mkDefault true;
    }

    # Better defaults
    {
      # Mount /etc as an overlay instead of generating it via a script,
      # but keep it mutable. This is experimental but seems to work
      # well with our setup.
      system.etc.overlay.enable = lib.mkDefault true;
      system.etc.overlay.mutable = lib.mkDefault true;

      # NixOS still defaults to its scripted init ram disk.
      # We use the newer systemd-based one instead for performance
      # and customizability improvements.
      boot.initrd.systemd.enable = lib.mkDefault true;

      # GRUB is still NixOS default bootloader outside containers.
      # Disable it as we do direct boot and don't need a bootloader.
      boot.loader.grub.enable = false;

      # We don't use zfs and therefore could use the newest
      # Linux kernels. But rosetta currently fails on my
      # macOS Sequioa machine due to unknown "auxillary vector
      # types" and an older guest kernel seems to work around
      # that.
      # boot.supportedFilesystems.zfs = false;
      # boot.kernelPackages = pkgs.linuxPackages_latest;
      boot.kernelPackages = pkgs.linuxPackages;
    }

    # Kernel parameters & modules
    {
      boot.kernelParams = [
        # The virtio console is known as hvc0 in the guest
        "console=hvc0"
      ];

      boot.initrd.kernelModules = [
        # See initrd output on the virtio console.
        "virtio_console"
        # Ensure shared filesystems such as /nix/store can be
        # mounted early.
        "virtiofs"
      ];
    }

    ## Networking
    {
      # Use systemd-networkd instead of the older, scripted network configuration in NixOS.
      networking.useNetworkd = true;
      # Use all physical interfaces to get DHCP leases for both ipv4 and ipv6.
      systemd.network.networks."10-uplink" = {
        matchConfig.Name = lib.mkDefault "en* eth*";
        networkConfig.DHCP = lib.mkDefault "yes";
        # Opt-in to using the machines mac as a DHCP identifier,
        # instead of a GUID. This makes VM IP adresses more predictable.
        dhcpV4Config.ClientIdentifier = lib.mkDefault "mac";
      };
    }

    ## Filesystem Layout
    {
      # By default, use mkVMOverride to enable building test VMs (e.g. via
      # `nixos-rebuild build-vm`) of a system configuration, where the regular
      # value for the `fileSystems' attribute should be disregarded (since those
      # filesystems don't necessarily exist in the VM). You can disable this
      # override by setting `virtualisation.fileSystems = lib.mkForce { };`.
      fileSystems = lib.mkIf (config.virtualisation.fileSystems != { }) (
        lib.mkVMOverride config.virtualisation.fileSystems
      );

      # This probably needs some improvements and should become easier
      # to customize and persistent storage should be added.

      # It just boots into tmpfs
      # with the hosts nix store mounted read-only but overlayed with
      # another tmpfs by default.

      # If virtualisation.useNixStoreImage is set, we create a store.img
      # erofs image before starting the vm and mount that readOnly to
      # overlay with tmpfs at runtime.
      #
      # If both, virtualisation.useNixStoreImage and writableStore are set,
      # but writableStoreUseTmpfs is unset, we overlay store-writable.img
      # instead.
      #
      # The split image model is still kept in order to allow users to
      # switch between both modes easily, but this might be reconsidered later

      virtualisation.fileSystems = lib.mkMerge [
        {
          "/" = {
            device = "none";
            fsType = "tmpfs";
            options = [
              "defaults"
              "size=${toString config.virtualisation.diskSize}M"
              "mode=755"
            ];
          };
          # Upstream qemu-vm.nix uses a persistent disk for mutable state
          # by default. We only use a tmpfs, so we persist the writeable /nix/store overlay part manually
          "/nix/.rw-store" =
            lib.mkIf (config.virtualisation.writableStore && !config.virtualisation.writableStoreUseTmpfs)
              {
                fsType = "ext4";
                device = "/dev/disk/by-label/nix-store-write";
                neededForBoot = true;
              };
        }
        # Mount point from rosetta.nix gets deleted when we override
        # fileSystems with virtualisation.fileSystems, so we re-add it.
        (lib.mkIf config.virtualisation.rosetta.enable {
          "${config.virtualisation.rosetta.mountPoint}" = {
            device = config.virtualisation.rosetta.mountTag;
            fsType = "virtiofs";
          };
        })
        (lib.optionalAttrs (config.virtualisation.sharedDirectories != { }) (
          lib.mapAttrs' (name: value: {
            name = value.target;
            value = {
              device = name;
              fsType = "virtiofs";
            };
          }) config.virtualisation.sharedDirectories
        ))
      ];
    }

    (lib.mkIf (config.virtualisation.writableStore && !config.virtualisation.writableStoreUseTmpfs) {
      boot.initrd.systemd.repart = {
        enable = true;
        empty = "allow";
        device = "/dev/nvme1n1";
      };
      systemd.repart.partitions = {
        "10-nix-store-writable" = {
          Type = "linux-generic";
          Label = "nix-store-write";
          Format = "ext4";
        };
      };
    })

  ];
}
