# SchweisOS Installer

Version: 0.5
Status: Faz 1 source implementation; runtime qualification pending
Date: 2026-08-02

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
- Active live-boot-media filtering so the USB or file-backed medium that
  started the live system is not exposed as an installation target.
- Target package manifest for a minimal KDE Plasma daily-use system.
- Fixed Firefox browser payload, mandatory installation-profile selection, and
  mandatory kernel selection, with Privacy and Linux Zen as the documented
  defaults.
- Optional, described software groups backed entirely by packages already on
  the live medium.
- Target pacman include configuration for the SchweisOS signed repository.
- Offline target creation through upstream Calamares `unpackfs`, followed by a
  fail-closed SchweisOS reconciliation step that removes unselected and
  live-only state.
- Text-first welcome presentation, SchweisOS-owned network status with
  Calamares fallback, and explicit `Maintained by Marijua` project identity.
- Full upstream IANA timezone data through Arch's `tzdata` package.
- Static installer configuration validator.
- Behavioral launcher and autostart regression tests.
- Internet connectivity is never a requirement; offline installation uses the
  complete signed payload already present in the live root.

Not yet fully qualified:

- Graphical installation in the complete VM and hardware matrix.
- First boot of an installed system across the documented storage scenarios.
- Runtime qualification of every kernel and optional-feature combination. The
  source contract and offline payload are implemented, but a static validator
  is not installation-completion evidence.

## Runbooks

- [Manual Installation Runbook](manual-installation-runbook.md)
- [Recovery Runbook](recovery-runbook.md)
- [Package Selection Contract](package-selection.md)
- [Installer Developer Guide](developer-guide.md)

## Installer Flow

```text
Live ISO
  -> first live Plasma session
  -> one-time delayed Install SchweisOS autostart
  -> guarded Install SchweisOS launcher
  -> exact-path Polkit / XWayland bridge
  -> Calamares
  -> UEFI preflight
  -> kernel and optional-feature selection
  -> partition and mount
  -> unpack the signature-verified live root
  -> reconcile packages and remove exact live-only state
  -> configure target pacman include
  -> install systemd-boot
  -> enable NetworkManager and SDDM
  -> reboot into installed Plasma system
```

## Important Boundaries

- The verified live root is copied with upstream `unpackfs`, then reconciled
  before target configuration. Copying without the mandatory reconciliation
  step is invalid.
- Installer payload must not live in `airootfs/`.
- Live passwordless sudo and polkit rules are live-media exceptions only; they
  must not be installed to the target system.
- The installer does not build or sign packages.
- The installer does not weaken pacman signature policy.
- The installer does not activate GRUB in the MVP.
- Automated storage does not expose LUKS or LVM until their boot and recovery
  contracts are implemented.
- The medium that booted the live system is not a supported target disk. If you
  boot from Ventoy or another USB, install to an internal disk or a different
  removable disk. The active boot disk must not appear in Calamares' target
  list.
- Calamares' welcome page reports connectivity from
  `/run/schweisos-installer/network-state` when available and falls back to
  Calamares' own network signal. Connectivity must never be a requirement.
  Package choice and target creation work offline from the ISO payload; later
  repository access remains governed by pacman trust policy.
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
