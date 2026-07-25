# schweisos-keyring

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Bootstrap package
Date: 2026-07-25

`schweisos-keyring` reserves the package structure that will eventually carry
the public trust material for official SchweisOS package signatures.

This bootstrap release is not a functional trust anchor. It contains no GPG
public keys, fingerprints, generated keyring databases, signatures, or private
signing material. Production public keys may be introduced only after the
official SchweisOS release-signing policy is finalized and its key admission,
verification, rotation, revocation, and recovery procedures are approved.

## Purpose

`schweisos-keyring` will eventually install the public keys and trust metadata
pacman needs to verify official SchweisOS packages. The bootstrap package only
installs policy documentation and reserves pacman's conventional keyring
directory; installing it grants no trust by itself.

It exists separately from `schweisos-release` because identity metadata and signing trust are different responsibilities:

- `schweisos-release` identifies the installed system as SchweisOS.
- `schweisos-keyring` manages trust material for SchweisOS-owned package signatures.

Keeping them separate makes key rotation, emergency revocation, and release identity updates easier to audit and recover.

## Relationship With Arch Trust

Arch Linux trust remains provided by `archlinux-keyring`.

SchweisOS only manages SchweisOS-owned signing keys. This package must never replace, weaken, disable, or modify Arch's trust model.

## Relationship With pacman

pacman verifies package signatures using configured keyrings and repository
signature policy. This package must never make an unsigned or untrusted package
acceptable by weakening pacman's verification settings.

Future SchweisOS repository integration comes from
`schweisos-pacman-config`, not from this package. This package does not edit
`pacman.conf`, set `SigLevel`, initialize pacman's local keyring, locally sign
keys, or run `pacman-key` from an install script.

## Relationship With Package Signing

Official public SchweisOS packages must be signed by authorized SchweisOS
signing keys as required by ADR-011.

This package is where the public side of that trust relationship will live. It
must never contain private keys. It does not sign packages, configure
repositories, create mirrors, or publish repository databases.

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

Production public keys and future maintainer keys must not be added until the
official release-signing policy is finalized. After that policy exists, a key
may be admitted only through its documented approval process.

The future process should include:

- public key collection from the maintainer
- fingerprint verification over an authenticated channel
- maintainer role approval
- addition to the SchweisOS keyring source files
- update to trusted or revoked metadata as appropriate
- package build and validation
- signed release of a new `schweisos-keyring`
- announcement when trust scope changes

No production or maintainer key is included in this bootstrap package.

## Future Pacman Keyring Layout

After the release-signing policy is finalized and production public keys are
approved, the expected installed files are:

```text
/usr/share/pacman/keyrings/schweisos.gpg
/usr/share/pacman/keyrings/schweisos-trusted
/usr/share/pacman/keyrings/schweisos-revoked
```

The current package only creates `/usr/share/pacman/keyrings/` and installs
documentation under `/usr/share/doc/schweisos-keyring/`. The empty directory is
not evidence of an initialized or trusted SchweisOS keyring.

## Source Layout

```text
packages/schweisos-keyring/
  PKGBUILD
  README.md
  future-keys.md
  keyring-policy.md
  keys/
    README.md
```

## Validation

From this directory:

```bash
bash -n PKGBUILD
makepkg --verifysource
makepkg --printsrcinfo
makepkg -f
bsdtar -tf schweisos-keyring-0.1.0-1-any.pkg.tar.* | sort
bsdtar -xOf schweisos-keyring-0.1.0-1-any.pkg.tar.* .PKGINFO
find keys -type f ! -name README.md -print
git diff --check
```

The `find` command must produce no output during the bootstrap phase.

Expected package contents at this stage:

```text
usr/share/doc/schweisos-keyring/future-keys.md
usr/share/doc/schweisos-keyring/keyring-policy.md
usr/share/pacman/keyrings/
```

## What Can Be Validated Now

- PKGBUILD syntax.
- Package build succeeds.
- No real, fake, empty, or generated cryptographic key material is shipped.
- The package owns only SchweisOS documentation and a future pacman keyring directory.
- The package does not modify Arch keyrings.
- The package does not weaken or configure pacman signature verification.
- The package has no install script.

## What Cannot Be Validated Yet

- Real key import behavior.
- Real maintainer fingerprint verification.
- Package signature verification.
- Repository database signature verification.
- Key rotation.
- Revocation recovery.

These require production public keys and a finalized release-signing policy.

## Self Review

Architectural risks:

- The package name may imply operational trust even though this bootstrap
  release contains no key material. Release and repository documentation must
  not present it as production-ready.
- The exact key admission and recovery processes are not yet defined. No
  production public key may be added until the official release-signing policy
  resolves them.

Unnecessary complexity:

- No install script is included.
- No fake keyring files are included.
- No pacman configuration is included.

Future improvements:

- Add production `schweisos.gpg`, `schweisos-trusted`, and
  `schweisos-revoked` files only after the release-signing policy is finalized,
  key ownership is verified, and the admission process is reviewed.
- Add validation that inspects fingerprints once real keys exist.
- Add release-engineering documentation for emergency key revocation and rotation drills.
