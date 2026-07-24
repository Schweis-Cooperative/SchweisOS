# schweisos-mirrorlist

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Initial mirrorlist package implementation
Date: 2026-07-24

`schweisos-mirrorlist` provides the pacman-compatible mirrorlist file used to discover official SchweisOS package repository endpoints.

It does not create repositories, sign packages, configure pacman repositories, rank mirrors, integrate with reflector, or modify Arch Linux mirrors.

## Purpose

The package installs:

```text
/etc/pacman.d/schweisos-mirrorlist
```

This file contains SchweisOS repository `Server = .../$repo/os/$arch` entries in the format pacman expects.

At this stage, the mirrorlist contains a single canonical official endpoint:

```text
https://repo.schweisos.org/$repo/os/$arch
```

The endpoint is reserved for future official repository publication. A real public repository is not implemented by this package.

## Relationship With schweisos-keyring

`schweisos-keyring` provides the future public keys and trust metadata used to verify SchweisOS package signatures.

`schweisos-mirrorlist` only tells pacman where repository files may be downloaded from. It does not decide whether downloaded packages are trusted.

## Relationship With schweisos-pacman-config

`schweisos-pacman-config` will eventually add SchweisOS repository sections to pacman configuration and include this mirrorlist.

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

Mirror expansion should happen in stages:

1. Publish the canonical official endpoint.
2. Validate package and repository signature workflows.
3. Document mirror eligibility and synchronization rules.
4. Add official mirrors after they sync from SchweisOS artifact storage.
5. Consider community mirrors only after health checks and policy exist.

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
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-mirrorlist-0.1.0-1-any.pkg.tar.* | sort
```

Mirrorlist format checks:

```bash
grep -n '^Server = ' schweisos-mirrorlist
awk '/^Server = / && $0 !~ /\$repo\/os\/\$arch$/ { bad=1; print } END { exit bad }' schweisos-mirrorlist
```

## What Can Be Validated Now

- PKGBUILD syntax.
- Stable `.SRCINFO` output without absolute local paths.
- Package build succeeds.
- Package contains only `/etc/pacman.d/schweisos-mirrorlist`.
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

- The canonical endpoint is present before public repository infrastructure exists. This is acceptable only because `schweisos-pacman-config` is not implemented yet and this package does not enable repositories by itself.
- If the endpoint domain changes later, the package must update users cleanly through pacman backup behavior.

Unnecessary complexity:

- No install script is included.
- No mirror ranking is included.
- No reflector integration is included.
- No pacman repository configuration is included.

Future improvements:

- Add official mirrors after mirror policy and synchronization are documented.
- Add health-check metadata only after a mirror maintenance process exists.
- Add community mirror sections only after trust and support boundaries are documented.
