{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "get-vm-ip";
  runtimeInputs = [
    pkgs.nix
  ];

  text = ''
    # Thanks, https://unix.stackexchange.com/a/489273
    mac_to_ipv6_ll() {
      bridge=$2
      IFS=':'
      # shellcheck disable=SC2086
      set $1
      unset IFS
      echo "fe80::$(printf %02x $((0x$1 ^ 2)))$2:''${3}ff:fe$4:$5$6%$bridge"
    }

    bridge=
    mac_address="$(
      nix eval --raw \
      ".#nixosConfigurations.$1.config.virtualisation.macAddress")"
    mac_to_ipv6_ll "$mac_address" "bridge100"
  '';
}
