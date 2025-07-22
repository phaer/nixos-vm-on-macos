Note: This is currently slightly broken on main, but I do lack time resources to fix right Away. I'll remove this notice when done.

# NixOS VM on macOS

This repository contains code to build and run [NixOS](https://nixos.org) in virtual machines on macOS. It uses [vfkit](https://github.com/crc-org/vfkit) as [qemu](https://www.qemu.org/) doesn't support [apple´s virtualisation framework](https://developer.apple.com/documentation/virtualization), and [UTM](https://mac.getutm.app/) isn't as easy to configure from nix expressions.

It is currently not much more than a quick weekend hack and therefore **experimental**, neither stable nor feature-complete - but fun & promising!

# Usage

To start a graphical, rather minimal VM run:

``` shellsession
$ nix run .\#nixosConfigurations.minimal-vm.config.system.build.vm -L
```

## Share Files

The local (currently empty) directory `persistent` gets mounted to `/persistent` in the guest via `virtio-fs``.

## Get the IP

`minimal-vm` has a static mac address defined in `virtualisation.macAddress`, which can be used to derive its ipv6 link local address. A legacy ipv4 address can be acquired by
parsing `/var/db/dhcpd_leases`. A helper script to do both is included in this repository:

``` shellsession
$ nix run .\#get-vm-ip -- minimal-vm
fe80::f425:e2ff:fe48:581e%bridge100
$ nix run .\#get-vm-ip -- minimal-vm -4
192.168.64.2
```

## Enable the GUI

Set `virtualisation.graphics = true;` in `configuration.nix`.

# Builder VM

There's a proof-of-concept implementation of nix-darwins `pkgs.linux-builder`, based on vfkit and therefore able to use rosetta.

You can start it with

``` shellsession
nix run .\#nixosConfigurations.builder-vm.config.system.build.macos-builder-installer -L
```

But it might interfere with already running linux-builders. It doesn't listen on
a high port, as upstream does. Instead its local IP is fully routed.
A patched, not yet upstreamed, nix-darwin fork to allow setting a custom host & port for the builder is available at:
https://github.com/nix-darwin/nix-darwin/pull/1459


# What works

* Booting a closure, directly from kernel and initrd.
* Mounting host file systems
  via `virtio-fs`. Used for a writable overlay over the hosts nix store by default
  (see [hosts/minimal-vm](./hosts/minimal-vm)
* Alternatively, a read-only erofs image with your boot closure and an optional
  writable overlay in a separate disk image. Those should eventually become a single image. See [hosts/builder-vm](./hosts/builder-vm)
* Rosetta - by leveraging vfkit´s and NixOS´ Rosetta integrations you can build derivations for both `aarch64-linux` and `x86_64-linux` in the VM.
* Bridged networking via `virto-net`.
* Graphical mode with virtio-gpu. vfkit´s GUI seems to be still limited though, e.g.
  no copy & paste support(?).

# What needs work

* VM Tests with our vfkit VMs would be awesome.
* CI tests for the builds would be awesome.
* Same for a release pipeline to pre-build images.
* This list: There's much to explore & still a bit to clean-up.
