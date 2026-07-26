# SchweisOS Canonical Package Repository Workflow

Version: 1.1
Status: Canonical
Date: 2026-07-26

## Purpose

This document defines how a SchweisOS-owned package moves from reviewed source
to a client system. It implements the boundaries established by ADR-009 and
ADR-011; it does not replace those decisions.

The canonical flow is:

```text
Developer
  -> PKGBUILD
  -> makepkg
  -> package validation
  -> package signing
  -> repo-add
  -> repository database signing
  -> publication
  -> mirror synchronization
  -> client installation through pacman
```

No stage may silently perform the responsibility of a later stage. In
particular, building a package does not authorize it for publication, and
creating a repository database does not make that repository official.

## Package Build

The package maintainer owns the PKGBUILD and its reviewed source inputs under
`packages/<pkgname>/`.

`makepkg` produces the package archive and build metadata. Release candidates
should be built in a clean Arch environment with recorded dependency versions.
The package build must not:

- hold or use production signing keys
- run `repo-add`
- publish artifacts
- select mirrors
- edit a workstation's pacman configuration

Local builds are developer artifacts until they pass validation and the release
workflow accepts them.

## Package Validation

Validation is a separate gate between build and signing. At minimum it records:

- PKGBUILD syntax and source checksum results
- `.SRCINFO`, `.PKGINFO`, `.BUILDINFO`, and payload inspection
- file ownership and package conflict review
- install, upgrade, and removal behavior where applicable
- security-sensitive scripts, hooks, permissions, and configuration
- disposable-root, container, or VM results appropriate to the package

A validation failure returns the artifact to development. It must not be
overridden by signing the failed artifact.

## Package Signing

Only the exact validated package artifact may be signed. Official repository
packages require detached signatures made by an authorized operational signing
key on a restricted signing host.

The signing host must invoke `tools/signing/sign-artifact.sh --role package`.
The tool selects the exact package-signing subkey from the reviewed public key
inventory, requires the approved build SHA256, snapshots those exact bytes,
and immediately verifies the detached signature before exposing it at the
requested path. Generic GnuPG default-key selection is not an official
publication workflow.

Developer workstations and general build workers must not hold the offline
master key. Mirrors never sign packages. The signing workflow is defined in
[Release Signing Workflow](release-signing-workflow.md).

Signing attests that a specific artifact passed the release process; it does
not make its source correct by itself. The artifact digest, validation evidence,
and signature must remain associated.

## Repository Creation

The repository maintainer creates or updates the repository database with
upstream `repo-add` using only validated, signed package artifacts approved for
the target channel.

Repository creation owns:

- the selected package set and versions
- the repository database and files database
- detection of duplicate or missing package artifacts
- channel consistency before publication

Repository creation does not build packages, add trust keys to clients, choose
public mirror operators, or publish directly from a developer directory.

The production implementation is
`tools/release/create-repository-candidate.sh`. It accepts a new output path,
verifies each detached package signature against the exact package role, sorts
inputs, and invokes `repo-add --include-sigs --prevent-downgrade`. In addition,
every update must supply the complete currently signed repository as
`--baseline-dir`; removals and version rollback relative to that generation
are fatal. Replacing package bytes without incrementing the package version is
also fatal. Only generation zero may use the explicit `--initial-repository`
acknowledgement. Its output is explicitly a candidate until repository metadata
is signed.

## Repository Database Signing

The completed repository database must be signed after `repo-add` finishes and
before publication. A database change invalidates the previous database
signature and requires a new signing operation.

The finalized database is signed with
`tools/signing/sign-artifact.sh --role database`; package and database roles
must not be interchanged. Publication verifies the detached database signature
against the admitted `schweisos.gpg` public bundle.

Official repository policy requires trusted signatures for both packages and
repository databases. An unsigned local bootstrap database is a developer test
artifact only and cannot be promoted into public infrastructure.

`tools/release/sign-repository-metadata.sh` signs both the database and files
archives with the restricted database role and requires the two digests
recorded when the candidate was created. It exposes neither signature until
both verify. `tools/release/validate-release-repository.sh --state complete`
is the publication gate; `tests/validate-signed-repository-client.sh` proves the
same state is consumable by a disposable strict pacman client without touching
host trust.

## Publication

Publication moves an immutable, internally consistent set of packages,
signatures, repository databases, and database signatures to designated
artifact storage and then to the canonical endpoint defined by ADR-011.

Publication is a release-engineering operation. It must:

- verify that every database entry has its referenced package and signature
- verify repository database signatures
- reject signatures made by a fingerprint not assigned to the artifact role
- record a manifest or equivalent release evidence
- stage changes before making them visible
- avoid partial publication states
- retain enough evidence for incident investigation and recovery

Developer workstations must never be mirror synchronization sources. A local
`out/local-repo/` tree is not publication input and must not be uploaded as an
official repository.

## Mirror Synchronization

Official mirrors copy already-published artifacts from the canonical endpoint
or designated artifact storage. They do not rebuild, re-sign, rename, or select
packages.

Mirror operators distribute bytes; they do not become trust anchors. Clients
must reject altered or unsigned artifacts through pacman's normal verification
model.

## Client Installation

Client trust begins outside the mirror:

```text
verified installation medium or independently verified bootstrap
  -> schweisos-keyring
  -> trusted SchweisOS public keys
  -> schweisos-pacman-config
  -> schweisos-mirrorlist
  -> signed repository database and packages
  -> pacman installation
```

`schweisos-keyring` owns SchweisOS public trust material,
`schweisos-mirrorlist` owns endpoints, and `schweisos-pacman-config` owns only
SchweisOS repository snippets. Arch repositories and `archlinux-keyring` remain
upstream-owned.

Clients must use full-system upgrades in accordance with Arch's supported
update model. Repository tooling must not encourage partial upgrades.

## Ownership Boundaries

| Responsibility | Owner | Output | Must not own |
| --- | --- | --- | --- |
| Package source | Package maintainer | PKGBUILD and source inputs | Signing authority or publication |
| Package build | Clean build environment | Package archive and build metadata | Repository state or private keys |
| Package validation | Reviewer or validation process | Evidence and approval/rejection | Artifact mutation after approval |
| Package signing | Restricted signing role | Detached package signature | Building or mirror operation |
| Repository creation | Repository maintainer | `repo-add` database and package set | Public trust bootstrap |
| Database signing | Restricted signing role | Detached database signature | Package selection |
| Publication | Release engineering | Canonical immutable repository state | Rebuilding packages |
| Synchronization | Mirror operator | Byte-for-byte copy | Trust decisions or signing |
| Installation | User and pacman | Verified installed packages | Trusting transport alone |

## Separation of Workflows

Package build answers: "What artifact did this PKGBUILD produce?"

Repository creation answers: "Which validated artifacts belong to this
repository state?"

Repository publication answers: "Which complete signed state is made available
to clients and mirrors?"

Release engineering answers: "Who authorized the state, how is it signed, what
evidence is retained, and how can the project recover from failure?"

Combining these questions in one unrestricted script or workstation would make
review, compromise recovery, and future delegation harder.

## Local Bootstrap Exception

The tooling under `tools/repo/` may create an unsigned, mutable repository under
`out/local-repo/` for local package compatibility tests. Its fixed database name
is `schweisos` so the repo-add output matches the configured `[schweisos]`
pacman repository name. This name alignment is required for Archiso and pacman
to consume the repository without manual copy steps or compatibility symlinks.

The local layout and its direct package-file installation test do not validate
package signing, repository signing, publication, mirrors, or production client
trust. No local result may be promoted by relabeling it as an official artifact.
The generated directory shape is:

```text
out/local-repo/schweisos/os/x86_64/schweisos.db
```

This mirrors pacman's `$repo/os/$arch` expansion for the local development
endpoint without inventing a public endpoint.

The installed bootstrap mirrorlist also contains a separate local development
endpoint:

```ini
Server = file:///var/lib/schweisos/local-repo/$repo/os/$arch
```

That endpoint exists so build hosts can parse and validate SchweisOS repository
integration through pacman and, during local development, consume a repository
whose database basename matches `[schweisos]`. It must not be used as an
official source. Under the required trusted package and database signature
policy, release use still requires signed artifacts and approved public keys.
