# SchweisOS Testing Strategy

Version: 0.5
Status: Draft
Date: 2026-07-28

## Goal

Testing must be realistic for a one-developer distribution. The first test suite should catch broken boots, broken installs, broken package trust, and obvious desktop regressions.

## Test Levels

- Documentation review: decisions and limitations are current.
- Package linting: PKGBUILDs reviewed with Arch tooling where practical.
- VM smoke tests: ISO boots, installer starts, installation completes.
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

## Gaming Validation

Gaming validation must focus on observable behavior, not vague performance claims:

- GPU driver present.
- Vulkan tools report expected device.
- Steam starts.
- A Proton title can launch in a controlled test environment where licensing permits.
- GameMode can be detected when enabled.
- MangoHud overlay can be toggled.

No gaming tweak becomes default without a documented before/after test.
