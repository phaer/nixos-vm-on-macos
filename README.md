# NixOS VM on macOS

This repository contains code to build and run [NixOS](https://nixos.org) in virtual machines on macOS. It uses [vfkit](https://github.com/crc-org/vfkit) as [qemu](https://www.qemu.org/) doesn't support [apple´s virtualisation framework](https://developer.apple.com/documentation/virtualization), and [UTM](https://mac.getutm.app/) isn't as easy to configure from nix expressions.

It is currently not much more than a quick weekend hack and therefore **experimental**, neither stable nor feature-complete - but fun & promising!

# Usage

To start a non-graphical, rather minimal VM with a serial console, but no peristent storage - run:

``` shellsession
$ nix run .\#nixosConfigurations.minimal-vm.config.system.build.vm -L
```

`minimal-vm` got a static mac address defined in `virtualisation.macAddress`, which can be used to derive its ipv6 link local address by running

``` shellsession
$ nix run .\#get-vm-ip minimal-vm
fe80::f425:e2ff:fe48:581e%bridge100
```

# What works

* Booting a closure, directly from kernel and initrd.
* Mounting host file systems
  via `virtio-fs`. Used for a writable overlay over the hosts nix store by default*
* Rosetta - by leveraging vfkit´s and NixOS´ Rosetta integrations you can build derivations for both `aarch64-linux` and `x86_64-linux` in the VM.
* Bridged networking via `virto-net`.
  At least on macOS 15, it [seems non-trivial to match dhcp leases](https://github.com/crc-org/vfkit/issues/242) to virtual machines, but that's not too much of an issue if one uses ipv6 link local adresses.


# What needs work

* GPU: Earlier tests with vfkit and graphical output worked quite well,
  just didn't integrate it in the module so far.
* Persistence: Should be easy, both `virtio-fs` and `virtio-blk` work.  Needs configuration and testing. Might be just need a virtio block device plus system repart.
* VM Tests with our vfkit VMs would be awesome.
* Might be worth a try to (optionally) replace qemu in nix-darwins linux-builder vm for rosetta.
* This list: There's much to explore & still a bit to clean-up.
