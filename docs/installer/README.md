# SchweisOS Installer

Version: 0.1
Status: Faz 1 source architecture
Date: 2026-07-29

SchweisOS Faz 1 introduces the source architecture for the first installable
MVP. The accepted graphical installer is Calamares, configured by the
package-owned `schweisos-calamares-config` package.

Canonical decision: [ADR-016 Installer Architecture](../adr/ADR-016-installer-architecture.md)

## Current Scope

Implemented in source:

- Calamares configuration package source.
- Live ISO package composition for installer packages.
- UEFI-only preflight policy.
- systemd-boot installed-system workflow.
- ext4 default filesystem with Btrfs as advanced optional filesystem support.
- Target package manifest for a minimal KDE Plasma daily-use system.
- Target pacman include configuration for the SchweisOS signed repository.
- Static installer configuration validator.

Not yet proven:

- Calamares binary package availability from a signed SchweisOS repository.
- ISO build containing the installer.
- Graphical installation in VM or hardware.
- First boot of an installed system.

## Runbooks

- [Manual Installation Runbook](manual-installation-runbook.md)
- [Recovery Runbook](recovery-runbook.md)

## Installer Flow

```text
Live ISO
  -> Install SchweisOS launcher
  -> Calamares
  -> UEFI preflight
  -> partition and mount
  -> pacstrap target packages
  -> configure target pacman include
  -> install systemd-boot
  -> enable NetworkManager and SDDM
  -> reboot into installed Plasma system
```

## Important Boundaries

- The live root is not cloned into the target.
- Installer payload must not live in `airootfs/`.
- The installer does not build or sign packages.
- The installer does not weaken pacman signature policy.
- The installer does not activate GRUB in the MVP.
- Secure Boot, full-disk encryption, snapshots, and rollback are future
  decisions.

## Validation

From the repository root:

```bash
tests/validate-installer-config.sh
tests/validate-iso-profile.sh
git diff --check
```

These static checks do not replace ISO, VM, or hardware installation testing.
