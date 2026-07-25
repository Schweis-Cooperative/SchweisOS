# Scripts Directory

Version: 0.3
Status: Active
Date: 2026-07-25

This directory contains small orchestration scripts. Scripts must preserve the
ownership boundaries established by the project ADRs and must not hide package
building, signing, publication, or host configuration changes.

## ISO Build

`build-iso.sh` prepares canonical generated directories, registers a private
text log and privacy-minimized latest-attempt manifest, then enforces:

```text
validate-build-environment.sh
  -> validate-iso-profile.sh
  -> mkarchiso
  -> artifact and checksum validation
```

Every gate is mandatory and a failure prevents later steps. A successful
future run requires exactly one expected, non-empty ISO in a previously empty
`out/iso/`, creates and verifies its SHA256 sidecar, and records optional
BLAKE2b-512 in the manifest when `b2sum` is available.

A nonblocking repository lock prevents concurrent builds from sharing work,
output, cache, or manifest state. Existing work is accepted only with
`--clean`; cleanup refuses mounted work paths. Each attempt retains a private
text log and per-run manifest while also updating the canonical latest-attempt
`logs/iso/build-manifest.json`.

From the repository root:

```sh
./scripts/build-iso.sh
```

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
requires an existing successful ISO build output and build manifest, then
creates a new immutable `release/YYYY.MM/` directory with checksums, manifests,
notes, and validation evidence.

From the repository root:

```sh
./scripts/create-release-artifacts.sh \
  --release-id YYYY.MM \
  --iso out/iso/schweisos-YYYY.MM.DD-x86_64.iso \
  --build-manifest logs/iso/build-manifest.json
```

The script does not build, sign, upload, publish, or modify trust policy.
