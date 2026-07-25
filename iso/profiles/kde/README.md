# KDE Archiso Profile

This profile is the minimal UEFI-first KDE live environment defined by
ADR-012. Reusable SchweisOS behavior remains package-owned; `airootfs/`
contains only live-media exceptions that cannot yet be delivered by a package.

## Live Overlay Ownership

The following files are temporary live-media exceptions:

- `/etc/mkinitcpio.conf.d/archiso.conf` uses the upstream Archiso hook chain so
  the initramfs can locate and mount the live root filesystem.
- `/etc/mkinitcpio.d/linux.preset` generates the initramfs path referenced by
  the UEFI loader entry.
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

These files must not be installed on a normal SchweisOS system because they
either define live-initramfs construction or create a passwordless automatic
live session, or define the live medium's ephemeral hostname. The mkinitcpio
files must exist before the kernel package creates the image. The remaining
files should move to a narrowly scoped, live-only package if one is designed
and approved later.

All executable behavior remains in upstream packages. The overlay contains no
scripts, binaries, package archives, branding, installer payload, or secrets.
Keeping this README outside `airootfs/` prevents profile documentation from
being copied to `/README.md` in the live filesystem.
