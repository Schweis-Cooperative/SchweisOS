# schweisos-release

Version: 0.1
Status: Initial package implementation
Date: 2026-07-25

`schweisos-release` provides SchweisOS distribution identity metadata.

It is intentionally small. It does not configure package repositories, install signing keys, configure mirrors, install desktop defaults, enable Flatpak, configure AUR helpers, configure Distrobox, build an ISO, or apply performance tuning.

This package exists separately from the other Distribution Identity Layer packages because identifying the operating system is not the same responsibility as trusting packages, discovering mirrors, or configuring pacman repositories.

## Installed Layout

- `/usr/lib/schweisos-release/os-release`
- `/usr/lib/schweisos-release/release.json`

Source files:

- `os-release`
- `release.json`
- `PKGBUILD`

The package does not install an `.install` script and does not modify `/etc/os-release`.

The initial package stores SchweisOS identity data under `/usr/lib/schweisos-release/`. Direct ownership or replacement of `/usr/lib/os-release` is intentionally deferred until the installer and base-system ownership model can handle Arch's `filesystem` package cleanly. This avoids a bootstrap package silently replacing Arch-owned identity files on a development host.

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
bsdtar -tf schweisos-release-0.1.0-1-any.pkg.tar.* | sort
```

Expected package payload:

```text
usr/lib/schweisos-release/os-release
usr/lib/schweisos-release/release.json
```

Optional local install testing should happen only in a disposable VM or container.
