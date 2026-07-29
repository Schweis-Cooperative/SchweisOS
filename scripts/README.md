# Scripts Directory

Version: 0.6
Status: Active
Date: 2026-07-29

This directory contains small orchestration scripts. Scripts must preserve the
ownership boundaries established by the project ADRs and must not hide package
building, signing, publication, or host configuration changes.

## ISO Build

`build-iso.sh` prepares canonical generated directories, registers a private
text log and privacy-minimized latest-attempt manifest, then enforces:

```text
validate-build-environment.sh
  -> validate-installer-config.sh
  -> validate-iso-profile.sh
  -> mkarchiso
  -> validate-built-iso-identity.sh
  -> validate-built-iso-boot.sh
  -> artifact checksum validation
  -> final schweisos.iso-build-manifest.v2
```

Every gate is mandatory and a failure prevents later steps. A successful run
requires exactly one expected, non-empty ISO in a previously empty
`out/iso/`, requires both completed-image validators to pass before checksum
publication, creates and verifies its SHA256 sidecar, and records optional
BLAKE2b-512 in the manifest when `b2sum` is available. A manifest is eligible
for release staging only when it was produced in release mode from a clean Arch
x86_64 host with an explicit environment `SOURCE_DATE_EPOCH` and a non-null
BLAKE2b-512 value.

A nonblocking repository lock prevents concurrent builds from sharing work,
output, cache, or manifest state. Existing work is accepted only with
`--clean`; cleanup refuses mounted work paths. Each attempt retains a private
text log and per-run manifest while also updating the canonical latest-attempt
`logs/iso/build-manifest.json`.

From the repository root:

```sh
./scripts/build-iso.sh
```

The current profile is configured to produce
`out/iso/schweisos-2026.07.27-x86_64.iso`.

To discard only the generated `work/iso/kde/` state before building:

```sh
./scripts/build-iso.sh --clean
```

The script does not build packages, weaken pacman signature policy, sign or
publish artifacts, or modify host pacman configuration. See
[`docs/build/README.md`](../docs/build/README.md) and ADR-013 for the required
host and repository prerequisites.

## Release Artifacts

`create-release-artifacts.sh` owns post-build release artifact staging. It
requires an existing ISO and a canonical, exact-schema, successful
`schweisos.iso-build-manifest.v2`. The completed-manifest validator binds the
ISO basename, byte size, SHA256, and BLAKE2b-512 to the supplied bytes before
staging. The release identifier must also equal the date embedded in the ISO
filename, and the release profile is derived from the build manifest; an
optional `--profile` assertion must match it exactly.

The tool then creates a new immutable `release/YYYY.MM.DD/` directory with
checksums, manifests, notes, and validation evidence.

It uses the same `YYYY.MM.DD` release identifier as `schweisos-release`, the
Archiso profile, the ISO filename, and release validation. SHA256 and
BLAKE2b-512 checksum files are both mandatory in staged release evidence.

From the repository root:

```sh
./scripts/create-release-artifacts.sh \
  --release-id YYYY.MM.DD \
  --iso out/iso/schweisos-YYYY.MM.DD-x86_64.iso \
  --build-manifest logs/iso/build-manifest.json
```

The script does not build, sign, upload, publish, or modify trust policy.

No current successful ISO evidence covers the newly added boot payload,
completed-image validators, or exact v2 manifest contract. That evidence must
be created later by a fresh production-host build; an older or manually copied
ISO is not a substitute.
