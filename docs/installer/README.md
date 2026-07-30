# SchweisOS Installer

Version: 0.3
Status: Faz 1 source implementation; runtime qualification pending
Date: 2026-07-30

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
- Package-level launcher ownership so only `Install SchweisOS` exists; the
  Calamares binary package omits upstream's generic `Install System` entry.
- Hidden XDG autostart approximately three seconds after the first live Plasma
  session, with a persistent-per-boot attempt marker and manual reopen support.
- Shared fail-closed live-session detection based on the live account, a
  profile-owned marker, the persistent Archiso `airootfs` mount, and the
  SchweisOS kernel contract. It does not depend on the transient Archiso
  `bootmnt`, which is absent after a successful copy-to-RAM boot.
- Exact-path Polkit and XWayland bridge for the privileged Calamares 3.4 UI.
- Single-instance locking, UEFI/display/component preflight, a private local
  launch log, and a visible KDE error dialog on startup failure.
- UEFI-only preflight policy.
- systemd-boot installed-system workflow.
- ext4 default filesystem with Btrfs as advanced optional filesystem support.
- Target package manifest for a minimal KDE Plasma daily-use system.
- Target pacman include configuration for the SchweisOS signed repository.
- Static installer configuration validator.
- Behavioral launcher and autostart regression tests.
- The welcome screen no longer blocks on Calamares' generic internet probe;
  package availability errors are owned by the signed package installation
  step.

Not yet fully qualified:

- Graphical installation in the complete VM and hardware matrix.
- First boot of an installed system across the documented storage scenarios.
- Complete offline installation. The current MVP uses `pacstrap` from signed
  repositories; without an ISO-contained signed installation repository, a
  disconnected install cannot be honestly claimed.

## Runbooks

- [Manual Installation Runbook](manual-installation-runbook.md)
- [Recovery Runbook](recovery-runbook.md)

## Installer Flow

```text
Live ISO
  -> first live Plasma session
  -> one-time delayed Install SchweisOS autostart
  -> guarded Install SchweisOS launcher
  -> exact-path Polkit / XWayland bridge
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
- Automated storage does not expose LUKS or LVM until their boot and recovery
  contracts are implemented.
- Calamares' welcome module must not be the network gate. If package retrieval
  is unavailable, the audited package installation step must report that real
  failure.
- Secure Boot, full-disk encryption, snapshots, and rollback are future
  decisions.

## Launch State and Diagnostics

The first-session attempt marker, single-instance lock, launch marker, and log
are stored under `$XDG_STATE_HOME/schweisos-installer`, defaulting to
`~/.local/state/schweisos-installer`. Closing Calamares never schedules another
automatic launch. The application-menu entry remains usable for a manual retry.

When preflight, Polkit, XWayland, or Calamares startup fails, a KDE dialog
identifies `launch.log`. The summary is also written to the journal when
available. No diagnostic data leaves the machine.

The launcher and autostart both call
`/usr/lib/schweisos-calamares/is-live-session`. A copied-to-RAM live session is
valid even when `/run/archiso/bootmnt` has been removed by Archiso; the
persistent `/run/archiso/airootfs` mountpoint remains required. This avoids
bootloader-specific heuristics while still rejecting installed systems.

## Validation

From the repository root:

```bash
tests/validate-installer-config.sh
tests/test-installer-experience.sh
tests/validate-iso-profile.sh
git diff --check
```

These static checks do not replace ISO, VM, or hardware installation testing.
