{
  lib,
  pkgs,
  ...
}:
{
  imports = [
    ./build.nix
  ];

  nixpkgs.hostPlatform.system = "aarch64-linux";

  # Enable flakes, disable channels.
  nix.channel.enable = lib.mkDefault false;
  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];

  # Enable efficient x86_64 emulation via Apples Rosetta 2 translator.
  # This allows you to build both, x86_64-linux as well as aarch64-linux
  # derivations on the same system with reasonable performance.
  virtualisation.rosetta.enable = lib.mkDefault true;

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

  # We don't use zfs and therefore can use the newest
  # Linux kernels.
  boot.supportedFilesystems.zfs = false;
  boot.kernelPackages = pkgs.linuxPackages_latest;

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

  # Filesystem Layout.
  # This probably needs some improvements and should become easier
  # to customize and persistent storage should be added.
  # But for now it just boots into a small tmpfs with
  # the hosts nix store mounted read-only but overlayed with
  # another tmpfs.
  fileSystems = {
    "/" = {
      device = "none";
      fsType = "tmpfs";
      options = [
        "defaults"
        "size=1G"
        "mode=755"
      ];
    };
    "/nix/store" = {
      overlay = {
        lowerdir = [ "/nix/.ro-store" ];
        upperdir = "/nix/.rw-store/upper";
        workdir = "/nix/.rw-store/work";
      };
    };
    "/nix/.ro-store" = {
      device = "nix-store";
      fsType = "virtiofs";
      neededForBoot = true;
      options = [ "ro" ];
    };
    "/nix/.rw-store" = {
      fsType = "tmpfs";
      options = [ "mode=0755" ];
      neededForBoot = true;
    };
  };

  ## Networking
  # Use systemd-networkd instead of the older, scripted network configuration in NixOS.
  networking.useNetworkd = true;
  # Use all physical interfaces to get DHCP leases for both ipv4 and ipv6.
  systemd.network.networks."10-uplink" = {
    matchConfig.Name = lib.mkDefault "en* eth*";
    networkConfig.DHCP = lib.mkDefault "yes";
  };

}
