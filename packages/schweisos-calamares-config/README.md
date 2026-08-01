# schweisos-calamares-config

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.4
Status: Installer MVP configuration and runtime launch integration
Date: 2026-07-30

`schweisos-calamares-config` provides the SchweisOS-owned configuration and
launcher for the graphical installer selected by ADR-016.

The package configures Calamares on the live ISO. It is not intended to remain
installed in the target system. The target system is installed through
Calamares partition and mount modules plus a SchweisOS-owned `pacstrap`
shellprocess. This avoids copying the live root filesystem and prevents
live-only Archiso files, autologin, Plymouth fallback units, or installer
payload from becoming installed-system state.

The installer starts from neutral UTC/default-locale configuration and does
not perform GeoIP lookup. Locale, timezone, keymap, hostname, and user creation
remain explicit user choices in the graphical flow.

## Ownership

This package owns:

- `/etc/calamares/settings.conf`
- `/etc/calamares/branding/schweisos/branding.desc`
- `/etc/calamares/branding/schweisos/show.qml`
- `/etc/calamares/modules/*.conf` for SchweisOS installer policy
- `/usr/bin/schweisos-installer`
- `/usr/lib/schweisos-calamares/*`, including the exact-path privileged
  XWayland bridge and once-only live autostart helper
- `/usr/share/applications/schweisos-installer.desktop`
- `/etc/xdg/autostart/schweisos-installer-autostart.desktop`
- `/usr/share/polkit-1/actions/org.schweisos.installer.policy`
- `/usr/share/schweisos/calamares/target-packages.x86_64`
- `/usr/share/schweisos/calamares/pacman.conf`

It does not own Calamares itself, fork Calamares modules, patch pacman, install
bootloaders outside installer context, build packages, sign repositories,
publish mirrors, configure Secure Boot, configure full-disk encryption, or
activate the packaged GRUB theme.

## MVP Install Contract

The accepted MVP path is:

```text
Live ISO
  -> Calamares
  -> UEFI validation
  -> partition and mount target
  -> pacstrap signed Arch and SchweisOS packages
  -> configure target pacman include
  -> install systemd-boot
  -> enable NetworkManager and SDDM
  -> user-created Plasma desktop
```

The default filesystem is ext4. Btrfs is exposed as an advanced filesystem
choice only when the live installer environment provides `btrfs-progs`; no
snapshot or rollback promise is made in this phase.

The default bootloader is systemd-boot on UEFI. GRUB remains a documented
future/alternative installed-system path and is not activated by this package.

## Live Launch Contract

The package owns the only visible installer entry. The separately packaged
Calamares binary omits its generic upstream desktop entry, so no profile-level
desktop-file override or menu-cache behavior is part of the contract.

The hidden XDG autostart entry runs only for the `live` Archiso session and
attempts one launch about three seconds after Plasma starts. State in the
ephemeral live home prevents automatic reopening after the installer is
closed. Manual use of `Install SchweisOS` remains available.

Autostart and the public launcher share
`/usr/lib/schweisos-calamares/is-live-session`. It requires the `live` user,
the exact `/usr/lib/schweisos-live/session` profile marker, a mounted
`/run/archiso/airootfs`, and `archisobasedir=schweis` on the kernel command
line. It intentionally ignores `/run/archiso/bootmnt`: upstream Archiso removes
that transient mount after a healthy `copytoram=auto` transition. The
multi-signal check prevents the live-only marker from authorizing an installed
system by itself.

Calamares 3.4 requires a privileged UI. The exact-path Polkit helper accepts no
arguments, sanitizes loader and Qt plugin environment variables, and selects
Qt's `xcb` backend over packaged XWayland. The public wrapper checks UEFI and
display authorization, prevents concurrent instances, captures a private
launch log, and displays a KDE error dialog for launch or runtime failures.

The branding component includes both the required `slideshow` key in
`branding.desc` and a package-owned `show.qml` resource. The welcome page uses
Calamares' compact `productBanner` image and deliberately omits the large
centered `productWelcome` image, so the installer presents SchweisOS as a
professional product rather than a splash screen inside the wizard. All
installer artwork still references only the canonical runtime SchweisOS logo at
`/usr/share/schweisos/branding/schweisos.png`.

The QML slideshow is text-first, loaded by Calamares during execution pages,
and carries the current contributors list. The initial list contains `Marijua`
and is intentionally data-local to the package so future contributors can be
added without duplicating artwork or changing installer launch policy.

The welcome page deliberately does not require Calamares' internet probe.
That probe can false-negative independently of the user's actual network
state and would block a usable live session before any installer-owned package
operation starts. Package retrieval remains owned by the audited `pacstrap`
step and its signed pacman configuration, so repository availability failures
must surface where package installation actually occurs.

Full offline installation is not claimed by this package while the MVP uses
`pacstrap` against configured repositories. A true offline contract requires a
separate accepted architecture, such as an ISO-contained signed installation
repository or a reviewed live-root deployment path with exhaustive live-state
cleanup.

## Calamares Binary Package

Arch official repositories do not provide Calamares in the current evaluated
environment. SchweisOS therefore must admit a reviewed Calamares binary package
to the signed SchweisOS repository before an installer ISO can be built from
this configuration. This configuration package intentionally depends on
`calamares` so package resolution fails closed until that dependency is
available from an approved repository source.

Validation:

```bash
tests/validate-installer-config.sh
```
