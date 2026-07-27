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

Repository-local release artifacts are prepared under `release/YYYY.MM/` only
after a successful ISO build. The artifact pipeline validates exactly one ISO,
generates and verifies mandatory SHA256 checksums, generates minimal release
notes, writes a JSON manifest, and refuses to overwrite an existing release
directory. It does not sign, upload, publish, or relax any trust policy.

The artifact stager currently expects a date-based ISO filename, while the
Archiso profile produces a semantic-version filename. This mismatch must be
resolved in code and tests before the stager is used. Renaming an artifact by
hand is not an accepted release step.

## ISO Build Direction

SchweisOS uses upstream Archiso for live media. The current KDE profile stays
small and consumes signed packages rather than embedding package payloads.

Reference: [Archiso - ArchWiki](https://wiki.archlinux.org/title/Archiso).

## Versioning

Use human-readable release tracks:

- `alpha`
- `beta`
- `1.0`
- `1.x`
- `2.x`

The current profile uses a semantic version in the ISO filename and records
timestamps separately in build manifests. Any version-scheme change must update
the profile, build wrapper, artifact stager, validators, and release notes as
one reviewed contract. Public releases require release notes and verification
material.

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
