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
    flake.modules.nixos.base
  ];

  # Set how many  CPU cores and MB of memory to allocate
  # to this VM. Depending on your machine and the amount of VMs
  # you want to run, those might be good to adapt.
  virtualisation = {
    cores = lib.mkDefault 4;
    memorySize = lib.mkDefault (4 * 1024);
    sharedDirectories = {
      persistent = {
        source = "$PWD/persistent";
        target = "/persistent";
      };
    };
  };
  # Set a static MAC address to get the same IP every time.
  # This is an optional, non-upstream option defined in this repo.
  virtualisation.macAddress = "f6:25:e2:48:58:1e";

  virtualisation.graphics = true;

  # Automatically log in as root on the console. # This makes it
  # unecessary to configure any credentials for simple ephmeral VM.
  services.getty.autologinUser = lib.mkDefault "root";

  # Enable a password-less root console in initrd if it fails
  # to switch to stage2 for any reason. This severely inpacts
  # security, but makes debugging issues easier. As we are in
  # an VM, defence against attackers with access to the console
  # seems to be point-less anyway.
  boot.initrd.systemd.emergencyAccess = lib.mkDefault true;

  # Required for some NixOS modules. See it's description at
  # https://search.nixos.org/options?channel=unstable&show=system.stateVersion
  system.stateVersion = "25.05";
}
