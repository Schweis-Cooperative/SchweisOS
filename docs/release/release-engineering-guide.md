# SchweisOS Release Engineering Guide

Version: 0.3
Status: Active pre-alpha policy
Date: 2026-07-27

## Goal

Release engineering must make SchweisOS builds repeatable, signed, and
understandable. The project has a signed package repository pipeline and a
validated development ISO build; it does not yet have a publishable ISO release
pipeline.

Canonical repository lifecycle: [Package Repository Workflow](repository-workflow.md).

Signing architecture: [Release Signing Workflow](release-signing-workflow.md).

Release artifact pipeline: [Release Artifact Pipeline](release-artifact-pipeline.md).

## Release Artifacts

Public releases must publish:

- ISO image.
- Checksum file.
- Detached signature.
- Release notes.
- Known issues.
- Package repository snapshot or manifest.

Repository-local release artifacts are prepared under `release/YYYY.MM.DD/` only
after a successful ISO build. The artifact pipeline validates exactly one ISO,
generates and verifies mandatory SHA256 and BLAKE2b-512 checksums, generates
minimal release notes, writes a JSON manifest, and refuses to overwrite an
existing release directory. It does not sign, upload, publish, or relax any
trust policy.

## ISO Build Direction

SchweisOS uses upstream Archiso for live media. The current KDE profile stays
small and consumes signed packages rather than embedding package payloads.

Reference: [Archiso - ArchWiki](https://wiki.archlinux.org/title/Archiso).

## Versioning

SchweisOS release identifiers use `YYYY.MM.DD`. The same identifier is used by
`schweisos-release`, the Archiso profile `iso_version`, ISO filenames, release
artifact directories, release manifests, validators, and release notes. Public
release maturity labels such as alpha or beta belong in release notes and
roadmap documentation, not in the machine release identifier.

## Release Gates

Before any public ISO:

- Release artifact naming and manifest contracts agree.
- ISO checksum and detached-signature generation and verification pass.
- VM boot test passes.
- Installer smoke test passes.
- Package signatures work.
- Documentation matches behavior.
- Known limitations are listed.
- No telemetry or report submission occurs without consent.

At present, package and repository signatures are implemented. ISO detached
signing, public hosting, mirror synchronization, installer testing, and public
release qualification are not complete.

## Rollback

Rollback means the ability to recover release infrastructure, not automatic user system rollback. User-facing rollback requires a separate Btrfs/snapshot design.
