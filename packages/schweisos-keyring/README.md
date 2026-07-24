# schweisos-keyring

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Initial trust-foundation package skeleton
Date: 2026-07-24

`schweisos-keyring` is the future trust-anchor package for official SchweisOS package signing keys.

This initial implementation does not contain real GPG public keys, fake fingerprints, empty keyrings, or placeholder cryptographic material. It defines the package structure and documentation needed so real public keys can later be added without changing the package architecture.

## Purpose

`schweisos-keyring` will eventually install the public keys and trust metadata pacman needs to verify official SchweisOS packages.

It exists separately from `schweisos-release` because identity metadata and signing trust are different responsibilities:

- `schweisos-release` identifies the installed system as SchweisOS.
- `schweisos-keyring` manages trust material for SchweisOS-owned package signatures.

Keeping them separate makes key rotation, emergency revocation, and release identity updates easier to audit and recover.

## Relationship With Arch Trust

Arch Linux trust remains provided by `archlinux-keyring`.

SchweisOS only manages SchweisOS-owned signing keys. This package must never replace, weaken, disable, or modify Arch's trust model.

## Relationship With pacman

pacman verifies package signatures using configured keyrings and repository signature policy.

Future SchweisOS pacman integration will come from `schweisos-pacman-config`, not from this package. This package only provides the SchweisOS keyring material that pacman can trust after it is properly populated.

## Relationship With Package Signing

Official SchweisOS packages must eventually be signed by authorized SchweisOS signing keys.

This package is where the public side of that trust relationship will live. It does not sign packages, configure repositories, create mirrors, or publish repository databases.

## Future Release Signing Workflow

The intended future workflow is:

```text
validated package
  -> signed by authorized SchweisOS signing key
  -> added to signed repository database
  -> published to artifact storage
  -> synchronized to mirrors
  -> verified by pacman using schweisos-keyring
```

## Future Maintainer Keys

New maintainer keys should be added only after a documented release-engineering decision.

The future process should include:

- public key collection from the maintainer
- fingerprint verification over an authenticated channel
- maintainer role approval
- addition to the SchweisOS keyring source files
- update to trusted or revoked metadata as appropriate
- package build and validation
- signed release of a new `schweisos-keyring`
- announcement when trust scope changes

No real maintainer key is included yet.

## Future Pacman Keyring Layout

When real keys are approved, the expected installed files are:

```text
/usr/share/pacman/keyrings/schweisos.gpg
/usr/share/pacman/keyrings/schweisos-trusted
/usr/share/pacman/keyrings/schweisos-revoked
```

The current package only creates `/usr/share/pacman/keyrings/` and installs documentation under `/usr/share/doc/schweisos-keyring/`.

## Source Layout

```text
packages/schweisos-keyring/
  PKGBUILD
  README.md
  keys/
    README.md
  files/
    usr/share/doc/schweisos-keyring/
      future-keys.md
      keyring-policy.md
```

## Validation

From this directory:

```bash
bash -n PKGBUILD
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-keyring-0.1.0-1-any.pkg.tar.* | sort
```

Expected package contents at this stage:

```text
usr/share/doc/schweisos-keyring/future-keys.md
usr/share/doc/schweisos-keyring/keyring-policy.md
usr/share/pacman/keyrings/
```

## What Can Be Validated Now

- PKGBUILD syntax.
- Package build succeeds.
- No fake or empty cryptographic key material is shipped.
- The package owns only SchweisOS documentation and a future pacman keyring directory.
- The package does not modify Arch keyrings.
- The package has no install script.

## What Cannot Be Validated Yet

- Real key import behavior.
- Real maintainer fingerprint verification.
- Package signature verification.
- Repository database signature verification.
- Key rotation.
- Revocation recovery.

These require real signing keys and a documented release signing process.

## Self Review

Architectural risks:

- The package creates the future keyring directory before real keys exist. This is acceptable for architecture preparation, but it must not be treated as a working trust anchor until real keys are added.
- The exact maintainer-key approval process is not yet defined. It should be handled in a future release-engineering ADR or guide update.

Unnecessary complexity:

- No install script is included.
- No fake keyring files are included.
- No pacman configuration is included.

Future improvements:

- Add real `schweisos.gpg`, `schweisos-trusted`, and `schweisos-revoked` files after key generation and fingerprint verification.
- Add validation that inspects fingerprints once real keys exist.
- Add release-engineering documentation for emergency key revocation and rotation drills.
