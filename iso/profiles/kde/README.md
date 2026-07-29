# KDE Archiso Profile

This profile is the UEFI-first KDE live environment defined by ADR-012 and
ADR-014. Reusable SchweisOS behavior remains package-owned; `airootfs/`
contains only live-media exceptions that cannot yet be delivered by a package.

## Live Overlay Ownership

The following files are temporary live-media exceptions:

- `/etc/mkinitcpio.conf.d/archiso.conf` uses the upstream Archiso hook chain
  plus upstream `kms` and `plymouth` hooks so the initramfs can locate and mount
  the live root filesystem while showing the SchweisOS splash.
- `/etc/mkinitcpio.d/linux.preset` generates the initramfs path referenced by
  the UEFI loader entry.
- `/etc/plymouth/plymouthd.conf` selects the SchweisOS live Plymouth theme.
- `/etc/hostname` gives the ephemeral live system the portable hostname
  `schweisos`; installed-system hostnames remain an installer and user choice.
- `/etc/locale.conf` and `/etc/localtime` retain upstream Archiso's neutral
  `LANG=C.UTF-8` and UTC live defaults. Both loader entries also set
  `systemd.firstboot=no`, so generic first-boot questions cannot block SDDM;
  installed locale, keymap, timezone, and account choices remain
  installer-owned.
- `/etc/sysusers.d/schweisos-live.conf` declares the ephemeral `live` account
  without embedding a password or password hash.
- `/etc/tmpfiles.d/schweisos-live.conf` creates `/home/live` after the account
  exists.
- `/etc/sddm.conf.d/10-schweisos-live.conf` selects the packaged Plasma session
  and enables autologin for the ephemeral account.
- `/etc/systemd/system/display-manager.service` enables the packaged SDDM unit.
- `/etc/systemd/system/multi-user.target.wants/NetworkManager.service` enables
  the packaged NetworkManager unit for live networking.
- `/etc/systemd/system/schweisos-boot-debug-fallback.service` and its
  `emergency.target` and Plymouth unit drop-ins propagate otherwise ignored
  Plymouth client errors, bound quit waiting to 20 seconds, and quit Plymouth
  when graphical boot cannot continue, restoring the normal diagnostic
  console.
- `/etc/systemd/system/schweisos-plymouth-exit-watch.path` watches Plymouth's
  runtime directory, while `schweisos-plymouth-watchdog.service` checks
  liveness once per second only until successful handoff. Live-only helpers
  under `/usr/lib/schweisos-live/` retain the normal marker only after a
  successful retained-splash quit and reject stale PID files by checking for a
  live `plymouthd`; either detector starts the same diagnostic fallback. The
  watchdog accepts the handoff only when systemd reports `Result=success` and
  `ExecMainStatus=0` for `plymouth-quit.service`.
- `/etc/systemd/system/sddm.service.d/10-schweisos-debug-fallback.conf` reveals
  diagnostics if the live display manager fails before Plasma appears.
- `/usr/share/plymouth/themes/schweisos/` contains the live-only Plymouth theme.
  Its `ImageDir` points at `/usr/share/schweisos/branding`, which is installed
  by `schweisos-branding`; no logo asset is copied into the profile. The script
  uses a temporary reference-matched near-black stage aligned with the
  canonical logo edge tone, delayed logo fade-in, and five-dot circular chase
  loader sampled from the canonical `schweisos.png`, then clears the retained
  frame during the normal handoff.

The UEFI loader retains the firmware-selected console mode and shows exactly
`SchweisOS Live` and `SchweisOS Live (Debug)`. Automatic firmware/OS entries and
interactive kernel-command-line editing are disabled for the live medium.

These files must not be installed on a normal SchweisOS system because they
either define live-initramfs construction or create a passwordless automatic
live session, or define the live medium's ephemeral hostname. The mkinitcpio
files must exist before the kernel package creates the image. The remaining
files should move to a narrowly scoped, live-only package if one is designed
and approved later.

The three short Bash helpers are the only profile-owned executables. They are
live-only systemd helpers, not reusable installed-system behavior: one guards
the normal Plymouth quit marker, one checks whether a recorded PID still
belongs to a live `plymouthd`, and one performs the boot-bounded liveness
check. The overlay contains no custom binary, package
archive, copied branding asset, installer payload, first-run wizard, timezone
wizard, or secret. Keeping this README outside `airootfs/` prevents profile
documentation from being copied to `/README.md` in the live filesystem.

## Installer Integration

The profile includes the graphical installer only as signed package content:
`calamares`, `arch-install-scripts`, storage helpers, and
`schweisos-calamares-config` appear in `packages.x86_64`. The installer
configuration package owns `/etc/calamares`, the desktop launcher, pacstrap
target manifest, and installed-system helpers.

No installer configuration, Calamares module payload, target package manifest,
or installer launcher is allowed in `airootfs/`. The target system is installed
with `pacstrap`; it is not cloned from the live root.
