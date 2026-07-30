# ADR-017 Live ISO Loopback Boot Compatibility

Version: 1.3

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
that was capable of passing `img_dev` and `img_loop`. Static inspection found a
real defect inside the live initramfs: SchweisOS carried `archiso` but not the
upstream `archiso_loop_mnt` hook that consumes an outer GRUB
`img_dev/img_loop` handoff. That omission made the reviewed loopback contract
incomplete. The runtime log itself did not include `/proc/cmdline`, however, so
it proved UUID-marker discovery failed but did not prove that Ventoy had
executed `loopback.cfg` or supplied the handoff parameters in that boot.

Upstream Archiso supports a small loopback compatibility file at
`grub/loopback.cfg`. When present in the profile, `mkarchiso` copies it to
`/boot/grub/loopback.cfg` in the ISO root even if the live medium's native UEFI
boot mode remains `uefi.systemd-boot`. This file lets an outer GRUB instance
find the filesystem containing the ISO file, load the kernel and initramfs from
inside the ISO, and pass `img_dev` plus `img_loop` to the Archiso initramfs.
The initramfs must also include Archiso's `archiso_loop_mnt` hook; otherwise
those parameters are present on the kernel command line but no early-userspace
component consumes them.

After adding `archiso_loop_mnt`, a third real-hardware Ventoy test proved that
the hook was present and executed. The observed initramfs log contained both:

```text
:: running hook [archiso]
:: running hook [archiso_loop_mnt]
Waiting 10 seconds for device /dev/disk/by-uuid/<Archiso UUID marker> ...
:: Searching for '/boot/<Archiso UUID marker>.uuid' in '/dev/sda1'
ERROR: Device '<Archiso UUID marker>' not found
```

That proves `archiso_loop_mnt` was no longer missing. Because the hook left the
native UUID search handler active, it did not receive a usable complete
`img_dev` plus `img_loop` handoff. This does not identify whether systemd-boot,
a generated GRUB entry, or another loader produced the command line. It does
show the native `archisosearchuuid` contract was active. On a file-based
multiboot filesystem, the marker exists inside the ISO file rather than
directly on the outer partition, so stock block-device marker discovery cannot
find the live root.

The next reported normal-mode failure was not produced by the current
locally inspected ISO. The photographed initramfs requested marker
`2026-07-29-22-25-32-00` and did not run
`schweisos_iso_file_fallback`; the current artifact requested
`2026-07-30-12-20-42-00`, and direct initramfs inspection proved that the
fallback hook and its required binaries were present. A filename copied to
Ventoy is therefore not sufficient evidence that the intended ISO was booted.
The exact media copy must be bound to the validated source artifact before a
hardware result can be attributed to current code.

`loopback.cfg` is the upstream Archiso-compatible contract for an outer GRUB
that elects to consume it. It is not a guarantee about Ventoy's internal mode
selection. Ventoy's documented GRUB2 mode searches supported `grub.cfg`
locations and can synthesize entries from loader metadata; it does not promise
to execute `/boot/grub/loopback.cfg`. SchweisOS must therefore classify the
actual path from the live kernel command line:

- `img_dev` plus `img_loop` means the upstream outer-GRUB ISO-file handoff is
  active;
- `archisosearchuuid` without those parameters means the native Archiso search
  path is active and the SchweisOS fallback may be required.

## Decision

SchweisOS will keep the native KDE live-medium boot mode as upstream Archiso
`uefi.systemd-boot` and add only the upstream-supported GRUB loopback
compatibility file plus its matching initramfs hook:

```text
iso/profiles/kde/grub/loopback.cfg
iso/profiles/kde/airootfs/etc/mkinitcpio.conf.d/archiso.conf
iso/profiles/kde/airootfs/usr/lib/initcpio/hooks/schweisos_iso_file_fallback
iso/profiles/kde/airootfs/usr/lib/initcpio/install/schweisos_iso_file_fallback
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
`archiso` and SchweisOS' ISO-file fallback hook immediately after
`archiso_loop_mnt`. The native systemd-boot entries continue to use
`archisosearchuuid=%ARCHISO_UUID%`, matching upstream Archiso's native
search-marker behavior.

The SchweisOS fallback hook is intentionally narrow:

- it does nothing when `archiso_loop_mnt` has already selected the upstream
  loopback mount handler from `img_dev/img_loop`;
- it runs only when the native `archisosearchuuid` contract is active and no
  `img_dev/img_loop` handoff exists;
- it first preserves native removable-media boot by looking for the requested
  marker directly on removable partitions;
- if the direct marker is absent, it searches removable media for ISO files
  whose raw contents contain the requested `<uuid>.uuid` marker;
- when a matching ISO is found, it creates a read-only loop device, clears the
  native search variables, and delegates back to upstream
  `archiso_mount_handler`;
- it does not perform an unconditional `modprobe loop` before `losetup`.
  Hardware testing showed repeated `Invalid ELF header magic` diagnostics
  immediately after this hook started; keeping module loading out of the normal
  successful path avoids that noisy and non-authoritative module-loader
  interaction while still letting the hook fail closed if a loop device cannot
  be created;
- it does not scan non-removable internal disks before falling back to the
  upstream Archiso handler.

SchweisOS must not replace the native entries with label-only discovery to
solve a Ventoy problem. An outer GRUB path that consumes the reviewed
`loopback.cfg` is handled by `img_dev/img_loop` and `archiso_loop_mnt`.
A multiboot path that supplies the native Archiso search contract without a
complete ISO-file handoff is handled by the SchweisOS fallback when needed.
Menu labels such as “Normal Mode” or
“GRUB2 Mode” are not used as proof of either handoff; `/proc/cmdline` is the
runtime evidence.

Before a file-based multiboot hardware boot,
`tests/validate-boot-media-copy.sh` must bind three inputs: the successful clean
build manifest, the completed source ISO named by that manifest, and the
destination copy. The manifest commit must equal the clean validator checkout's
current commit. The source must also pass the current built-ISO identity and
boot-composition validators, including SquashFS and installer payload
inspection. After copying, the medium must be synchronized, safely unmounted,
physically reinserted, and mounted read-only for validation. The destination
must be on an available block-device filesystem distinct from the host root
filesystem, contain exactly one `schweisos-*.iso`, retain the canonical
basename, and match source size, SHA256, and bytes. This gate is writing-tool
agnostic within that file-copy scope: it verifies the result on Ventoy or
another file-based multiboot medium instead of changing the ISO for a
particular copy utility.

Raw-device imaging with `dd`, Etcher, or a comparable whole-image writer is a
different evidence shape because there is no mounted destination ISO file to
compare. This file-copy validator must not be advertised as proof for that
path; raw-device qualification requires a separately documented device-range
readback procedure.

This decision does not enable Archiso's `uefi.grub` boot mode, add the `grub`
package to the live ISO, create a full `/boot/grub/grub.cfg`, add BIOS support,
or activate the packaged installed-system GRUB theme. Those remain separate
installer and bootloader decisions.

## Ownership

- `iso/profiles/kde/grub/loopback.cfg` owns only live ISO loopback
  compatibility for outer GRUB/multiboot launchers.
- `iso/profiles/kde/airootfs/etc/mkinitcpio.conf.d/archiso.conf` owns the
  narrowly scoped live initramfs hook order required to consume loopback
  handoffs and then try SchweisOS' removable ISO-file fallback.
- `iso/profiles/kde/airootfs/usr/lib/initcpio/hooks/` and
  `iso/profiles/kde/airootfs/usr/lib/initcpio/install/` own only the
  SchweisOS-specific ISO-file fallback needed for multiboot command lines that
  use native Archiso search without `img_dev/img_loop`.
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

### Rely on Ventoy's Generated Menu or Mode Label

Rejected. A generated menu or visible mode label gives no guarantee about the
resulting handoff, while the observed kernel command line used native Archiso
search without a complete ISO-file handoff. The ISO must carry the
project-reviewed loopback contract itself, while runtime diagnosis must still
use the resulting kernel command line rather than assume which contract a
Ventoy label selected.

### Require Users to Select Ventoy GRUB2 Mode

Rejected as the only fix. The reviewed outer-GRUB loopback path remains
supported by `loopback.cfg`, but the failing command line used native Archiso
search without a complete ISO-file handoff. The menu label did not prove which
loader generated it. A production desktop ISO should not require users to know
Ventoy's alternate boot mode before the live system can start.

### Add Ventoy-Specific Runtime Integration

Deferred. Ventoy has distro-specific mechanisms for deeply integrated ISO-file
mounting, but adopting them would add a new downstream compatibility surface
and potential vendored tooling. The accepted hook is smaller: it relies only
on the Archiso marker already generated by `mkarchiso`, scans only removable
media, and delegates the actual live-root mount back to upstream Archiso.

### Move Kernel or Initramfs Paths

Rejected. The current kernel and initramfs locations match the Archiso
convention for the selected `install_dir` and architecture. Moving them would
increase drift from upstream Archiso and risk breaking the working native UEFI
path.

### Replace Native Entries with `archisolabel`

Rejected for this defect. The tested failure did not prove volume-label drift;
it proved that UUID-marker discovery failed, while static inspection separately
proved the initramfs omitted `archiso_loop_mnt`. Native systemd-boot continues
to use Archiso's `archisosearchuuid` marker contract. Completed ISO validation
verifies the real ISO volume label through `xorriso`, the UUID marker,
`grubenv`, and loader entry command lines so real drift is caught without
changing the native boot strategy.

## Consequences

Positive consequences:

- Outer-GRUB loopback launchers that consume the Archiso compatibility file
  receive an explicit, reviewed SchweisOS boot contract.
- The native systemd-boot path remains minimal, fast, and upstream-compatible.
- The loopback path mirrors the same normal/debug behavior as the native live
  entries, preserving debuggability.
- A file-based multiboot path using native Archiso search without an
  `img_dev/img_loop` handoff can recover because the initramfs can discover the
  ISO file containing the requested UUID marker on removable media.
- Kernel filename, initramfs filename, `install_dir`, architecture, Archiso
  ISO-file handoff, required hook drift, and raw marker discoverability are now
  statically validated.
- Completed ISO validation now checks the bootloader-visible ISO root, ISO
  volume label, UUID marker, native command lines, loopback command lines, and
  initramfs hook list before expensive SquashFS inspection.

Negative consequences:

- The live profile now contains a tiny `grub/` directory despite not using GRUB
  as its native bootloader. Validators must keep that directory restricted to
  `loopback.cfg`.
- The live profile now contains one SchweisOS-specific initramfs hook. Its
  maintenance cost is intentionally bounded by limiting it to removable media,
  marker-based ISO identification, and immediate delegation back to upstream
  Archiso.
- Static validation can prove ISO structure and handoff parameters, but only
  real Ventoy hardware testing can prove a specific firmware, USB device, and
  Ventoy version combination.
- Exact source-to-media verification reads the completed ISO twice and scans
  the destination filesystem for stale SchweisOS ISO copies before every
  attributed hardware test.

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
- the live mkinitcpio hook list omits `archiso_loop_mnt` after `archiso` or
  `schweisos_iso_file_fallback` after `archiso_loop_mnt`;
- the fallback hook scans non-removable disks before preserving upstream
  Archiso fallback;
- the fallback hook stops clearing `archisosearchuuid` and
  `archisosearchfilename` before delegating a discovered ISO loop device to
  upstream Archiso;
- the fallback hook reintroduces unconditional loop-module loading or adds an
  unused `modprobe` runtime dependency;
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
- the ISO UUID marker is not raw-discoverable by the initramfs fallback scan;
- the live initramfs omits `archiso_loop_mnt` or
  `schweisos_iso_file_fallback`;
- the live initramfs omits the binaries required by the fallback scan and loop
  setup;
- the live initramfs fallback hook performs unconditional loop-module loading;
- a full `boot/grub/grub.cfg` or syslinux configuration enters the image under
  the current UEFI-only live contract.

File-based multiboot media validation must fail closed if:

- the build manifest is not a successful clean completed build or does not
  describe the exact source ISO bytes;
- the manifest commit differs from the current clean validator checkout;
- the source ISO fails the current built identity or boot-composition
  contract;
- source and destination resolve to the same path or filesystem object;
- the destination medium is not mounted read-only;
- the destination is not on an available block-device filesystem distinct
  from the host root filesystem;
- the source or destination has a non-canonical or different basename;
- the destination medium contains zero or multiple SchweisOS ISOs;
- source and destination size, SHA256, or byte comparison differs.

Manual Ventoy hardware boot remains required release evidence. The evidence
must record the preceding synchronize, safe-unmount, physical-reinsert, and
read-only-remount procedure, identify the exact media-copy SHA256, and capture
`/proc/cmdline` or an equivalent debug log before assigning a result to the
outer-loopback or native search path. Passing these
validators means the repository no longer reproduces the known missing
loopback contracts behind the reported pre-kernel GRUB failure, the statically
proven missing `archiso_loop_mnt` defect, or the later native-search
device-discovery failure where `archiso_loop_mnt` was present but passive.
