# schweisos-release

Version: 0.2
Status: Development identity implementation
Date: 2026-07-25

`schweisos-release` provides SchweisOS distribution identity metadata.

It is intentionally small. It does not configure package repositories, install signing keys, configure mirrors, install desktop defaults, enable Flatpak, configure AUR helpers, configure Distrobox, build an ISO, or apply performance tuning.

This package exists separately from the other Distribution Identity Layer packages because identifying the operating system is not the same responsibility as trusting packages, discovering mirrors, or configuring pacman repositories.

## Installed Layout

- `/usr/lib/schweisos-release/os-release`
- `/usr/lib/schweisos-release/release.json`
- `/etc/os-release` -> `../usr/lib/schweisos-release/os-release`

Source files:

- `os-release`
- `release.json`
- `PKGBUILD`

The package does not install an `.install` script and does not rewrite files at
installation time. It owns a relative `/etc/os-release` symlink to its canonical
metadata. The standard `os-release` lookup gives `/etc/os-release` precedence,
so systemd, KDE, and other consumers identify the system as SchweisOS.

Arch's `filesystem` package continues to own `/usr/lib/os-release` as the
upstream fallback. SchweisOS does not replace or fork that package. During an
Archiso build, upstream `mkarchiso` resolves `/etc/os-release` and appends the
profile-derived `IMAGE_ID` and `IMAGE_VERSION` to the SchweisOS-owned metadata.

## Boundaries

`schweisos-release` must not own:

- package signing keys
- mirror endpoints
- pacman repository snippets
- desktop or branding assets
- installer configuration
- update behavior
- performance tuning
- telemetry or bug-report automation

## Validation

From this directory:

```bash
bash -n PKGBUILD
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-release-0.2.0-1-any.pkg.tar.* | sort
```

Expected package payload:

```text
etc/os-release
usr/lib/schweisos-release/os-release
usr/lib/schweisos-release/release.json
```

Optional local install testing should happen only in a disposable VM or container.
