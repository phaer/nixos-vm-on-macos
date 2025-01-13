# Options borroed from nixpkgs/nixos/modules/virtualisation/qemu-vm.nix
{ lib, ... }:
let
  inherit (lib) mkOption types;
in
{
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
          #options.securityModel = mkOption {
          #  type = types.enum [
          #    "passthrough"
          #    "mapped-xattr"
          #    "mapped-file"
          #    "none"
          #  ];
          #  default = "mapped-xattr";
          #  description = ''
          #    The security model to use for this share:

          #    - `passthrough`: files are stored using the same credentials as they are created on the guest (this requires QEMU to run as root)
          #    - `mapped-xattr`: some of the file attributes like uid, gid, mode bits and link target are stored as file attributes
          #    - `mapped-file`: the attributes are stored in the hidden .virtfs_metadata directory. Directories exported by this security model cannot interact with other unix tools
          #    - `none`: same as "passthrough" except the sever won't report failures if it fails to set file attributes like ownership
          #  '';
          #};
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
        virtual machine using VirtFS (9P filesystem over VirtIO).
        The attribute name will be used as the 9P mount tag.
      '';
    };
  };
}
