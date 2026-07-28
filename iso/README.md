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
- `packages.x86_64` lists the minimum Arch and SchweisOS packages for the
  planned KDE live environment.
- `pacman.conf` is used only while resolving packages for image assembly.
- `efiboot/` contains the systemd-boot loader configuration required by the
  selected upstream boot mode, including only the normal and debug live
  entries.
- `airootfs/` contains only the declarative plumbing required for an ephemeral
  KDE live account, SDDM autologin, NetworkManager startup, Plymouth selection,
  canonical-logo animation, and automatic diagnostic fallback.

The profile selects the upstream `uefi.systemd-boot` boot mode. Its
`efiboot/loader/` files are a small adaptation of the current upstream archiso
templates and use only archiso-supported template identifiers.
The text-oriented loader keeps the firmware console mode, disables automatic
entries and editing, and exposes `SchweisOS Live` plus
`SchweisOS Live (Debug)`. Graphical presentation begins in Plymouth.

Installer integration, KDE defaults, wallpapers, SDDM theming, and installed
system boot policy are intentionally absent. The live-only overlay and its
removal condition are documented in `profiles/kde/README.md`; documentation is
kept outside `airootfs/` so it is not copied into the live root filesystem.

## Repository Integration

The profile's `pacman.conf` uses Arch's normal mirrorlist for upstream
repositories and includes `/etc/pacman.d/schweisos.conf` for SchweisOS-owned
repositories. That include file is owned by `schweisos-pacman-config`; its
dependencies provide the SchweisOS keyring and mirrorlist.

A build host must install `schweisos-pacman-config` before running
`mkarchiso`. Its dependencies install `schweisos-keyring` and
`schweisos-mirrorlist`. The profile resolves the four Distribution Identity
Layer packages plus `schweisos-branding` from the configured SchweisOS
repository into the image.

The profile does not embed a repository URL, mirrorlist, signing key, or a copy
of the packaged repository snippet.

## Static Validation

From the repository root:

```sh
tests/validate-iso-profile.sh
git diff --check
```

The dedicated validator owns the complete profile contract, including package
ordering, permissions, UEFI normal/debug entries, Plymouth integration,
automatic diagnostic fallback, mkinitcpio inputs, airootfs minimality,
host-independent pacman parsing, symlink targets, and secret scanning.

The profile contract and repository-backed build path have produced a
development ISO on a canonical Arch build host. A clean build still requires
current Archiso tooling, the five signed live SchweisOS foundation packages,
the signed
repository database in release mode, and every validator to pass. Construction,
post-build SquashFS inspection, manual boot testing, installer testing, ISO
signing, and publication remain distinct release-engineering gates.
