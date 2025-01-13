# Options borroed from nixpkgs/nixos/modules/virtualisation/qemu-vm.nix
{ lib, modulesPath, ... }:
let
  inherit (lib) mkOption types;
in
{
  imports = [ "${modulesPath}/virtualisation/disk-size-option.nix" ];

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
  };

  config = {
    virtualisation.diskSizeAutoSupported = false;
  };
}
