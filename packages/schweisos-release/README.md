# schweisos-release

Version: 0.1
Status: Initial package implementation
Date: 2026-07-24

`schweisos-release` provides SchweisOS distribution identity metadata.

It is intentionally small. It does not configure package repositories, install signing keys, configure mirrors, install desktop defaults, enable Flatpak, configure AUR helpers, configure Distrobox, build an ISO, or apply performance tuning.

## Installed Layout

- `/usr/lib/schweisos-release/os-release`
- `/usr/lib/schweisos-release/release.json`
- `/usr/share/schweisos/branding/README.md`
- `/usr/share/schweisos/branding/logo-placeholder.svg`
- `/usr/share/licenses/schweisos-release/LICENSE`

The package install script points `/etc/os-release` to `/usr/lib/schweisos-release/os-release` only when `/etc/os-release` is missing or already points to a known Arch or SchweisOS os-release target. If `/etc/os-release` is a user-managed regular file or an unknown symlink, it is left unchanged.

This avoids packaging a direct `/usr/lib/os-release` replacement, because Arch's `filesystem` package owns that file.

## Validation

From this directory:

```bash
bash -n PKGBUILD
bash -n schweisos-release.install
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-release-0.1.0-1-any.pkg.tar.* | sort
```

Optional local install test in a disposable VM or container:

```bash
sudo pacman -U schweisos-release-0.1.0-1-any.pkg.tar.*
cat /etc/os-release
cat /usr/lib/schweisos-release/release.json
sudo pacman -R schweisos-release
ls -l /etc/os-release
```

Do not run install tests on a primary workstation unless you intentionally want `/etc/os-release` to identify the host as SchweisOS during the test.
