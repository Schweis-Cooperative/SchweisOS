# ADR-011 Repository Architecture

Version: 1.1

## Status

Accepted

## Date

2026-07-25

## Related ADRs

- ADR-001 Repository Strategy
- ADR-003 Package Sources
- ADR-007 Update Philosophy
- ADR-009 Distribution Identity Packages

## Context

SchweisOS needs a complete package repository architecture before implementing the remaining distribution identity packages.

The repository must define how SchweisOS packages are built, validated, signed, published, mirrored, installed, updated, and maintained. It must stay close to Arch package semantics and avoid creating a new package manager, hidden update layer, or forked Arch repository.

At bootstrap, SchweisOS has one maintainer. The architecture must work for one maintainer without blocking future growth into a larger contributor and release team.

## Decision

SchweisOS will maintain a small signed package repository for SchweisOS-owned packages only.

Arch packages remain upstream Arch packages. SchweisOS repositories contain distribution identity packages, configuration packages, installer configuration, documentation packages, and carefully scoped meta packages. SchweisOS must not mirror, rename, or fork Arch repositories unless a future ADR approves a specific exception.

The initial repository family is:

- `schweisos`
- `schweisos-testing`
- `schweisos-staging`

SchweisOS will not create `core`, `extra`, or `multilib` repositories. Those names belong to Arch's repository model and should remain upstream Arch concepts in SchweisOS documentation and pacman configuration.

## Package Flow

The complete package lifecycle is:

```text
Developer
  -> PKGBUILD
  -> makepkg
  -> package validation
  -> package signing
  -> repository database update
  -> repository database signing
  -> artifact publication
  -> mirror synchronization
  -> user installation through pacman
```

Developer:

A maintainer or contributor proposes a package change in the monorepo. The change must follow the Packaging Guide and any relevant ADRs.

PKGBUILD:

Each SchweisOS package source lives under `packages/<pkgname>/`. PKGBUILDs must follow Arch packaging conventions and must not download unpinned or hidden sources during package functions.

makepkg:

Packages are built with `makepkg`, preferably in a clean build environment once release infrastructure exists. Build metadata from `.BUILDINFO` must be retained as part of release evidence.

Package validation:

Validation must include at minimum syntax checks, source checksum verification, package content inspection, install/remove behavior review when install scripts exist, and VM or container testing when the package affects system identity, boot, trust, or pacman behavior.

Package signing:

Every package published to an official SchweisOS repository must have a detached package signature. Unsigned packages may exist only as local developer artifacts.

Repository database:

Repository databases are produced with `repo-add`. The repository database must be regenerated or updated only from validated packages. Repository database signatures should be used for public repositories once the signing process is operational.

Mirror synchronization:

Mirrors receive already-signed packages, package signatures, repository databases, and repository database signatures. Mirrors must not sign or rebuild packages.

User installation:

Users install SchweisOS packages through pacman using `schweisos-keyring`, `schweisos-mirrorlist`, and `schweisos-pacman-config`. SchweisOS must preserve Arch's full-system update expectation.

## Canonical Endpoint Policy

`repo.schweisos.org` is the authoritative publication endpoint for SchweisOS package repositories.

Official mirrors must synchronize from the canonical endpoint or from designated SchweisOS artifact storage. Developer workstations must never be used as mirror synchronization sources.

Mirrors distribute already-signed artifacts, package signatures, repository databases, and repository database signatures. They are not trust anchors. Trust must come from verified installation media, `schweisos-keyring`, package signatures, repository signature policy, and pacman verification.

Community mirrors may be considered only after mirror eligibility, synchronization, health-check, and incident-response rules are documented.

## Repository Layout

Future public layout:

```text
repo/
  x86_64/
    schweisos/
      schweisos.db
      schweisos.db.sig
      schweisos.files
      schweisos.files.sig
      *.pkg.tar.zst
      *.pkg.tar.zst.sig
    schweisos-testing/
      schweisos-testing.db
      schweisos-testing.db.sig
      schweisos-testing.files
      schweisos-testing.files.sig
      *.pkg.tar.zst
      *.pkg.tar.zst.sig
    schweisos-staging/
      schweisos-staging.db
      schweisos-staging.db.sig
      schweisos-staging.files
      schweisos-staging.files.sig
      *.pkg.tar.zst
      *.pkg.tar.zst.sig
```

Only `x86_64` is planned for the first release family. Additional architectures require a future ADR.

`schweisos-staging`:

Maintainer integration repository. It may contain packages that are not ready for users. It is not enabled by default and must not be recommended for normal installations.

`schweisos-testing`:

Testing repository for release candidate packages. It may be used by testers and pre-release ISO builds. It is not enabled by default for stable users.

`schweisos`:

Stable SchweisOS repository. It is the only SchweisOS repository intended for default stable installations.

## Repository Availability by Release Phase

Alpha:

- Required: `schweisos`
- Optional internal: `schweisos-staging`
- Optional tester-facing: `schweisos-testing`

Alpha may use a small manually maintained repository, but packages must still be signed before public use.

Beta:

- Required: `schweisos`
- Required: `schweisos-testing`
- Internal: `schweisos-staging`

Beta must have documented promotion rules from staging to testing to stable.

Stable:

- Required: `schweisos`
- Available but disabled by default: `schweisos-testing`
- Internal only: `schweisos-staging`

Stable installations must enable only `schweisos` by default.

## Repository Trust Model

Trust begins with installation media and the SchweisOS keyring.

Fresh installation trust path:

```text
Verified ISO
  -> installed schweisos-keyring
  -> pacman trusts SchweisOS package signing keys
  -> schweisos-pacman-config enables official repositories
  -> pacman verifies package signatures during installation and updates
```

`schweisos-keyring`:

Owns public signing keys and trust metadata for official SchweisOS packages. It must be installed before official SchweisOS repositories are considered trusted.

Package signatures:

Every public repository package must be signed. Pacman must require trusted package signatures for official SchweisOS repositories.

Repository signatures:

Repository database signatures should be used for public repositories. During bootstrap, package signatures are the minimum hard requirement; unsigned repository databases must be treated as a temporary limitation and documented before any public alpha.

SigLevel:

Official SchweisOS repositories must not use `TrustAll`. The intended model is trusted package signatures and, when operational, signed repository databases.

## Package Ownership

SchweisOS-owned packages:

- `schweisos-release`
- `schweisos-keyring`
- `schweisos-mirrorlist`
- `schweisos-pacman-config`
- SchweisOS installer configuration packages
- SchweisOS desktop/defaults packages
- SchweisOS documentation packages
- SchweisOS meta packages
- SchweisOS release tooling packages, if later needed

Always upstream Arch packages:

- Linux kernel packages
- `pacman`
- `systemd`
- KDE Plasma packages
- Mesa and graphics stack packages
- Core libraries
- Toolchains
- Arch `core`, `extra`, and `multilib` packages

Any exception that forks or replaces an upstream Arch package requires a separate ADR with maintenance, security, and upgrade impact analysis.

## Release Flow

The release lifecycle is:

```text
Development
  -> Testing
  -> Repository
  -> ISO
  -> Stable release
```

Development:

Package changes are developed in the monorepo and built locally or on a build host.

Testing:

Packages are validated, installed in disposable environments, and promoted to `schweisos-staging` or `schweisos-testing` depending on maturity.

Repository:

Release candidates are signed, added to repository databases, and synchronized to artifact storage and mirrors.

ISO:

ISO builds consume the intended repository state. An ISO must not silently include packages that are not present in the documented release repository set unless it records that exception.

Stable release:

Stable releases are cut from a known repository state. Release notes, package manifest, checksums, and signatures must match the published artifacts.

## Build Infrastructure

The future build infrastructure has three roles:

Build server:

Builds packages in clean environments, runs validation, produces package artifacts, and stores build logs. It should not hold long-lived primary signing keys.

Signing host:

Signs validated package artifacts and repository databases. It should be more restricted than the build server. Long-lived signing keys should be protected from general build workloads.

Artifact storage:

Stores signed packages, signatures, repository databases, repository database signatures, build logs, manifests, and release evidence. Mirrors synchronize from artifact storage, not from developer machines.

For the one-maintainer phase, these roles may be performed manually on one controlled machine, but the process must remain documented as separate trust responsibilities.

## Security Considerations

Package signing:

Package signatures are mandatory for official public repositories. Local unsigned builds are developer artifacts only.

Bootstrap development endpoint:

`schweisos-mirrorlist` may ship a local file-based development endpoint under
`/var/lib/schweisos/local-repo/$repo/os/$arch` before public infrastructure
exists. This endpoint exists to make pacman repository integration parseable and
testable on a build host. It is not the canonical endpoint, a public mirror, a
publication source, or a trust anchor. Because SchweisOS repository policy
requires trusted package and repository database signatures, the endpoint
remains fail-closed until signed artifacts and approved public keys exist.

Key compromise recovery:

If a signing key is compromised, SchweisOS must revoke the affected key, publish an incident notice, ship an updated `schweisos-keyring`, stop publishing packages signed only by the compromised key, and provide user recovery instructions.

Repository key rotation:

Key rotation must overlap old and new keys long enough for users to receive `schweisos-keyring` updates. Rotation must be announced and tested before old keys are removed.

Mirror trust:

Mirrors are distribution channels, not trust anchors. Users must not need to trust mirror operators because pacman verifies package signatures and, when enabled, repository database signatures.

Signing separation:

Build machines may be compromised by package build workloads. Signing keys should not live on general build workers once infrastructure matures.

Signing key hierarchy:

SchweisOS will keep the long-lived master trust key offline and outside routine
development, build, and publication environments. Routine package and
repository database signing will use separately authorized operational keys on
a restricted signing host. Production public keys must not enter
`schweisos-keyring` until the release-signing policy and key admission process
are finalized.

The operational boundaries, bootstrap trust model, rotation, and revocation
strategy are defined in the
[Release Signing Workflow](../release/release-signing-workflow.md).

Rollback and downgrade risk:

The repository model must later define snapshot retention and downgrade policy. Until then, users should be guided toward normal full-system upgrades, not partial pinning.

## Future Scalability

One maintainer:

Manual builds and repository publication are acceptable if every step is documented, signed, and reproducible enough for review.

Small team:

Separate maintainers may own package groups, but package promotion should still require review for security-sensitive packages.

Larger contributor base:

Build infrastructure should move toward clean build workers, restricted signing hosts, automated validation, role-based permissions, signed release manifests, and documented emergency key rotation.

Long-term:

If package volume grows, SchweisOS may split source repositories or repository channels. This requires a future ADR because additional repositories increase user-facing complexity and maintenance burden.

## Alternatives Considered

Use Arch repository names such as `core`, `extra`, and `multilib`:

Rejected. These names imply Arch-owned package domains and would blur upstream boundaries.

Single repository only forever:

Rejected. It is simple, but it gives no clean place for testing and staged promotion.

Enable testing repository by default:

Rejected. It increases user risk and violates the goal of a stable default experience.

Unsigned bootstrap repository:

Rejected for public use. It may be acceptable only for private local development before trust infrastructure exists.

Custom package manager or updater:

Rejected. It violates Arch alignment and increases maintenance cost.

## Consequences

SchweisOS gets a repository model that is close to Arch, small enough for one maintainer, and scalable to a team.

The cost is early discipline: keyring, mirrorlist, pacman config, build logs, validation, and signing order must be designed before the project can honestly publish packages as official.

This architecture makes `schweisos-keyring`, `schweisos-mirrorlist`, and `schweisos-pacman-config` implementation decisions dependent on repository trust and release flow rather than isolated package convenience.
