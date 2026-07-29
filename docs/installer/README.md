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
- Live-session administration policy so the autologged-in live user can start
  the graphical installer and other administrative GUI tools without a root
  password prompt.
- Live desktop menu cleanup so only `Install SchweisOS` is shown, not
  Calamares' generic upstream `Install System` launcher.
- UEFI-only preflight policy.
- systemd-boot installed-system workflow.
- ext4 default filesystem with Btrfs as advanced optional filesystem support.
- Target package manifest for a minimal KDE Plasma daily-use system.
- Target pacman include configuration for the SchweisOS signed repository.
- Static installer configuration validator.

Not yet fully qualified:

- Graphical installation in the complete VM and hardware matrix.
- First boot of an installed system across the documented storage scenarios.

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
- Live passwordless sudo and polkit rules are live-media exceptions only; they
  must not be installed to the target system.
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
