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

`minimal-vm` got a static mac address defined in `virtualisation.macAddress`, which can be used to derive its ipv6 link local address by running

``` shellsession
$ nix run .\#get-vm-ip minimal-vm
fe80::f425:e2ff:fe48:581e%bridge100
```

## Disable the GUI

Set `virtualisation.graphics = false` in `configuration.nix`.

# What works

* Booting a closure, directly from kernel and initrd.
* Mounting host file systems
  via `virtio-fs`. Used for a writable overlay over the hosts nix store by default*
* Rosetta - by leveraging vfkit´s and NixOS´ Rosetta integrations you can build derivations for both `aarch64-linux` and `x86_64-linux` in the VM.
* Bridged networking via `virto-net`.
  At least on macOS 15, it [seems non-trivial to match dhcp leases](https://github.com/crc-org/vfkit/issues/242) to virtual machines, but that's not too much of an issue if one uses ipv6 link local adresses.
* Graphical mode with virtio-gpu. vfkit´s GUI seems to be still limited though, e.g.
  no copy & paste support(?).

# What needs work

* Persistence: `virtio-blk` is quite easy to use, just needs a nice interface on the module side. I didn't bother so far, as `virtio-fs` works well enough atm.  
There's a branch `disk` in which I played around with formatting a `virtio-blk` device wich systemd-repart on first boot, but didn't finish taht yet.
* VM Tests with our vfkit VMs would be awesome.
* Might be worth a try to (optionally) replace qemu in nix-darwins linux-builder vm for rosetta.
* This list: There's much to explore & still a bit to clean-up.
