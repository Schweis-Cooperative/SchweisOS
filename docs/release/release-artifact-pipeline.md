# SchweisOS Release Artifact Pipeline

Version: 0.3
Status: Implemented
Date: 2026-07-27

This document defines the repository-local release artifact pipeline for
SchweisOS. It consumes an already successful ISO build. It does not build
images, sign files, publish repositories, upload artifacts, or create GitHub
releases.

## Artifact Flow

```text
successful mkarchiso build
    -> build manifest and ISO output
    -> release artifact preparation
    -> checksum generation and verification
    -> release manifest generation
    -> release notes generation
    -> release artifact validation
    -> future signing and publication
```

The current implementation is `scripts/create-release-artifacts.sh`. It accepts
an existing ISO and successful build manifest, prepares an immutable local
release directory, validates it, and exits nonzero on any failure.

The canonical SchweisOS release identifier is `YYYY.MM.DD`. The
`schweisos-release` package version, Archiso `iso_version`, ISO filename,
release artifact directory, release manifest, and release validators all use
that same identifier. Manual renames and copied aliases are prohibited.

## Canonical Layout

Release artifacts are staged under `release/`:

```text
release/
    README.md
    YYYY.MM.DD/
        iso/
            schweisos-YYYY.MM.DD-x86_64.iso
        checksum/
            schweisos-YYYY.MM.DD-x86_64.iso.sha256
            schweisos-YYYY.MM.DD-x86_64.iso.b2
        manifests/
            build-manifest.json
            release-manifest.json
        logs/
            release-artifacts.log
        RELEASE_NOTES.md
```

SHA256 and BLAKE2b-512 checksums are mandatory for staged release artifacts.
Generated release directories are ignored by Git.

## Ownership

The ISO build wrapper owns `out/iso/`, `work/iso/kde/`, `cache/pacman/`, and
`logs/iso/`.

The release artifact pipeline owns only newly created `release/YYYY.MM.DD/`
directories. It never overwrites an existing release directory.

Release artifact validation is owned by `tests/validate-release-artifacts.sh`.
Disposable behavior tests are owned by `tests/test-release-artifacts.sh`.

## Failure Conditions

The pipeline fails closed when:

- The release identifier is not `YYYY.MM.DD`.
- The target release directory already exists.
- The ISO is missing, empty, symlinked, duplicated, or incorrectly named.
- The build manifest is missing, unsuccessful, dirty, inconsistent, or from an
  unsupported schema.
- Required build validators did not pass.
- SHA256 generation or verification fails.
- BLAKE2b-512 generation fails when `b2sum` is present.
- The output layout contains unexpected files.
- Any release path is world-writable.
- A symlink exists inside the release directory.
- Manifest values contain path traversal or inconsistent artifact metadata.

Failures stop the pipeline before publication. A partially prepared temporary
directory is removed unless the operating system prevents cleanup.

## Manifest Policy

`manifests/release-manifest.json` uses schema
`schweisos.release-artifact-manifest.v1`. It records:

- Release format version and release identifier.
- UTC generation and build timestamps.
- Git commit and clean tree state.
- ISO filename and size.
- SHA256 and BLAKE2b-512 checksum values.
- Profile, architecture, Archiso version, and `SOURCE_DATE_EPOCH`.
- Validator versions and validator results.

The manifest must not contain hostnames, usernames, machine IDs, home
directories, IP addresses, private keys, credentials, Git remotes, repository
endpoints, or signing material.

## Integration Points

Production package and repository signing exist as separate workflows. ISO
detached signing is not implemented. It belongs after artifact validation and
before external publication, using a documented role and verification path
that does not place offline primary material on the build host.

Repository publication and mirror synchronization are separate release
engineering steps. They consume already validated and signed artifacts; they do
not change checksums, manifests, or trust policy.
