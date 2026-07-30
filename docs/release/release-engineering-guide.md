# SchweisOS Release Engineering Guide

Version: 0.4
Status: Active pre-alpha policy
Date: 2026-07-28

## Goal

Release engineering must make SchweisOS builds repeatable, signed, and
understandable. The project has a signed package repository pipeline and a
source-configured ISO build and validation pipeline; it does not yet have a
publishable ISO release pipeline. No current successful ISO evidence covers the
new first-boot defaults, Plymouth watchdog, built-boot validator, or exact v2
manifest contract. A fresh production-host build must create that evidence
later.

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
after a successful ISO build. The artifact pipeline requires a canonical,
exact-schema release-mode `schweisos.iso-build-manifest.v2`, revalidates both
completed-image gates, and binds the actual ISO basename, byte size, SHA256,
and BLAKE2b-512 to that manifest. It also binds the requested release
identifier to the date in the ISO filename and derives profile provenance from
the build manifest.

The pipeline then validates exactly one ISO, generates and verifies mandatory
SHA256 and BLAKE2b-512 checksums, generates minimal release notes, writes a
canonical exact-schema release manifest, validates the generated notes and log
against that manifest, and refuses to overwrite an existing release directory.
It does not sign, upload, publish, or relax any trust policy.

## ISO Build Direction

SchweisOS uses upstream Archiso for live media. The current KDE profile stays
small and consumes signed packages rather than embedding package payloads.

Reference: [Archiso - ArchWiki](https://wiki.archlinux.org/title/Archiso).

## Versioning

SchweisOS release identifiers use `YYYY.MM.DD`. The same identifier is used by
`schweisos-release`, the Archiso profile `iso_version`, ISO filenames, release
artifact directories, release manifests, validators, and release notes. Public
release maturity labels such as alpha or beta belong in release notes and
roadmap documentation, not in the machine release identifier. Release staging
requires the exact filename `schweisos-YYYY.MM.DD-x86_64.iso`; independently
well-formed but unequal dates are rejected.

## Release Gates

Before any public ISO:

- The built-ISO identity, boot/root/initramfs, and forensic doctor gates pass
  on the exact image.
- The canonical build and release manifest schemas pass without missing, extra,
  duplicate, ambiguous, or incorrectly typed fields.
- Release identifier, profile, ISO name, byte size, SHA256, build timestamp,
  Git commit, Archiso version, and `SOURCE_DATE_EPOCH` provenance agree across
  the image and manifests.
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
