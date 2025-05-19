{
  flake,
  lib,
  modulesPath,
  ...
}:
{
  imports = [
    # Start out with a minimal config. This disables much of the
    # generated documentation and so on by default, but saves
    # size and bandwidth.
    "${modulesPath}/profiles/minimal.nix"

    # Import upstreams nix-builder-vm, the same module nix-darwins
    # linux-builder uses. We going to disable the hard-coded qemu integration
    # below, this should be made composable upstream later on.
    "${modulesPath}/profiles/nix-builder-vm.nix"

    flake.modules.nixos.base
  ];

  # FIXME: fake option, as profiles/minimal.nix assumes that this option
  # exists, but profiles/nix-builder-vm adds virtualisation/nixos-containers
  # to disabledModules.
  options.boot.enableContainers = lib.mkEnableOption "nixos containers";

  config = {

    # Set how many  CPU cores and MB of memory to allocate
    # to this VM. Depending on your machine and the amount of VMs
    # you want to run, those might be good to adapt.
    virtualisation = {
      cores = lib.mkDefault 8;
      memorySize = lib.mkDefault (8 * 1024);
      sharedDirectories = {
        persistent = {
          source = ''"$PWD/persistent"'';
          target = "/persistent";
        };
      };
      # FIXME: unset forwarded ports from nix-builder-vm, because
      # we don't have the options for vfkit implemented yet. That could
      # be done, but we do have a full, routable ip anyway.
      forwardPorts = lib.mkForce [];
    };
    # Set a static MAC address to get the same IP every time.
    # This is an optional, non-upstream option defined in this repo.
    virtualisation.macAddress = "f6:25:e2:48:58:1e";

    # Activate password-less sudo for the "builder" user.
    # Feel free to deactivate it, as it's not needed but can be helpful
    # for interactive debugging in the VM.
    users.users.builder.extraGroups = [ "wheel" ];
    security.sudo.enable = true;
    security.sudo.wheelNeedsPassword = false;

    # Enable a password-less root console in initrd if it fails
    # to switch to stage2 for any reason. This severely inpacts
    # security, but makes debugging issues easier. As we are in
    # an VM, defence against attackers with access to the console
    # seems to be point-less anyway.
    boot.initrd.systemd.emergencyAccess = lib.mkDefault true;

    # Required for some NixOS modules. See it's description at
    # https://search.nixos.org/options?channel=unstable&show=system.stateVersion
  };
}
