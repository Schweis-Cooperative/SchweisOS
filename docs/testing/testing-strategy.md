# SchweisOS Testing Strategy

Version: 0.7
Status: Draft
Date: 2026-08-02

## Goal

Testing must be realistic for a one-developer distribution. The first test suite should catch broken boots, broken installs, broken package trust, and obvious desktop regressions.

## Test Levels

- Documentation review: decisions and limitations are current.
- Package linting: PKGBUILDs reviewed with Arch tooling where practical.
- VM smoke tests: ISO boots, installer starts, installation completes.
- Installer static validation: Calamares package configuration, target package
  manifest, pacstrap policy, and installed-system systemd-boot helpers are
  internally consistent before an ISO is built.
- Installed-system tests: bootloader works, user can log in, updates work.
- GRUB theme static validation: canonical logo ownership, inert packaging,
  required theme components, and absence from the systemd-boot live profile.
- Gaming smoke tests: Steam launches, Vulkan info is available where supported, MangoHud/GameMode behavior can be checked.
- Hardware tests: real machines added gradually.
- Regression tests: issues become checklist items after fixes.

## Initial VM Matrix

- UEFI VM, ext4, systemd-boot.
- UEFI VM, Btrfs option.
- UEFI VM, GRUB alternative once implemented.

Legacy BIOS is not required for the first release.

QEMU installation tests must attach a writable target disk. A command that only
passes `-cdrom schweisos-YYYY.MM.DD-x86_64.iso` is a boot-only test and should
produce no installable target. Use
[`docs/testing/qemu.md`](qemu.md) for the canonical QEMU installation command.

## Repository Bootstrap Tests

Repository bootstrap validation has three deliberately separate levels:

- static package-boundary validation checks PKGBUILDs, payload ownership,
  pacman snippets, and signature policy
- local repository validation checks the generated local `schweisos` layout,
  exact package membership, and `repo-add` database references
- disposable-root validation installs the five live/repository foundation
  package files in one isolated pacman transaction without using host
  configuration or keyrings; optional installed-system packages are validated
  separately

The disposable local-file test proves package compatibility, not production
trust. The separate signed-repository client test bootstraps the admitted
SchweisOS public trust, keeps Arch trust for upstream dependencies, requires
trusted package and database signatures, and verifies wrong-role rejection.

## Manual Test Evidence

Each release candidate should record:

- ISO filename and checksum.
- Host machine used for build.
- VM configuration.
- Install path selected.
- Result.
- Known failures.

Post-build SquashFS inspection is mandatory but does not replace a boot test.
It must verify the installed `schweisos-release` version, effective
`/etc/os-release` link and fields, package ownership, and the expected live
package set before a VM or hardware test begins. It must also inspect the built
initramfs for the selected Plymouth theme, script runtime, and exact canonical
logo, and verify that live first-boot defaults cannot interrupt the SDDM/Plasma
handoff.

## Built-ISO Identity Contract

`tests/validate-built-iso-identity.sh` validates the installed
`schweisos-release` package and the live image identity contract together. The
installed package identity remains byte-for-byte package-owned; the built ISO
identity must equal that package identity plus exactly the upstream Archiso
`IMAGE_ID` and `IMAGE_VERSION` fields derived from the validated profile.
Because the check extracts the ISO SquashFS, it uses the ignored repository
`work/validators/built-iso-identity/` directory by default rather than assuming
that `/tmp` has enough space for a full live root filesystem. Build hosts may set
`TMPDIR` to another disk-backed disposable location. The check does not restore
SquashFS xattrs while extracting because it is an unprivileged identity and
package-metadata gate, not a Linux capability/xattr policy gate. Manual SquashFS
evidence may support investigation, but it does not replace the automated
post-build validator.

## Built-ISO Boot Composition Contract

`tests/validate-built-iso-boot.sh` closes the gap between reviewed source and
the signed package versions selected by pacman. It checks the built
systemd-boot entries, installed branding record and payload hash, live
locale/timezone defaults, systemd fallback units, Plasma session, and the
actual initramfs contents. It also runs `systemd-analyze verify` against the
merged unit set in the extracted live root.

This gate proves composition, not pixels or successful hardware initialization.
A VM and hardware boot remain necessary to observe animation, renderer
selection, SDDM autologin, and the final Plasma desktop.

## File-Based Boot Media Evidence

Before a Ventoy or other file-based multiboot hardware test, run:

```bash
tests/validate-boot-media-copy.sh \
  logs/iso/build-manifest.json \
  out/iso/schweisos-YYYY.MM.DD-x86_64.iso \
  /path/to/mounted-media/schweisos-YYYY.MM.DD-x86_64.iso
```

Before invoking the read-only gate, copy the ISO, run `sync`, safely unmount
the medium, physically reinsert it, and mount the data partition read-only.
The gate then binds the copied bytes to the successful clean build manifest
and current clean repository commit, reruns the current built-ISO identity and
boot-composition validators, rejects a source/destination alias, requires a
read-only block-device-backed destination different from the host root
filesystem, and permits exactly one SchweisOS ISO on that filesystem. Safely
unmount it again before booting. It is not a raw-device readback validator for
`dd`, Etcher, or similar whole-image writers; use `scripts/test-dd.sh` for the
read-only prefix-hash evidence after a whole-image write.

Before attributing a boot failure to current source, run:

```bash
scripts/test-iso.sh out/iso/schweisos-YYYY.MM.DD-x86_64.iso
```

This wrapper includes `schweisos-doctor`, which checks embedded
`airootfs.sfs` SHA512, SquashFS superblock metadata with live-media xattrs
disabled, checksum-enabled command lines, installed package versions, and
Calamares welcome policy. A stale ISO or a stale media copy is not
current-source evidence.

The subsequent hardware record must capture the exact ISO SHA256 and
`/proc/cmdline` (or equivalent debug evidence). A Ventoy menu label is not
evidence of which kernel-command-line handoff actually ran.

## Gaming Validation

Gaming validation must focus on observable behavior, not vague performance claims:

- GPU driver present.
- Vulkan tools report expected device.
- Steam starts.
- A Proton title can launch in a controlled test environment where licensing permits.
- GameMode can be detected when enabled.
- MangoHud overlay can be toggled.

No gaming tweak becomes default without a documented before/after test.
