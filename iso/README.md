# SchweisOS ISO Profiles

This directory owns the SchweisOS archiso profiles used to assemble live and
installation media. The profiles consume upstream Arch packages and published
SchweisOS packages; they do not build packages or define a separate ISO build
system.

The architecture and ownership rules are defined by
[ADR-012](../docs/adr/ADR-012-iso-build-architecture.md).

## Ownership Boundaries

- `iso/profiles/` owns image metadata, package composition, build-time pacman
  configuration, boot-loader inputs, and exceptional live-only overlay files.
- `packages/` owns reusable SchweisOS software and configuration. Files that
  need pacman ownership, updates, removal, or reuse outside the live image must
  be packaged there.
- `branding/` owns source artwork. No branding asset belongs directly in an ISO
  profile.
- `docs/` owns project documentation. Documentation intended for the live
  system should eventually be delivered by a package.

Each file has one canonical owner. An ISO profile must not copy package
payloads, project configuration, branding, or documentation from another
canonical location.

## Initial KDE Profile

`profiles/kde/` is the only profile currently defined. It is intentionally a
small upstream-compatible profile:

- `profiledef.sh` declares image metadata and UEFI systemd-boot policy.
- `packages.x86_64` lists the minimum Arch and SchweisOS packages for the KDE
  live environment and installer launcher.
- `pacman.conf` is used only while resolving packages for image assembly.
- `efiboot/` contains the systemd-boot loader configuration required by the
  selected upstream boot mode, including only the normal and debug live
  entries.
- `grub/loopback.cfg` contains the only approved GRUB profile file. Upstream
  `mkarchiso` copies it to `/boot/grub/loopback.cfg` so Ventoy-style outer
  GRUB loopback launchers can load the same kernel and initramfs while passing
  Archiso's `img_dev`/`img_loop` ISO-file handoff. It is not a native GRUB live
  boot configuration.
- `airootfs/` contains bounded live-only plumbing for an ephemeral KDE account,
  SDDM autologin, NetworkManager startup, passwordless local live-session
  administration, Plymouth selection, canonical-logo animation, neutral
  noninteractive first-boot defaults, and automatic diagnostic fallback. This
  includes three short audited Bash helpers whose behavior is meaningful only
  during live boot.

The profile selects the upstream `uefi.systemd-boot` boot mode. Its
`efiboot/loader/` files are a small adaptation of the current upstream archiso
templates and use only archiso-supported template identifiers.
The profile also carries the upstream Archiso loopback compatibility file for
multiboot launchers; no full `grub.cfg`, syslinux profile, BIOS path, or GRUB
package is part of the current live image.
The text-oriented loader keeps the firmware console mode, disables automatic
entries and editing, and exposes `SchweisOS Live` plus
`SchweisOS Live (Debug)`. The source contract configures graphical
presentation to begin in Plymouth.
Both entries disable interactive `systemd-firstboot`; the live overlay matches
upstream Archiso's `C.UTF-8` and UTC defaults and configures SDDM to hand the
ephemeral account directly to Plasma.

KDE defaults, wallpapers, SDDM theming, and installed-system boot policy are
intentionally absent from the profile. Installer integration is consumed only
through packages such as `calamares` and `schweisos-calamares-config`; no
installer payload is copied into `airootfs/`. The Calamares binary package
omits its generic launcher, while `schweisos-calamares-config` owns the single
visible launcher, once-only live autostart, and privilege/display bridge. The
live-only overlay and its removal condition are
documented in `profiles/kde/README.md`; documentation is kept outside
`airootfs/` so it is not copied into the live root filesystem.

## Repository Integration

The profile's `pacman.conf` uses Arch's normal mirrorlist for upstream
repositories and includes `/etc/pacman.d/schweisos.conf` for SchweisOS-owned
repositories. That include file is owned by `schweisos-pacman-config`; its
dependencies provide the SchweisOS keyring and mirrorlist.

A build host must install `schweisos-pacman-config` before running
`mkarchiso`. Its dependencies install `schweisos-keyring` and
`schweisos-mirrorlist`. The profile resolves the four Distribution Identity
Layer packages, `schweisos-branding`, and package-owned SchweisOS installer
configuration from the configured SchweisOS repository into the image. Because
Arch official repositories do not provide Calamares in the evaluated
environment, installer ISO builds also require an admitted signed Calamares
package in an approved SchweisOS repository.

The profile does not embed a repository URL, mirrorlist, signing key, or a copy
of the packaged repository snippet.

## Static Validation

From the repository root:

```sh
tests/validate-iso-profile.sh
tests/test-plymouth-watchdog.sh
git diff --check
```

The dedicated validator owns the complete profile contract, including package
ordering, permissions, UEFI normal/debug entries, Plymouth integration,
automatic diagnostic fallback, GRUB loopback compatibility, mkinitcpio inputs,
airootfs minimality, host-independent pacman parsing, symlink targets, and
secret scanning.

`tests/test-plymouth-watchdog.sh` exercises the real watchdog control flow with
disposable command stubs. It verifies successful and in-progress normal
handoff, failed handoff, absent and later-stopped daemons, and propagation of
health-helper and systemd-query errors. It does not boot an image or claim that
a renderer displayed pixels.

`tests/validate-iso-loopback-boot.sh`, `tests/validate-built-iso-identity.sh`,
and `tests/validate-built-iso-boot.sh` are complementary post-build gates. On a
completed image the loopback validator inspects only the bootloader-visible ISO
root and proves the kernel, initramfs, EFI image, boot catalog, systemd-boot
entries, and `/boot/grub/loopback.cfg` handoff before the more expensive
SquashFS checks. The built identity and built boot validators then extract the
SquashFS and initramfs and prove the effective distribution identity, signed
branding package version, canonical logo, Plymouth script/runtime, first-boot
defaults, systemd fallback units, installer runtime payload, and Plasma
handoff inputs. The wrapper requires the post-build gates before publishing
checksums.

There is no current successful ISO evidence for the newly changed first-boot
payload, Plymouth watchdog, built-boot validator, or exact v2 manifest
contract. A fresh production-host build must create that evidence later. The
older local ISO and its failed or legacy manifests do not validate the current
profile. A clean build still requires current Archiso tooling, the signed live
SchweisOS foundation packages, the signed installer configuration package, an
admitted Calamares package, the signed repository database in release mode, and
every validator to pass. Installer configuration validation, construction,
both post-build inspections, manual boot testing, installer testing, ISO
signing, and publication remain distinct release-engineering gates.
