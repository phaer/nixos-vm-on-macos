{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "get-vm-ip";
  runtimeInputs = [
    pkgs.nix
  ];

  text = ''
    ipv="''${2:--6}"
    if [ ! "$ipv" = "-4" ] && [ ! "$ipv" = "-6" ]
    then
      echo "usage: $0 <vm-name> [-4|-6]"
      exit 1
    fi

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

    if [ "$ipv" = "-6" ]
    then
      mac_to_ipv6_ll "$mac_address" "bridge100"
    else
      grep -B 1 "hw_address=1,$mac_address" /var/db/dhcpd_leases \
      | head -1 \
      | cut -d "=" -f 2
    fi
  '';
}
