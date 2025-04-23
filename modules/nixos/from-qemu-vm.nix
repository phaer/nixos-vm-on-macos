# Options borrowed from nixpkgs/nixos/modules/virtualisation/qemu-vm.nix
{ lib, config, modulesPath, ... }:
let
  inherit (lib) mkOption types;
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
      virtualisation.diskSizeAutoSupported = false;

      assertions = [
        {
          # TODO: support at least the SSH forwarding from host 22 -> guest cfg.darwin-builder.hostPort
          assertion = config.virtualisation.forwardPorts == [];
          message = "virtualisation.forwardPorts is currently not implemented with vfkit. Full networking via IP is available.";
        }
      ];
    };

    options = {
      # TODO:
      # - useNixStoreImage
      # - writableStore
      # - writableStoreUseTmpfs
      # - useHostCerts

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
