# SchweisOS Packaging Guide

Version: 0.1
Status: Draft
Date: 2026-07-24

## Goal

SchweisOS packaging exists to add a small distribution layer on top of Arch, not to rebuild Arch.

## Package Policy

Allowed early packages:

- Release identity.
- Keyring.
- Mirror list.
- pacman repository configuration.
- Installer configuration.
- Desktop defaults.
- Small meta packages.
- Documentation packages.

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

References: [PKGBUILD manual](https://man.archlinux.org/man/PKGBUILD.5.en), [PKGBUILD - ArchWiki](https://wiki.archlinux.org/title/PKGBUILD).

## Repository Policy

The SchweisOS binary repository must be signed. Packages should be promoted through clear stages:

1. Local build.
2. Local install test.
3. VM install test.
4. Repository staging.
5. Signed release repository.

## Meta Package Policy

Meta packages are preferred for optional feature groups because they avoid patching upstream packages.

Examples:

- `schweisos-gaming-meta`
- `schweisos-flatpak-meta`
- `schweisos-distrobox-meta`

Meta packages must not pull in controversial or high-risk components without documentation.
