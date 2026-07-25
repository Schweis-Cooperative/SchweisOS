# schweisos-mirrorlist

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Bootstrap ownership package
Date: 2026-07-25

`schweisos-mirrorlist` defines ownership of the pacman-compatible mirror file
that will eventually list official SchweisOS repository endpoints.

No production SchweisOS repository or mirror exists yet. The installed file is
therefore an intentionally endpoints-free placeholder: it contains comments but
no active `Server` line and does not pretend that future infrastructure is
already available.

## Purpose

The package installs:

```text
/etc/pacman.d/schweisos-mirrorlist
```

The package does not create repositories, sign packages, configure pacman
repository sections, rank mirrors, contact network services, modify Arch Linux
mirrorlists, or edit `/etc/pacman.conf`. It has no install script.

## Relationship With schweisos-keyring

`schweisos-keyring` provides the future public keys and trust metadata used to verify SchweisOS package signatures.

`schweisos-mirrorlist` only tells pacman where repository files may be downloaded from. It does not decide whether downloaded packages are trusted.

## Relationship With schweisos-pacman-config

`schweisos-pacman-config` owns the SchweisOS repository section and includes
this mirrorlist.

This package intentionally does not duplicate pacman configuration. It does not create `[schweisos]`, `[schweisos-testing]`, or `[schweisos-staging]` repository sections.

## Mirrors Are Not Trust Anchors

Mirrors distribute files. They do not establish trust.

SchweisOS trust must come from:

- verified installation media
- `schweisos-keyring`
- package signatures
- repository database signatures when enabled
- pacman signature policy

This means future mirror operators should not need to be trusted with package integrity. They should only host already-signed artifacts.

## Future Mirror Expansion

Mirror publication should happen in stages:

1. Finalize signing and publication policy.
2. Operate the canonical repository and validate its signed artifacts.
3. Add its real endpoint through a reviewed package update.
4. Document mirror eligibility and synchronization rules.
5. Add official or community mirrors only after those rules are operational.

Future mirror entries should remain simple `Server = .../$repo/os/$arch` lines. Automatic ranking and reflector integration require separate design.

## Package Layout

```text
packages/schweisos-mirrorlist/
  PKGBUILD
  README.md
  schweisos-mirrorlist
```

Installed layout:

```text
/etc/pacman.d/schweisos-mirrorlist
```

The installed mirrorlist is marked as a pacman backup file so local user edits are protected during package upgrades.

## Validation

From this directory:

```bash
bash -n PKGBUILD
makepkg --verifysource
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-mirrorlist-*.pkg.tar.* | sort
```

Sprint A interaction validation is run from the repository root:

```bash
tests/validate-repository-bootstrap.sh
```

## What Can Be Validated Now

- PKGBUILD syntax.
- Stable `.SRCINFO` output without absolute local paths.
- Package build succeeds.
- Package contains only `/etc/pacman.d/schweisos-mirrorlist`.
- Mirrorlist contains no active endpoint or invented production URL.
- Mirrorlist contains no Arch mirror entries.
- Mirrorlist contains no ranking or reflector integration.
- Mirrorlist contains no pacman repository sections.

## What Cannot Be Validated Yet

- Live repository availability.
- Mirror synchronization.
- Repository database download.
- Package signature verification from the endpoint.
- Repository database signature verification.
- Failover behavior across multiple mirrors.

These require real SchweisOS repository infrastructure.

## Self Review

Architectural risks:

- An included `[schweisos]` repository has no usable server until production
  infrastructure exists. This deliberate failure state prevents accidental use
  of invented bootstrap infrastructure.
- A future endpoint update must preserve the file's narrow ownership and pacman
  backup semantics.

Unnecessary complexity:

- No install script is included.
- No mirror ranking is included.
- No reflector integration is included.
- No pacman repository configuration is included.

Future improvements:

- Add the canonical endpoint only after signing, publication, and ownership are
  operational.
- Add official mirrors after mirror policy and synchronization are documented.
- Add health-check metadata only after a mirror maintenance process exists.
- Add community mirror sections only after trust and support boundaries are documented.
