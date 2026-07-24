# schweisos-pacman-config

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Initial pacman configuration package implementation
Date: 2026-07-24

`schweisos-pacman-config` provides the pacman repository configuration snippet for SchweisOS-owned package repositories.

It does not overwrite `/etc/pacman.conf`. It does not configure Arch Linux repositories. It does not install keys, generate repositories, contact network services, or perform updates.

## Purpose

The package installs:

```text
/etc/pacman.d/schweisos.conf
```

This file can be included from `/etc/pacman.conf`:

```ini
Include = /etc/pacman.d/schweisos.conf
```

The include action is intentionally not performed by this package. Installer logic, administrator action, or a future explicitly documented configuration step must decide when the snippet is included.

## Repository Policy

The snippet defines only SchweisOS-owned repositories:

- `[schweisos]` is enabled by default inside the snippet.
- `[schweisos-testing]` exists but is commented out.
- `[schweisos-staging]` exists but is commented out.

Arch Linux repositories such as `[core]`, `[extra]`, and `[multilib]` remain owned by Arch configuration and must not be duplicated here.

## Signature Policy

The current snippet uses:

```ini
SigLevel = Required DatabaseOptional
```

This means package signatures are required. Repository database signatures are accepted when present but not required yet.

This matches the current bootstrap trust model in ADR-011:

- package signatures are mandatory for official public packages
- repository database signatures should be used once operational
- unsigned repository databases remain a temporary bootstrap limitation
- `TrustAll` must not be used

Once SchweisOS repository database signing is operational, this policy should be revisited and tightened through a documented release-engineering decision.

## Relationship With schweisos-keyring

`schweisos-keyring` provides SchweisOS-owned public signing keys and trust metadata.

This package depends on `schweisos-keyring` because pacman configuration should not enable SchweisOS repositories without the future trust material package being present.

This package does not install, import, revoke, or generate keys.

## Relationship With schweisos-mirrorlist

`schweisos-mirrorlist` provides repository endpoint discovery through:

```text
/etc/pacman.d/schweisos-mirrorlist
```

This package includes that mirrorlist from SchweisOS repository sections. It does not rank mirrors or manage mirror synchronization.

## Package Layout

```text
packages/schweisos-pacman-config/
  PKGBUILD
  README.md
  schweisos.conf
```

Installed layout:

```text
/etc/pacman.d/schweisos.conf
```

The installed snippet is marked as a pacman backup file so local user edits are protected during package upgrades.

## Validation

From this directory:

```bash
bash -n PKGBUILD
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-pacman-config-0.1.0-1-any.pkg.tar.* | sort
```

Static pacman config parse check:

```bash
tmpdir="$(mktemp -d)"
mkdir -p "${tmpdir}/etc/pacman.d"
sed "s|/etc/pacman.d/schweisos-mirrorlist|${tmpdir}/etc/pacman.d/schweisos-mirrorlist|" \
  schweisos.conf > "${tmpdir}/etc/pacman.d/schweisos.conf"
cp ../schweisos-mirrorlist/schweisos-mirrorlist "${tmpdir}/etc/pacman.d/schweisos-mirrorlist"
printf '[options]\nRootDir = %s\nDBPath = %s/var/lib/pacman/\nCacheDir = %s/var/cache/pacman/pkg/\nArchitecture = auto\nInclude = %s/etc/pacman.d/schweisos.conf\n' "${tmpdir}" "${tmpdir}" "${tmpdir}" "${tmpdir}" > "${tmpdir}/pacman.conf"
pacman-conf -c "${tmpdir}/pacman.conf" --repo-list
rm -r "${tmpdir}"
```

## What Can Be Validated Now

- PKGBUILD syntax.
- Stable `.SRCINFO` output.
- Package build succeeds.
- Package contains only `/etc/pacman.d/schweisos.conf`.
- No install script exists.
- `/etc/pacman.conf` is not modified by the package.
- No Arch repository sections are duplicated.
- `schweisos-testing` and `schweisos-staging` are present but disabled.
- `TrustAll` is not used.
- The snippet can be parsed by `pacman-conf` with the local mirrorlist file.

## What Cannot Be Validated Yet

- Real repository database download.
- Real package signature verification.
- Real repository database signature verification.
- Interaction with a populated `schweisos-keyring`.
- End-to-end installation from `repo.schweisos.org`.
- Mirror failover.

These require official SchweisOS repository infrastructure and real signing keys.

## Self Review

Architectural risks:

- `DatabaseOptional` is intentionally transitional. It should be tightened after repository database signing is operational.
- If an installer includes this file before real signed packages exist, pacman operations against SchweisOS repositories will fail. That is correct failure behavior, but release notes must make it clear.

Unnecessary complexity:

- No install script is included.
- No pacman.conf mutation is included.
- No Arch repositories are duplicated.
- No network checks are included.

Future improvements:

- Tighten repository database signature policy when repo database signing exists.
- Add installer documentation describing when `/etc/pacman.d/schweisos.conf` is included.
- Add validation against a disposable pacman root after real keyring and repository infrastructure exist.
