# SchweisOS Release Artifact Pipeline

Version: 0.6
Status: Implemented
Date: 2026-07-28

This document defines the repository-local release artifact pipeline for
SchweisOS. It consumes an already successful ISO build. It does not build
images, sign files, publish repositories, upload artifacts, or create GitHub
releases.

## Artifact Flow

```text
successful validated mkarchiso build
    -> built identity, boot-payload, and forensic validation
    -> build manifest, checksums, and ISO output
    -> release artifact preparation
    -> checksum generation and verification
    -> release manifest generation
    -> release notes generation
    -> release artifact validation
    -> future signing and publication
```

The current implementation is `scripts/create-release-artifacts.sh`. It accepts
an existing ISO and a canonical, exact-schema, successful build manifest,
prepares an immutable local release directory, validates it, and exits nonzero
on any failure.

The successful v2 build manifest is produced only after the wrapper's built-ISO
identity validator, boot validator, and ISO doctor pass. Staging binds the
supplied ISO's basename, byte size, and SHA256 to that manifest. A manually
copied ISO, an earlier image, or an ISO from a failed post-build gate is not
acceptable release input.

The canonical SchweisOS release identifier is `YYYY.MM.DD`. The
`schweisos-release` package version, Archiso `iso_version`, ISO filename,
release artifact directory, release manifest, and release validators all use
that same identifier. The stager requires the exact name
`schweisos-YYYY.MM.DD-x86_64.iso`; a well-formed but unequal date is rejected.
The profile is read from the build manifest. If the caller supplies
`--profile`, it is an equality assertion and cannot relabel the artifact.
Manual renames, copied aliases, and caller-invented profile provenance are
prohibited.

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
- The release identifier, release directory, and date embedded in the ISO
  filename differ.
- The target release directory already exists.
- The ISO is missing, empty, symlinked, duplicated, or incorrectly named.
- The build manifest is missing, unsuccessful, dirty, inconsistent, or from an
  unsupported schema.
- Either manifest is noncanonical or has missing, extra, duplicate, ambiguous,
  or incorrectly typed fields.
- Any pre- or post-build validator did not pass.
- The ISO basename, size, or SHA256 differs from the build manifest.
- A supplied profile differs from build-manifest provenance.
- Build timestamp, Git commit, Archiso version, `SOURCE_DATE_EPOCH`, profile, or
  validator results differ across the build and release manifests.
- SHA256 generation or verification fails.
- `b2sum` is unavailable, or BLAKE2b-512 generation or verification fails.
- The output layout contains unexpected files.
- Any release path is world-writable.
- A symlink exists inside the release directory.
- Manifest values contain path traversal or inconsistent artifact metadata.

Failures stop the pipeline before publication. A partially prepared temporary
directory is removed unless the operating system prevents cleanup.

## Manifest Policy

Both JSON manifests must byte-match their `jq --indent 2` normalization. Their
validators require exact top-level and nested key sets, so missing, extra,
duplicated, ambiguously parsed, or incorrectly typed fields are fatal rather
than ignored.

The copied build manifest uses
`schweisos.iso-build-manifest.v2`. Its exact top-level key set is:

```text
schema, build_id, build_timestamp_utc, finished_at_utc, status, stage,
exit_code, git, host, archiso_version, source_date_epoch, epoch_origin,
build_mode, profile, expected_iso_name, validation, mkarchiso_exit_code,
artifact_candidate_count, artifact, build_log, failure_code
```

Its exact nested objects are `git` with `commit`, `dirty_at_start`, and
`dirty_at_finish`; `host` with `id` and `architecture`; `validation` with
`build_environment`, `installer_config`, `iso_profile`, `built_iso_identity`,
`built_iso_boot`, `built_iso_forensics`, and `artifact`; and the artifact
object with `name`, `size_bytes`, `sha256`, `blake2b_512`, and
`sha256_file`.

Release staging accepts only the completed-success release form: clean Git
state, `build_mode=release`, `epoch_origin=environment`, canonical Arch x86_64
host provenance, `status=success`, `stage=complete`, zero wrapper and
`mkarchiso` exit codes, one artifact candidate, every validation result equal
to `pass`, internally consistent artifact/sidecar names, positive size, valid
SHA256, non-null BLAKE2b-512, and a null failure code.
`tests/validate-iso-build-manifest.sh --release` then recomputes the supplied
ISO basename, byte size, SHA256, and BLAKE2b-512 and requires all four to
match.

`manifests/release-manifest.json` uses schema
`schweisos.release-artifact-manifest.v2`. Its exact top-level key set is:

```text
schema, schema_version, release_format_version, release_id,
generated_at_utc, build_timestamp_utc, git_commit, git_tree_state,
iso_filename, iso_size_bytes, sha256, sha256_file, blake2b_512,
blake2b_512_file, profile, arch, archiso_version, source_date_epoch,
validator_versions, validator_results
```

It records:

- Release format version and release identifier.
- UTC generation and build timestamps.
- Git commit and clean tree state.
- ISO filename and size.
- SHA256 and BLAKE2b-512 checksum values.
- Profile, architecture, Archiso version, and `SOURCE_DATE_EPOCH`.
- The release-artifact validator version and explicit results for the
  build-environment, installer-config, ISO-profile, built-identity,
  built-boot, built-forensics, aggregate artifact, and release-artifact gates.

The fixed schema values are `schema_version` as numeric `2`,
`release_format_version` as string `"2"`, `git_tree_state` as `clean`, and
`arch` as `x86_64`. ISO size is a positive integral JSON number and
`SOURCE_DATE_EPOCH` is a nonnegative integral JSON number; checksum and
timestamp fields have fixed string formats.

`validator_versions` contains exactly
`release_artifact_validator: "2"`. `validator_results` contains exactly the
eight documented gates, all set to `pass`. The release validator revalidates the
copied build manifest against the staged ISO, then cross-checks release
identifier and filename, profile, build timestamp, Git commit, Archiso version,
`SOURCE_DATE_EPOCH`, ISO size, SHA256, BLAKE2b-512, and validator results.
It also regenerates `RELEASE_NOTES.md` and `logs/release-artifacts.log` from
the validated manifest fields and rejects any drift.

The manifest must not contain hostnames, usernames, machine IDs, home
directories, IP addresses, private keys, credentials, Git remotes, repository
endpoints, or signing material.

No current successful ISO evidence covers the newly changed first-boot payload,
Plymouth watchdog, built-boot validator, or these exact v2 contracts. A fresh
production-host build and subsequent staging run must create that evidence
later. Older local ISO files and failed or legacy manifests are not acceptable
inputs.

## Integration Points

Production package and repository signing exist as separate workflows. ISO
detached signing is not implemented. It belongs after artifact validation and
before external publication, using a documented role and verification path
that does not place offline primary material on the build host.

Repository publication and mirror synchronization are separate release
engineering steps. They consume already validated and signed artifacts; they do
not change checksums, manifests, or trust policy.
