# Options borrowed from nixpkgs/nixos/modules/virtualisation/qemu-vm.nix
{
  lib,
  config,
  pkgs,
  options,
  modulesPath,
  ...
}:
let
  inherit (lib) mkOption types;
  cfg = config.virtualisation;
in
{
  imports = [
    "${modulesPath}/virtualisation/disk-size-option.nix"
  ];

  disabledModules = [
    # Disable upstreams qemu-vm.nix, which is is imported by nix-builder-vm.
    # We going to replace the options used by it below.
    "${modulesPath}/virtualisation/qemu-vm.nix"
  ];

  config = {
    warnings =
      lib.optionals
        # TODO: support at least the SSH forwarding from host 22 -> guest cfg.darwin-builder.hostPort
        (cfg.forwardPorts != [ ])
        [
          "virtualisation.forwardPorts is currently not implemented with vfkit. Full networking via IP is available."
        ];

    security.pki.installCACerts = lib.mkIf cfg.useHostCerts false;

    virtualisation.diskSizeAutoSupported = false;

    virtualisation.sharedDirectories = {
      xchg = {
        source = ''"$TMPDIR"/xchg'';
        securityModel = "none";
        target = "/tmp/xchg";
      };
      shared = {
        source = ''"''${SHARED_DIR:-$TMPDIR/xchg}"'';
        target = "/tmp/shared";
        securityModel = "none";
      };
      certs = lib.mkIf cfg.useHostCerts {
        source = ''"$TMPDIR"/certs'';
        target = "/etc/ssl/certs";
        securityModel = "none";
      };
    };

    virtualisation.fileSystems = {
      "/nix/store" = lib.mkIf (cfg.useNixStoreImage || cfg.mountHostNixStore) (
        if cfg.writableStore then
          {
            overlay = {
              lowerdir = [ "/nix/.ro-store" ];
              upperdir = "/nix/.rw-store/upper";
              workdir = "/nix/.rw-store/work";
            };
          }
        else
          {
            device = "/nix/.ro-store";
            options = [ "bind" ];
          }
      );
      "/nix/.ro-store" = lib.mkIf (cfg.useNixStoreImage || cfg.mountHostNixStore) {
        device = if cfg.mountHostNixStore then "nix-store" else "/dev/disk/by-label/nix-store";
        fsType = if cfg.mountHostNixStore then "virtiofs" else "erofs";
        neededForBoot = true;
        options = [ "ro" ];
      };
      "/nix/.rw-store" = lib.mkIf (cfg.writableStore && cfg.writableStoreUseTmpfs) {
        fsType = "tmpfs";
        options = [ "mode=0755" ];
        neededForBoot = true;
      };
    };
  };

  options = {
    virtualisation.fileSystems = options.fileSystems;

    virtualisation.host.pkgs = mkOption {
      type = options.nixpkgs.pkgs.type;
      default = pkgs;
      defaultText = lib.literalExpression "pkgs";
      example = lib.literalExpression ''
        import pkgs.path { system = "x86_64-darwin"; }
      '';
      description = ''
        Package set to use for the host-specific packages of the VM runner.
        Changing this to e.g. a Darwin package set allows running NixOS VMs on Darwin.
      '';
    };

    virtualisation.memorySize = mkOption {
      type = types.ints.positive;
      default = 1024;
      description = ''
        The memory size in megabytes of the virtual machine.
      '';
    };

    virtualisation.cores = mkOption {
      type = types.ints.positive;
      default = 1;
      description = ''
          Specify the number of cores the guest is permitted to use.
        The number can be higher than the available cores on the
        host system.
      '';
    };

    virtualisation.sharedDirectories = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.source = mkOption {
            type = types.str;
            description = "The path of the directory to share, can be a shell variable";
          };
          options.target = mkOption {
            type = types.path;
            description = "The mount point of the directory inside the virtual machine";
          };
          options.securityModel = mkOption {
            type = types.enum [
              "passthrough"
              "mapped-xattr"
              "mapped-file"
              "none"
            ];
            default = "mapped-xattr";
            description = ''
                The security model to use for this share:

              - `passthrough`: files are stored using the same credentials as they are created on the guest (this requires QEMU to run as root)
              - `mapped-xattr`: some of the file attributes like uid, gid, mode bits and link target are stored as file attributes
              - `mapped-file`: the attributes are stored in the hidden .virtfs_metadata directory. Directories exported by this security model cannot interact with other unix tools
              - `none`: same as "passthrough" except the sever won't report failures if it fails to set file attributes like ownership
            '';
          };
        }
      );
      default = { };
      example = {
        my-share = {
          source = "/path/to/be/shared";
          target = "/mnt/shared";
        };
      };
      description = ''
          An attributes set of directories that will be shared with the
        virtual machine using virtio-fs
      '';
    };

    virtualisation.additionalPaths = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = ''
          A list of paths whose closure should be made available to
        the VM.

        When 9p is used, the closure is registered in the Nix
        database in the VM. All other paths in the host Nix store
        appear in the guest Nix store as well, but are considered
        garbage (because they are not registered in the Nix
        database of the guest).

        When {option}`virtualisation.useNixStoreImage` is
        set, the closure is copied to the Nix store image.
      '';
    };

    virtualisation.useNixStoreImage = mkOption {
      type = types.bool;
      default = false;
      description = ''
          Build and use a disk image for the Nix store, instead of
        accessing the host's one through 9p.

        For applications which do a lot of reads from the store,
        this can drastically improve performance, but at the cost of
        disk space and image build time.

        The Nix store image is built just-in-time right before the VM is
        started. Because it does not produce another derivation, the image is
        not cached between invocations and never lands in the store or binary
        cache.

        If you want a full disk image with a partition table and a root
        filesystem instead of only a store image, enable
        {option}`virtualisation.useBootLoader` instead.
      '';
    };

    virtualisation.mountHostNixStore = mkOption {
      type = types.bool;
      default = !cfg.useNixStoreImage && !cfg.useBootLoader;
      defaultText = lib.literalExpression "!cfg.useNixStoreImage && !cfg.useBootLoader";
      description = ''
        Mount the host Nix store as a 9p mount.
      '';
    };

    virtualisation.useBootLoader = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Use a boot loader to boot the system.
        This allows, among other things, testing the boot loader.

        If disabled, the kernel and initrd are directly booted,
        forgoing any bootloader.

        Check the documentation on {option}`virtualisation.directBoot.enable` for details.
      '';
    };

    virtualisation.writableStore = mkOption {
      type = types.bool;
      default = cfg.mountHostNixStore;
      defaultText = lib.literalExpression "cfg.mountHostNixStore";
      description = ''
          If enabled, the Nix store in the VM is made writable by
        layering an overlay filesystem on top of the host's Nix
        store.

        By default, this is enabled if you mount a host Nix store.
      '';
    };

    virtualisation.writableStoreUseTmpfs = mkOption {
      type = types.bool;
      default = true;
      description = ''
          Use a tmpfs for the writable store instead of writing to the VM's
        own filesystem.
      '';
    };

    virtualisation.useHostCerts = mkOption {
      type = types.bool;
      default = false;
      description = ''
          If enabled, when `NIX_SSL_CERT_FILE` is set on the host,
        pass the CA certificates from the host to the VM.
      '';
    };

    virtualisation.graphics = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Whether to run vfkit with a graphics window.
      '';
    };

    virtualisation.resolution = mkOption {
      type = types.attrsOf types.ints.positive;
      default = {
        x = 1024;
        y = 768;
      };
      description = ''
        The resolution of the virtual machine display.
      '';
    };

    virtualisation.forwardPorts = mkOption {
      type = types.listOf (
        types.submodule {
          options.from = mkOption {
            type = types.enum [
              "host"
              "guest"
            ];
            default = "host";
            description = ''
                Controls the direction in which the ports are mapped:

              - `"host"` means traffic from the host ports
                is forwarded to the given guest port.
              - `"guest"` means traffic from the guest ports
                is forwarded to the given host port.
            '';
          };
          options.proto = mkOption {
            type = types.enum [
              "tcp"
              "udp"
            ];
            default = "tcp";
            description = "The protocol to forward.";
          };
          options.host.address = mkOption {
            type = types.str;
            default = "";
            description = "The IPv4 address of the host.";
          };
          options.host.port = mkOption {
            type = types.port;
            description = "The host port to be mapped.";
          };
          options.guest.address = mkOption {
            type = types.str;
            default = "";
            description = "The IPv4 address on the guest VLAN.";
          };
          options.guest.port = mkOption {
            type = types.port;
            description = "The guest port to be mapped.";
          };
        }
      );
      default = [ ];
      example = lib.literalExpression ''
          [ # forward local port 2222 -> 22, to ssh into the VM
          { from = "host"; host.port = 2222; guest.port = 22; }

          # forward local port 80 -> 10.0.2.10:80 in the VLAN
          { from = "guest";
            guest.address = "10.0.2.10"; guest.port = 80;
            host.address = "127.0.0.1"; host.port = 80;
          }
        ]
      '';
      description = ''
          When using the SLiRP user networking (default), this option allows to
        forward ports to/from the host/guest.

        ::: {.warning}
        If the NixOS firewall on the virtual machine is enabled, you also
        have to open the guest ports to enable the traffic between host and
        guest.
        :::

        ::: {.note}
        Currently QEMU supports only IPv4 forwarding.
        :::
      '';
    };
  };
}
