# SchweisOS Production Keyring Admission

Version: 1.0
Status: Canonical gate
Date: 2026-07-26

## Purpose

This document defines how the public output of the offline release-key ceremony
becomes the `schweisos-keyring` trust anchor. Admission handles public material
only. It never reads, copies, imports, or records a private key.

The bootstrap `schweisos-keyring` package remains intentionally
non-operational until every gate below succeeds. Missing production material is
a blocker, not a reason to add a temporary key or weaken pacman policy.

## Required Ceremony Evidence

Admission requires all of the following:

- an accepted ceremony record based on `key-ceremony-record-template.md`
- two recorded comparisons of the full primary and operational fingerprints
- the original public bundle produced by the ceremony tool
- a successful `tools/signing/validate-public-bundle.sh` result
- a reviewed repository commit containing the accepted signing policy
- confirmation that no private material or revocation certificate is present

The bundle is copied into `packages/schweisos-keyring/keys/` only after those
checks. Copying it earlier would blur the difference between unverified input
and an admitted trust root.

## Package Transition

The admission change converts `schweisos-keyring` from bootstrap state to an
operational trust package. One focused review must:

1. add the six validated public-bundle files to `keys/`
2. include their exact checksums in the PKGBUILD source inventory
3. install `schweisos.gpg`, `schweisos-trusted`, and `schweisos-revoked` with
   mode `0644` under `/usr/share/pacman/keyrings/`
4. install the armored certificate, role metadata, and checksums as public
   audit documentation, not as alternate trust databases
5. add the minimal package install script described below
6. remove bootstrap-only wording and assign the first operational package
   version
7. build and inspect the complete package payload

No generated pacman database, local trustdb, secret key, revocation
certificate, signing-host export, signature, hostname, or private path belongs
in the source or binary package.

## pacman Trust Bootstrap

The operational package install script follows the upstream keyring-package
contract. On install and upgrade it may run:

```text
pacman-key --populate schweisos
```

only when `/usr/bin/pacman-key` is available and pacman's local keyring is
already initialized. It must not run `pacman-key --init`, fetch keys from a key
server, alter `archlinux-keyring`, edit `pacman.conf`, or change `SigLevel`.

`schweisos.gpg` supplies the public certificate. `schweisos-trusted` identifies
the approved primary fingerprint for local trust establishment.
`schweisos-revoked` carries approved revocation state. Arch Linux trust remains
owned by `archlinux-keyring`.

## Bootstrap Limitation

The first operational keyring package cannot authenticate itself. Its package
checksum and full primary fingerprint must therefore be verified through at
least two independently controlled SchweisOS channels or delivered by an
independently verified installation image. This exception applies only to the
initial trust transition; it does not permit unsigned repository publication.

After initial trust is established, every keyring update must be signed by a
currently trusted SchweisOS operational package-signing subkey. Operational
subkey rotation must publish the new public state before the old subkey stops
being valid.

## Acceptance Tests

The focused admission review must prove:

- the public-bundle validator passes
- no secret-key packets exist in any package source or payload
- package source checksums and `.SRCINFO` match
- the package owns only its documented keyring and audit files
- a disposable initialized pacman root can populate `schweisos`
- the exact primary fingerprint receives the intended local trust
- Arch keyring files and trust remain unchanged
- trusted package and repository-database signatures verify
- unsigned, unknown-key, wrong-role, expired, and revoked signatures fail
- all repository and ISO validators remain strict

The package is not production-ready until these tests are recorded as passing.
