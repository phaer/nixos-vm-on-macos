# Options borroed from nixpkgs/nixos/modules/virtualisation/qemu-vm.nix
{ lib, modulesPath, ... }:
let
  inherit (lib) mkOption types;
in
{
  imports = [
    "${modulesPath}/virtualisation/disk-size-option.nix"
  ];

  config = {
    virtualisation.diskSizeAutoSupported = false;
  };

  options = {

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
  };
}
