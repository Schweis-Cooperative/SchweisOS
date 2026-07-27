# SchweisOS Testing Strategy

Version: 0.3
Status: Draft
Date: 2026-07-27

## Goal

Testing must be realistic for a one-developer distribution. The first test suite should catch broken boots, broken installs, broken package trust, and obvious desktop regressions.

## Test Levels

- Documentation review: decisions and limitations are current.
- Package linting: PKGBUILDs reviewed with Arch tooling where practical.
- VM smoke tests: ISO boots, installer starts, installation completes.
- Installed-system tests: bootloader works, user can log in, updates work.
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
- disposable-root validation installs the five local package files in one
  isolated pacman transaction without using host configuration or keyrings

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
package set before a VM or hardware test begins.

## Known Validator Reconciliation

`tests/validate-built-iso-identity.sh` currently requires the effective
SchweisOS `os-release` in the built image to be byte-for-byte equal to the
package source. ADR-009 also records upstream Archiso's supported behavior of
appending `IMAGE_ID` and `IMAGE_VERSION` to the resolved identity file. These
contracts cannot both hold when Archiso adds the fields. The validator must be
changed to compare the package-owned canonical fields while separately
validating the two Archiso image fields. Until that correction is reviewed,
manual SquashFS evidence does not make the contradictory automated check a
valid release gate.

## Gaming Validation

Gaming validation must focus on observable behavior, not vague performance claims:

- GPU driver present.
- Vulkan tools report expected device.
- Steam starts.
- A Proton title can launch in a controlled test environment where licensing permits.
- GameMode can be detected when enabled.
- MangoHud overlay can be toggled.

No gaming tweak becomes default without a documented before/after test.
