# SchweisOS Release Signing Workflow

Version: 2.0
Status: Accepted
Date: 2026-07-26

## Purpose

This document defines the production trust root and the operational workflow
for signing SchweisOS packages and repository databases. The policy applies to
all official SchweisOS repositories. Development keys and host-local pacman
keys are not release-signing authorities.

## Key Hierarchy

SchweisOS uses one OpenPGP certificate with three deliberately separate key
roles:

| Role | Algorithm | Capability | Lifetime | Location |
| --- | --- | --- | --- | --- |
| Offline release primary | Ed25519 | Certification only | 10 years | Offline encrypted media only |
| Package signing subkey | Ed25519 | Signing only | 1 year | Restricted signing host or approved hardware token |
| Repository database signing subkey | Ed25519 | Signing only | 1 year | Restricted signing host or approved hardware token |

The primary identity is:

```text
SchweisOS Release Authority <release@schweisos.org>
```

The primary key never signs packages or repository databases. Operational
scripts must select the exact authorized subkey fingerprint, including GnuPG's
`!` suffix, so GnuPG cannot silently choose another signing-capable key.

The two operational roles may initially be held on one restricted signing host,
but they remain separate subkeys and separate authorization records. A future
team may move them to separate devices without changing the client trust root.

## Offline Key Ceremony

The production primary key is generated only during a reviewed ceremony on a
dedicated Arch Linux system that has no configured network route, no global
network address, and no active non-loopback network interface. Removing a
browser window or disabling one application does not make a host offline.

The ceremony uses `tools/signing/create-offline-release-key.sh`. The script:

- refuses to run as root
- refuses to place the GnuPG home inside the source repository
- refuses an existing or non-empty GnuPG home
- requires the private GnuPG home to be on a LUKS-backed block-device chain
- fails when an active network path is visible
- never accepts a passphrase through arguments, files, or environment variables
- asks GnuPG and pinentry to collect a new passphrase interactively
- creates the certification-only primary and two signing subkeys
- verifies that GnuPG created primary-key revocation material
- exports only the public certificate and public role metadata
- produces checksums for every exported public artifact

Two project representatives should read the fingerprints from the offline host
and compare them with the exported public bundle. With one maintainer, the same
person may perform both readings at separate times, but the record must say so.

Key generation must not occur on a VPS, CI worker, daily workstation, build
host, or inside a temporary directory. A sandboxed process on a networked host
is not an offline key ceremony.

## Private-Key Storage

The authoritative offline GnuPG home is stored on a LUKS2-encrypted removable
device. A second LUKS2-encrypted backup is created during the same ceremony and
stored in a separate physical location. Both devices use strong, unique
passphrases that are not reused for SSH, user accounts, Git hosting, or disk
login.

The private primary key must never be exported to the source repository,
password manager attachments, cloud storage, build host, signing host, mirror,
or project website. The encrypted offline GnuPG home is the canonical private
record. File-level encryption is not a substitute for encrypted-media custody.

The automatically generated primary revocation certificate is copied to both
encrypted offline devices and to a third sealed offline recovery medium. It is
not committed or uploaded. Every access to an offline device is recorded with
date, purpose, operator, and outcome; private paths and passphrases are never
recorded.

After the backup is verified, the ceremony host is shut down. If it used an
internal writable disk, that disk must be securely erased or retained as an
offline signing asset. The host must not reconnect to a network while the
offline GnuPG home is mounted.

## Operational Signing Material

Only the operational signing subkeys may be transferred to the restricted
signing host. The exported secret-subkey bundle is transported on encrypted
removable media. After an independent import and signing test succeeds, the
medium is unmounted and returned to offline custody; portable file deletion is
not claimed to securely sanitize flash storage. The medium is not reused. The
offline primary remains a stub on the signing host and cannot certify, rotate,
or revoke keys.

`tools/signing/export-operational-subkeys.sh` performs that export on the
offline host. It creates separate role files with GnuPG's
`--export-secret-subkeys` operation, refuses SSH, networking, virtualization,
repository-local output, and non-LUKS-backed storage. The signing-host import is
accepted only when both exact role fingerprints match the reviewed public
inventory and no usable certification primary is present.

The signing host must:

- be dedicated to release signing rather than builds or development
- receive immutable validated artifacts and their digests
- have no general web-browsing or source-build role
- require interactive authorization for each signing batch
- select the exact role fingerprint recorded by the public key inventory
- preserve a signing record containing artifact digest, role, key fingerprint,
  validation reference, timestamp, and operator
- return detached signatures without modifying the signed artifact

CI, developer machines, build workers, mirrors, and repository web servers do
not receive operational private keys.

## Public Bundle and Key Inventory

The ceremony exports a public bundle containing:

```text
schweisos.gpg
schweisos-release.asc
schweisos-trusted
schweisos-revoked
release-key-metadata.tsv
SHA256SUMS
```

`schweisos.gpg` is the minimal binary OpenPGP public certificate used by
pacman. `schweisos-trusted` contains only the full primary fingerprint using
the ownertrust format expected by `pacman-key`. `schweisos-revoked` is initially
empty and receives full revoked primary fingerprints only after an approved
revocation decision.

`release-key-metadata.tsv` binds the primary, package-signing, and
database-signing fingerprints to their exact roles. It contains no executable
shell syntax and must never be sourced. `SHA256SUMS` covers every other public
bundle file; it cannot recursively cover itself.

The armored public certificate and all three fingerprints are published through
at least two independently controlled project channels. Transport security is
useful but does not replace fingerprint comparison.

## `schweisos-keyring` Admission

Only a bundle that passes `tools/signing/validate-public-bundle.sh` may enter
`packages/schweisos-keyring/keys/`. Admission requires:

1. two recorded fingerprint comparisons against the offline display
2. exactly one certification-only Ed25519 primary
3. exactly two authorized Ed25519 signing subkeys
4. no secret-key packets
5. exact role metadata and public-bundle checksums
6. an accepted package review

The complete package transition and bootstrap acceptance gates are defined in
[Production Keyring Admission](keyring-admission.md).

The package installs:

```text
/usr/share/pacman/keyrings/schweisos.gpg
/usr/share/pacman/keyrings/schweisos-trusted
/usr/share/pacman/keyrings/schweisos-revoked
```

An install script follows the upstream keyring-package pattern: if pacman's
keyring already exists, `pacman-key --populate schweisos` imports and locally
signs the approved trust root. It does not initialize pacman, fetch network
keys, modify Arch keyring files, or weaken `SigLevel`.

The initial keyring package cannot authenticate itself. Its first admission
therefore requires an independently verified installation medium or a manually
verified bootstrap package whose checksum and primary fingerprint are published
through separate project channels. Once installed, future keyring updates are
authenticated by the existing trusted operational key.

Arch trust remains exclusively provided by `archlinux-keyring`.

## Package and Repository Signing

The release sequence is:

```text
clean package build
  -> package validation and immutable SHA256 record
  -> package-signing subkey creates detached signature
  -> signature verified against committed schweisos.gpg
  -> repo-add builds the final repository database
  -> repository-database subkey creates detached database signature
  -> complete repository validation
  -> atomic publication
```

`tools/signing/sign-artifact.sh` is the only project-provided generic signing
entry point. It requires an explicit `package` or `database` role, reads the
authorized subkey from `release-key-metadata.tsv`, selects that fingerprint
exactly, requires the independently approved SHA256, signs a private immutable
snapshot, refuses to overwrite a signature, and verifies both the digest and
detached signature before publishing it to the requested output path.

Package and database signatures are mandatory. A failed signature or trust
check stops publication. Verification rejects revoked, expired, wrong-role,
future-dated, or out-of-validity-window signatures in addition to cryptographic
failure. Local development repositories remain outside this workflow and must
never be relabeled as release repositories.

## Rotation

Operational signing subkeys rotate annually. Rotation begins at least 90 days
before expiry:

Public-bundle schema 1 is deliberately the generation-zero format: exactly one
active package subkey, one active database subkey, and no revocation entry. It
fails closed on overlap, expired records, or revocation. Before the first
rotation begins, a reviewed schema revision must add role history, overlap,
revocation, and historical-signature fixtures to the validators and keyring
package. This is an engineering gate scheduled before the 90-day window, not
an operator workaround during rotation.

1. create the replacement subkey on the offline host
2. update and verify the public bundle
3. publish a signed `schweisos-keyring` update while the old subkey is valid
4. keep both subkeys accepted for at least two normal full-system update cycles
   and no less than 30 days
5. switch signing tooling to the new role fingerprint
6. stop using the old subkey before expiry
7. retain the expired public record for historical verification

The offline primary is reviewed one year before expiry. Replacing it is a new
trust-root ceremony, not routine operational rotation.

## Revocation and Compromise Recovery

If an operational subkey may be compromised, publication stops immediately.
The offline primary revokes the affected subkey, a new public bundle and
keyring package are produced through a still-trusted path, affected publication
windows are identified, and repository state is re-signed as required.

If the offline primary may be compromised, all SchweisOS signing is suspended.
A new trust root requires a separately reviewed recovery ceremony and explicit
user-facing bootstrap instructions. Users must never be told to use `TrustAll`,
`SigLevel = Never`, or unsigned replacement packages.

## Audit Records

Public inventory records contain fingerprints, roles, creation and expiry
times, rotation state, and revocation state. They never contain private-key
paths, device serial numbers, passphrases, usernames, hostnames, machine IDs, or
network identifiers.

Signing records are release evidence and contain artifact name, artifact
digest, signing role, signing fingerprint, validation result, UTC timestamp,
and release authorization. They contain no user telemetry.

The ceremony's public audit record uses
`docs/release/key-ceremony-record-template.md`. It deliberately excludes
private storage paths and device identifiers.

The complete machine-enforced dependency graph and online handoffs are in
[Production Trust Bootstrap](production-trust-bootstrap.md). The separate
[Physical Offline Ceremony Checklist](offline-ceremony-checklist.md) contains
only actions that require custody of the air-gapped computer or encrypted
media; signing-host import and repository work are not misclassified as
offline ceremony steps.

## Explicit Prohibitions

- No temporary development key may sign an official artifact.
- No host pacman master key may act as a SchweisOS release key.
- No private key or revocation certificate may enter Git.
- No signing key may be generated by CI or on a VPS.
- No passphrase may be supplied on a command line or in an environment variable.
- No build or publication failure may be bypassed by weakening pacman policy.
- Mirrors distribute signed state; they never create or replace signatures.
