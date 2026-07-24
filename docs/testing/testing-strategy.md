# SchweisOS Testing Strategy

Version: 0.1
Status: Draft
Date: 2026-07-24

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

## Manual Test Evidence

Each release candidate should record:

- ISO filename and checksum.
- Host machine used for build.
- VM configuration.
- Install path selected.
- Result.
- Known failures.

## Gaming Validation

Gaming validation must focus on observable behavior, not vague performance claims:

- GPU driver present.
- Vulkan tools report expected device.
- Steam starts.
- A Proton title can launch in a controlled test environment where licensing permits.
- GameMode can be detected when enabled.
- MangoHud overlay can be toggled.

No gaming tweak becomes default without a documented before/after test.
