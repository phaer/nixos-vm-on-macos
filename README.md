# NixOS VM on macOS

This repository contains code to build and run [NixOS](https://nixos.org) in virtual machines on macOS. It uses [vfkit](https://github.com/crc-org/vfkit) as [qemu](https://www.qemu.org/) doesn't support [apple´s virtualisation framework](https://developer.apple.com/documentation/virtualization), and [UTM](https://mac.getutm.app/) isn't as easy to configure from nix expressions.

It is currently not much more than a quick weekend hack and therefore **experimental**, neither stable nor feature-complete - but fun & promising!

# Usage

To start a non-graphical, rather minimal VM with a serial console, but no peristent storage nor host-to-guest networking yet (guest-to-internet works fine, except for ICMP) - run:

``` shellsession
nix run .\#nixosConfigurations.minimal-vm.config.system.build.vm -L
```

# What works

* Booting a closure, directly from kernel and initrd.
* Mounting host file systems
  via `virtio-fs`. Used for a writable overlay over the hosts nix store by default*
* Rosetta - by leveraging vfkit´s and NixOS´ Rosetta integrations you can build derivations for both `aarch64-linux` and `x86_64-linux` in the VM.

# What needs work

* Host-to-Guest-Networking: Not integrated yet. Plan is to package [gvisor-tap-vsock](https://github.com/containers/gvisor-tap-vsock) or https://github.com/njhsi/macos-virtio-net in nixpkgs and use either of that.
* GPU: Earlier tests with vfkit and graphical output worked quite well,
  just didn't integrate it in the module so far.
* Persistence: Should be easy, both `virtio-fs` and `virtio-blk` work.  Needs configuration and testing. Might be just need a virtio block device plus system repart.
* VM Tests with our vfkit VMs would be awesome.
* Might be worth a try to (optionally) replace qemu in nix-darwins linux-builder vm for rosetta.
* This list: There's much to explore & still a bit to clean-up.
