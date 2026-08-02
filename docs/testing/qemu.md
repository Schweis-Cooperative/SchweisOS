# SchweisOS QEMU Test Runbook

Version: 0.1
Status: Active
Date: 2026-08-02

SPDX-License-Identifier: CC-BY-SA-4.0

## Purpose

QEMU is engineering evidence for the ISO and installer path. It does not
replace Ventoy, raw USB, firmware, or hardware qualification, but it catches
missing target disks, broken UEFI handoff, and obvious installer regressions
before a physical test.

## Boot-Only Smoke Test

For a bounded serial-console smoke test that does not create an install target,
use:

```bash
scripts/test-qemu.sh out/iso/schweisos-YYYY.MM.DD-x86_64.iso
```

This extracts the built kernel and initramfs from the ISO and boots them with
the ISO attached as a virtual CD-ROM. It is useful for Archiso boot and display
manager evidence, not for completing an installation.

## Installation Test

An installation test must attach a writable target disk. Booting only with
`-cdrom schweisos-YYYY.MM.DD-x86_64.iso` gives Calamares no installation
target, so a "no installable disk" message is expected.

Create a disposable target image:

```bash
qemu-img create -f qcow2 work/qemu/schweisos-target.qcow2 40G
```

Then boot UEFI with both the ISO and the target disk:

```bash
qemu-system-x86_64 \
  -enable-kvm \
  -machine q35 \
  -m 4096 \
  -smp 4 \
  -cpu host \
  -drive if=pflash,format=raw,readonly=on,file=/usr/share/edk2/x64/OVMF_CODE.4m.fd \
  -drive if=pflash,format=raw,file=work/qemu/OVMF_VARS.4m.fd \
  -cdrom out/iso/schweisos-YYYY.MM.DD-x86_64.iso \
  -drive file=work/qemu/schweisos-target.qcow2,format=qcow2,if=virtio \
  -boot d
```

Copy the firmware variables template before the first boot:

```bash
mkdir -p work/qemu
cp /usr/share/edk2/x64/OVMF_VARS.4m.fd work/qemu/OVMF_VARS.4m.fd
```

The installer should show the virtio target disk as installable. If no target
appears with the command above, collect the Calamares log and treat it as an
installer disk-detection bug. If no target appears when the command omits the
`-drive file=...,if=virtio` disk, the test command is invalid rather than the
ISO.

## Boundaries

- Do not use a host disk as the QEMU target.
- Do not reuse a target image containing evidence from an unrelated test.
- QEMU success is not release qualification by itself.
- Ventoy Normal Mode, Ventoy GRUB2 Mode, and raw USB media still require
  separate hardware records.
