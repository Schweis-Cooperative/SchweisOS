# SchweisOS Packaging Guide

Version: 0.5
Status: Draft
Date: 2026-07-29

## Goal

SchweisOS packaging exists to add a small distribution layer on top of Arch, not to rebuild Arch.

## Package Policy

Current packages:

- `schweisos-release`: distribution identity and version metadata.
- `schweisos-keyring`: admitted production public trust only.
- `schweisos-mirrorlist`: SchweisOS repository discovery.
- `schweisos-pacman-config`: SchweisOS-owned pacman policy/include.
- `schweisos-branding`: minimal runtime logo assets sourced only from
  `branding/assets/logo/schweisos.png`; standard icon lookup paths are aliases
  to one package-owned runtime payload.
- `schweisos-grub-theme`: inert reusable GRUB theme behavior and non-logo
  decoration; its runtime logo is an alias to the payload owned by
  `schweisos-branding`, and activation remains installer-owned.
- `schweisos-calamares-config`: Calamares settings, installer launcher,
  target package manifest, pacstrap policy, and installer-owned
  installed-system integration helpers for the Faz 1 MVP.

Allowed next packages:

- Desktop defaults.
- Small meta packages.
- Documentation packages.

Calamares itself is a separate package-admission problem. It is not vendored
into the configuration package or ISO profile. If Arch official repositories do
not provide it for the release environment, SchweisOS must admit a reviewed
Calamares binary package through the signed repository workflow before an
installer ISO can be built.

Bootloader presentation packages must not install a bootloader, edit its
global configuration, regenerate boot entries, or choose a firmware path from
an install hook. Those actions require installer context and an accepted ADR.

Avoid early packages:

- Forked kernels.
- Forked Mesa, KDE, systemd, pacman, or core libraries.
- Repackaged `.deb` or `.rpm` software.
- Packages that exist only to apply undocumented tuning.

## PKGBUILD Standards

SchweisOS packages must follow Arch packaging conventions. PKGBUILDs are Bash build descriptions interpreted by makepkg and should use normal Arch variables and package functions.

Minimum expectations:

- Clear `pkgname`, `pkgver`, `pkgrel`, `pkgdesc`, `arch`, `url`, and `license`.
- Reproducible sources where possible.
- No network access during build functions.
- `namcap` review before repository publication when practical.
- No hidden telemetry, remote configuration, or post-install surprises.
- Every installed path has one package owner; package boundaries must not
  overlap.
- Private keys, operational secret-key exports, fake fingerprints, and
  development trust anchors are prohibited package sources.
- Package versions admitted to a release repository must match the reviewed
  source and be signed by the authorized package role.

References: [PKGBUILD manual](https://man.archlinux.org/man/PKGBUILD.5.en), [PKGBUILD - ArchWiki](https://wiki.archlinux.org/title/PKGBUILD).

## Repository Policy

The SchweisOS binary repository is signed. Packages are promoted through clear
stages:

1. Local build.
2. Package and payload validation.
3. Package-role signing and immediate verification.
4. Atomic repository candidate construction with `repo-add`.
5. Database-role signing and immediate verification.
6. Complete repository validation.
7. Disposable pacman trust validation.
8. Atomic build-repository activation.

The unsigned local bootstrap repository is only a package-coexistence
development tool. It must never be promoted, mirrored, or relabeled as a
release repository.

## Meta Package Policy

Meta packages are preferred for optional feature groups because they avoid patching upstream packages.

Examples:

- `schweisos-gaming-meta`
- `schweisos-flatpak-meta`
- `schweisos-distrobox-meta`

Meta packages must not pull in controversial or high-risk components without documentation.
