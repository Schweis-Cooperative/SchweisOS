# SchweisOS Release Signing Workflow

Version: 1.0
Status: Architecture
Date: 2026-07-25

## Purpose

This document defines the future trust and operational boundaries for signing
SchweisOS package repository artifacts. It contains no keys, fingerprints,
signatures, commands that generate keys, or temporary trust material.

Production public keys must not be added to `schweisos-keyring` until this
policy is completed with an approved operational procedure and a reviewed key
ceremony.

## Trust Roles

The signing architecture separates four roles even when one maintainer performs
them initially:

- the offline master key establishes and recovers SchweisOS signing authority
- operational signing keys sign approved package and repository artifacts
- the release-signing host performs controlled signing operations
- `schweisos-keyring` distributes approved public trust material to clients

Role separation is a security boundary, not an organizational claim. A
one-maintainer project may perform the steps manually, but it must keep the
artifacts, credentials, and decisions distinguishable.

## Offline Master Key Philosophy

The long-lived master key should be kept offline and used only for narrowly
defined trust-management operations such as authorizing or revoking operational
signing keys and recovering from key compromise.

It must not be used for routine package builds, daily repository updates, CI,
developer authentication, or general workstation activity. Its private material
must not exist on developer machines, build workers, mirrors, public artifact
storage, or in the source repository.

Before production use, release engineering must define protected offline
storage, independently recoverable backups, access records, and revocation
material. This document deliberately does not select a hardware token, storage
vendor, or exact key algorithm before an operational threat review.

## Operational Signing Keys

Routine signing should use delegated operational keys with a narrower lifetime
and authority than the offline master key. Their scope must be documented so a
package signer, repository database signer, and any future release-artifact
signer are not assumed to be interchangeable without review.

Operational private keys belong only on the restricted signing host or approved
hardware-backed signing device. Public counterparts and trust metadata belong
in `schweisos-keyring` after approval.

## Developer and Build Separation

Developer machines produce source changes and local artifacts. Clean build
workers produce release candidate package archives and `.BUILDINFO` evidence.
Neither role authorizes publication and neither should hold long-lived
production private keys.

The signing host accepts only immutable artifacts that have passed validation.
It must not execute PKGBUILDs, fetch arbitrary package sources, browse mirrors,
or act as a general development workstation. Signing must never mutate the
artifact it authorizes.

## Package and Database Signing

The release sequence is:

```text
validated package archive
  -> detached package signature
  -> repo-add database built from approved signed packages
  -> detached repository database signature
  -> publication gate
```

The digest and identity of every artifact presented for signing must match the
validation record. Repository database signing occurs only after the package set
is final. Any database modification requires revalidation of the repository set
and a new database signature.

Mirrors distribute these artifacts unchanged. They never receive signing
authority.

## Trust Establishment

Transport security and domain ownership do not establish package trust. Clients
trust SchweisOS packages only when pacman verifies them against public keys
delivered through an independently trusted bootstrap path.

The intended path is:

```text
independently verified SchweisOS installation medium or bootstrap artifact
  -> schweisos-keyring
  -> approved public operational keys
  -> signed repository databases and packages
```

Arch trust remains provided by `archlinux-keyring`. SchweisOS public keys must
not be inserted into, replace, or weaken Arch's trust domain.

## Bootstrap Trust

The first production keyring creates a bootstrapping problem: clients cannot
learn the initial SchweisOS key solely from an artifact whose authenticity
depends on that same key.

Before a public repository is enabled, release engineering must provide an
independent verification path for the initial keyring and publish verification
instructions through separately controlled project channels. A verified
installation medium may carry the initial public keyring, but that medium must
have its own documented authenticity path.

Until this process exists, the bootstrap `schweisos-keyring` package remains
non-operational and local repositories remain untrusted developer artifacts.

No fingerprint is defined by this document. Fingerprints must be derived from
approved production public keys and verified during the future key ceremony;
they must never be invented to complete documentation.

## Rotation

Operational signing keys must have planned lifetimes. Normal rotation should:

1. authorize the new public key through the offline trust process
2. ship the new key in `schweisos-keyring` while the old key is still valid
3. allow enough overlap for supported clients to update their keyring
4. begin signing new artifacts with the new operational key
5. retire the old key only after the documented migration window
6. retain auditable records of the transition

Rotation must not require disabling signature checks or using `TrustAll`.

## Revocation and Compromise Recovery

The release policy must prepare revocation material and recovery instructions
before a production key is used.

If an operational key is suspected or confirmed compromised, SchweisOS must:

1. stop signing and publication with the affected key
2. preserve evidence and identify the affected publication interval
3. revoke the key through the established trust path
4. publish an incident notice through independently controlled channels
5. deliver an updated `schweisos-keyring` through a still-valid trust path
6. rebuild or re-sign affected repository state as policy requires
7. provide explicit client recovery instructions

Compromise of the offline master key is a trust-root incident. Recovery cannot
be reduced to routine key rotation and requires a separately reviewed trust
re-establishment plan.

Expired, revoked, or compromised keys must not remain trusted merely to keep an
old client working. Recovery procedures must fail closed rather than advise
users to disable verification.

## Audit and Ownership Records

Before production signing begins, the project must maintain an auditable key
inventory containing public key identity, approved owner or role, permitted use,
creation and expiry dates, rotation state, and revocation state. Private key
locations must not be published in that inventory.

Signing records should associate each signature with the artifact digest,
validation evidence, repository channel, authorization, and timestamp. These
records are release evidence, not telemetry about users.

## Deferred Operational Decisions

Sprint B does not decide or implement:

- concrete keys, fingerprints, algorithms, or expiry dates
- key generation commands or a key ceremony checklist
- hardware token or offline storage products
- signing automation, remote signing, or CI integration
- public key distribution or repository publication
- ISO or Secure Boot signing

These decisions require a future release-engineering review before production
trust is established.
