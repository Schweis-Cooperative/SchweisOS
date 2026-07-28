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
  `emergency.target` and Plymouth unit drop-ins quit Plymouth when graphical
  boot cannot continue, restoring the normal diagnostic console.
- `/etc/systemd/system/schweisos-plymouth-exit-watch.path` watches Plymouth's
  runtime directory. If the PID is absent before the normal quit handoff marker,
  it starts the same diagnostic fallback.
- `/etc/systemd/system/sddm.service.d/10-schweisos-debug-fallback.conf` reveals
  diagnostics if the live display manager fails before Plasma appears.
- `/usr/share/plymouth/themes/schweisos/` contains the live-only Plymouth theme.
  Its `ImageDir` points at `/usr/share/schweisos/branding`, which is installed
  by `schweisos-branding`; no logo asset is copied into the profile. The script
  fades in and gently pulses the canonical `schweisos.png`, then derives its
  rotating dot indicator from that same image.

The UEFI loader retains the firmware-selected console mode and shows exactly
`SchweisOS Live` and `SchweisOS Live (Debug)`. Automatic firmware/OS entries and
interactive kernel-command-line editing are disabled for the live medium.

These files must not be installed on a normal SchweisOS system because they
either define live-initramfs construction or create a passwordless automatic
live session, or define the live medium's ephemeral hostname. The mkinitcpio
files must exist before the kernel package creates the image. The remaining
files should move to a narrowly scoped, live-only package if one is designed
and approved later.

All executable behavior remains in upstream packages and systemd units. The
overlay contains no custom binaries, package archives, copied branding assets,
installer payload, first-run wizard, timezone wizard, or secrets. Keeping this
README outside `airootfs/` prevents profile documentation from being copied to
`/README.md` in the live filesystem.
