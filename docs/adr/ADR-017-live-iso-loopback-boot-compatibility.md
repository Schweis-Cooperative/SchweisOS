# ADR-017 Live ISO Loopback Boot Compatibility

Version: 1.1

## Status

Accepted

## Date

2026-07-30

## Related ADRs and DDRs

- ADR-002 UEFI First
- ADR-012 ISO Build Architecture
- ADR-013 ISO Build Workflow
- ADR-014 Live Boot Experience Architecture
- ADR-015 GRUB Theme Architecture
- DDR-001 Boot Experience

## Context

The SchweisOS KDE live medium boots successfully through Archiso's native
UEFI `systemd-boot` path, including QEMU tests that boot the ISO directly as a
virtual optical medium. Real-hardware Ventoy testing exposed a separate boot
path. The first failure occurred before the kernel started:

```text
Loading kernel...
error: attempt to read or write outside of disk 'loop'
Loading initrd...
error: you need to load the kernel first.
```

The generated ISO contains the live kernel and initramfs at the expected
Archiso paths:

```text
/schweis/boot/x86_64/vmlinuz-linux
/schweis/boot/x86_64/initramfs-linux.img
```

That failure was not caused by Plymouth, the initramfs userspace, KDE,
Calamares, or the installed-system boot design. It occurred in the multiboot
GRUB loopback path used by tools such as Ventoy before Linux was loaded.

After adding the reviewed loopback file, a second real-hardware test proved
that the kernel and initramfs could start but the Archiso hook stopped with:

```text
:: running hook [archiso]
ERROR: Device '<Archiso UUID marker>' not found
```

The tested ISO had a valid volume label, a single `/boot/*.uuid` marker,
matching native systemd-boot entries, and a valid `/boot/grub/loopback.cfg`
that passed `img_dev` and `img_loop`. The missing piece was inside the live
initramfs: SchweisOS carried `archiso` but not the upstream
`archiso_loop_mnt` hook that turns the outer GRUB `img_dev/img_loop` handoff
into a read-only loop device before delegating to the normal Archiso mount
handler. Without that hook, the initramfs ignores the loopback-specific
handoff and falls back to native device/UUID-marker discovery, which cannot
find an ISO stored as a file on Ventoy's USB filesystem.

Upstream Archiso supports a small loopback compatibility file at
`grub/loopback.cfg`. When present in the profile, `mkarchiso` copies it to
`/boot/grub/loopback.cfg` in the ISO root even if the live medium's native UEFI
boot mode remains `uefi.systemd-boot`. This file lets an outer GRUB instance
find the filesystem containing the ISO file, load the kernel and initramfs from
inside the ISO, and pass `img_dev` plus `img_loop` to the Archiso initramfs.
The initramfs must also include Archiso's `archiso_loop_mnt` hook; otherwise
those parameters are present on the kernel command line but no early-userspace
component consumes them.

## Decision

SchweisOS will keep the native KDE live-medium boot mode as upstream Archiso
`uefi.systemd-boot` and add only the upstream-supported GRUB loopback
compatibility file plus its matching initramfs hook:

```text
iso/profiles/kde/grub/loopback.cfg
iso/profiles/kde/airootfs/etc/mkinitcpio.conf.d/archiso.conf
```

The profile-owned loopback file will:

- expose the same reviewed normal and debug SchweisOS live boot choices as the
  systemd-boot menu;
- load `/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux`;
- load `/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img`;
- pass `archisobasedir=%INSTALL_DIR%`;
- derive `img_dev=UUID=${archiso_img_dev_uuid}` from the filesystem that stores
  the ISO file;
- pass `img_loop="${iso_path}"` so the Archiso initramfs can mount the ISO
  file provided by the multiboot tool;
- preserve `systemd.firstboot=no` on both entries;
- preserve the quiet Plymouth default and the visible debug fallback entry;
- provide only small utility entries that are safe in GRUB loopback context.

The live initramfs hook list will include `archiso_loop_mnt` immediately after
`archiso`. The native systemd-boot entries continue to use
`archisosearchuuid=%ARCHISO_UUID%`, matching upstream Archiso's native
search-marker behavior. SchweisOS must not replace the native entries with
label-only discovery to solve a Ventoy loopback problem; Ventoy's ISO-file
path is handled by `img_dev/img_loop` and `archiso_loop_mnt`.

This decision does not enable Archiso's `uefi.grub` boot mode, add the `grub`
package to the live ISO, create a full `/boot/grub/grub.cfg`, add BIOS support,
or activate the packaged installed-system GRUB theme. Those remain separate
installer and bootloader decisions.

## Ownership

- `iso/profiles/kde/grub/loopback.cfg` owns only live ISO loopback
  compatibility for outer GRUB/multiboot launchers.
- `iso/profiles/kde/airootfs/etc/mkinitcpio.conf.d/archiso.conf` owns the
  narrowly scoped live initramfs hook extension required to consume that
  loopback handoff.
- `iso/profiles/kde/efiboot/` continues to own the native systemd-boot live
  path.
- `schweisos-grub-theme` remains inert installed-system theme groundwork and is
  not consumed by the current live ISO.
- `scripts/build-iso.sh` continues to orchestrate Archiso and must not generate
  ad-hoc bootloader files.
- Validators own drift detection for kernel/initramfs paths, volume label and
  UUID-marker metadata, native and loopback kernel command lines, initramfs
  hook presence, and forbidden full GRUB/syslinux profile additions.

## Alternatives Considered

### Enable Archiso `uefi.grub`

Rejected for the current profile. The selected live-medium boot mode is
systemd-boot, and current Archiso validation treats `uefi.grub` and
`uefi.systemd-boot` as mutually exclusive UEFI bootloader modes. Switching the
native bootloader would expand the boot architecture beyond the reported
Ventoy failure and reopen a boot-experience phase that is otherwise closed.

### Add a Full `grub.cfg`

Rejected. A full GRUB configuration would imply a native GRUB live boot path.
The compatibility requirement is narrower: an outer GRUB instance needs a
loopback entry that can load the existing Archiso kernel and initramfs while
passing the ISO-file mount parameters.

### Rely on Ventoy's Generated Menu

Rejected. The tested real-hardware failure shows that relying on an inferred
or generated menu can select an incompatible kernel/initramfs handoff. The ISO
must carry the project-reviewed loopback contract itself.

### Move Kernel or Initramfs Paths

Rejected. The current kernel and initramfs locations match the Archiso
convention for the selected `install_dir` and architecture. Moving them would
increase drift from upstream Archiso and risk breaking the working native UEFI
path.

### Replace Native Entries with `archisolabel`

Rejected for this defect. The tested failure did not prove volume-label drift;
it proved that an outer GRUB loopback boot reached initramfs without the
`archiso_loop_mnt` hook that consumes `img_dev/img_loop`. Native systemd-boot
continues to use Archiso's `archisosearchuuid` marker contract. Completed ISO
validation verifies the real ISO volume label through `xorriso`, the UUID
marker, `grubenv`, and loader entry command lines so real drift is caught
without changing the native boot strategy.

## Consequences

Positive consequences:

- Ventoy and similar GRUB loopback launchers receive an explicit, reviewed
  SchweisOS boot contract.
- The native systemd-boot path remains minimal, fast, and upstream-compatible.
- The loopback path mirrors the same normal/debug behavior as the native live
  entries, preserving debuggability.
- Kernel filename, initramfs filename, `install_dir`, architecture, Archiso
  ISO-file handoff, and required loopback hook drift are now statically
  validated.
- Completed ISO validation now checks the bootloader-visible ISO root, ISO
  volume label, UUID marker, native command lines, loopback command lines, and
  initramfs hook list before expensive SquashFS inspection.

Negative consequences:

- The live profile now contains a tiny `grub/` directory despite not using GRUB
  as its native bootloader. Validators must keep that directory restricted to
  `loopback.cfg`.
- Static validation can prove ISO structure and handoff parameters, but only
  real Ventoy hardware testing can prove a specific firmware, USB device, and
  Ventoy version combination.

## Validation

Pre-build validation must fail closed if:

- `iso/profiles/kde/grub/loopback.cfg` is missing;
- any file other than `loopback.cfg` appears in the profile `grub/` directory;
- `grub.cfg` is added to the live profile under the current systemd-boot
  contract;
- the loopback normal/debug entries stop using the reviewed kernel or initramfs
  paths;
- either entry omits `archisobasedir`, `img_dev`, `img_loop`, or
  `systemd.firstboot=no`;
- the live mkinitcpio hook list omits `archiso_loop_mnt` after `archiso`;
- the quiet and debug entries drift from the existing live boot policy.

Completed ISO validation must fail closed if:

- `/boot/grub/loopback.cfg` is absent from the ISO root;
- the ISO-visible loopback file differs from the reviewed profile source after
  Archiso token substitution;
- unresolved Archiso template tokens remain in the ISO-visible file;
- the ISO is missing the kernel, initramfs, loader entries, EFI image, boot
  catalog, or exactly one Archiso UUID marker;
- the ISO volume label, `grubenv` label, native `archisosearchuuid`, and UUID
  marker metadata no longer agree;
- the live initramfs omits `archiso_loop_mnt`;
- a full `boot/grub/grub.cfg` or syslinux configuration enters the image under
  the current UEFI-only live contract.

Manual Ventoy hardware boot remains required release evidence. Passing these
validators means the repository no longer reproduces the known missing
loopback contracts that caused the reported pre-kernel GRUB failure and the
later initramfs device-discovery failure.
