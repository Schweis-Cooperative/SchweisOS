# schweisos-pacman-config

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.2
Status: Active local repository configuration
Date: 2026-07-27

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

The package does not edit `/etc/pacman.conf`; therefore installing it does not
activate a repository. Installer logic, administrator action, or a future
documented configuration owner must decide when to add the include.

## Repository Policy

The bootstrap snippet defines only the future `[schweisos]` repository. It
obtains endpoints through the separately owned include:

```ini
Include = /etc/pacman.d/schweisos-mirrorlist
```

The mirrorlist provides a local development bootstrap `Server` entry. It is
not a production mirror and does not weaken trust: this package still requires
trusted signatures for packages and repository databases. Testing and staging
channels are defined by ADR-011 but are not needed in this minimal bootstrap
package.

Arch Linux repositories such as `[core]`, `[extra]`, and `[multilib]` remain owned by Arch configuration and must not be duplicated here.

## Signature Policy

The current snippet uses:

```ini
SigLevel = Required TrustedOnly
```

This requires signatures for both packages and repository databases and accepts
only fully trusted signing keys. The snippet does not inherit a weaker global
database policy and never uses `Never`, `Optional`, or `TrustAll`.

The production keyring and signed local repository workflow are operational.
The configuration still fails closed when the configured path lacks a complete
signed generation or the client has not admitted SchweisOS trust.

## Relationship With schweisos-keyring

`schweisos-keyring` provides the SchweisOS production public certificate and
trust metadata.

This package depends on `schweisos-keyring` so the package relationship is
explicit. Trust bootstrap, rotation, and revocation remain separate
release-engineering operations.

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
makepkg --verifysource
makepkg --printsrcinfo
makepkg --nodeps -f
bsdtar -tf schweisos-pacman-config-*.pkg.tar.* | sort
```

Sprint A interaction validation is run from the repository root:

```bash
tests/validate-repository-bootstrap.sh
```

## What Can Be Validated Now

- PKGBUILD syntax.
- Stable `.SRCINFO` output.
- Package build succeeds.
- Package contains only `/etc/pacman.d/schweisos.conf`.
- No install script exists.
- `/etc/pacman.conf` is not modified by the package.
- No Arch repository sections are duplicated.
- Package and database signatures are required with `TrustedOnly`.
- `Never`, `Optional`, and `TrustAll` are not used.
- The snippet can be parsed by `pacman-conf` with the local mirrorlist file.

## What Cannot Be Validated Yet

- End-to-end installation from a future public endpoint.
- Mirror failover.

These require public SchweisOS repository and mirror infrastructure.

## Self Review

Architectural risks:

- If an administrator includes this file before a complete signed repository
  exists, pacman operations against `[schweisos]` will fail because the
  configured path is incomplete. This is the intended fail-closed behavior.

Unnecessary complexity:

- No install script is included.
- No pacman.conf mutation is included.
- No Arch repositories are duplicated.
- No network checks are included.

Future improvements:

- Validate the installer-owned `/etc/pacman.conf` include path in a completed
  installed-system smoke test.
- Continue validating each repository generation in a disposable pacman root.
- Add testing and staging snippets only when those channels become operational.
