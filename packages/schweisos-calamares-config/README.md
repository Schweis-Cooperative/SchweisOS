# schweisos-calamares-config

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Installer MVP configuration source
Date: 2026-07-29

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
- `/etc/calamares/modules/*.conf` for SchweisOS installer policy
- `/usr/bin/schweisos-installer`
- `/usr/lib/schweisos-calamares/*`
- `/usr/share/applications/schweisos-installer.desktop`
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
