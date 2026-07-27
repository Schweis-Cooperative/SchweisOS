# SchweisOS Build Documentation

Version: 0.6
Status: Active
Date: 2026-07-27

This directory documents the canonical SchweisOS ISO build workflow. The
orchestration wrapper is `scripts/build-iso.sh`; upstream `mkarchiso` remains
responsible for image construction.

## ISO Build Host

The canonical build host is an up-to-date Arch Linux x86_64 system using
official Arch packages for the ISO toolchain. Derivatives are useful
development systems but are not canonical release build hosts.

The host must provide:

- Sufficient space for work state, output, package cache, and logs.
- Trusted access to the required Arch and SchweisOS repositories.
- `sudo` or existing root privilege for `mkarchiso` only.
- A clean Git worktree for an official release artifact.

The environment validator rejects updates known to the host's current pacman
synchronization databases. It does not refresh those databases because
validation must remain network-free and must not mutate host state. The
operator is responsible for synchronizing and fully upgrading the host first.

The same gate compares every SchweisOS identity package version declared by
its repository PKGBUILD with the version visible through the build host's
configured `schweisos` synchronization database. A missing or stale package
fails before profile validation and `mkarchiso`. This prevents an ISO from
silently embedding an older identity package than the source tree being built.
Refreshing or publishing repository metadata remains an explicit repository
operation outside the ISO wrapper.

The initial space policy requires at least 20 GiB free on the filesystems
backing the generated locations. This is a conservative engineering threshold,
not an estimate of the final ISO size. The validator checks available blocks,
not inode totals, because filesystems such as Btrfs do not expose meaningful
fixed inode counts.

## Required Packages

The machine-readable direct package contract is
[`build/build-dependencies.txt`](../../build/build-dependencies.txt):

- `archiso`
- `bash`
- `git`
- `pacman`
- `sudo`
- `util-linux`

These are SchweisOS's direct dependencies. Arch's current `archiso` package
owns its runtime dependencies, including filesystem, archive, ISO, bootstrap,
and FAT tooling. SchweisOS does not duplicate that transitive list in its
manifest. The dependency validator still checks every required command and
its exact Arch package owner, so a missing transitive dependency or unexpected
replacement fails closed. It does not pin a historical Archiso version; the
current upstream Arch package is authoritative.

Optional later review tools include `shellcheck`, `namcap`, `diffoscope`,
`qemu-desktop`, `edk2-ovmf`, and `gnupg`. They are not part of the initial image
build gate and do not imply that signing keys belong on the build host.

## Directory Layout

Generated state is separated from the version-controlled profile:

```text
iso/profiles/kde/       version-controlled profile
work/iso/kde/           disposable Archiso work state
out/iso/                ISO and checksum output
cache/pacman/           reusable package cache
logs/iso/               text logs and latest-attempt manifest
```

The generated paths are repository-relative, Git-ignored, and never sources of
truth. The wrapper and environment validator reject symlinked or noncanonical
locations.

## Complete Build Pipeline

The wrapper executes this ordered pipeline:

```text
safe path and log initialization
  -> validate-build-environment.sh
  -> validate-iso-profile.sh
  -> epoch and expected-name preparation
  -> output and privilege preflight
  -> build-local pacman configuration
  -> mkarchiso
  -> artifact and checksum validation
  -> final build manifest
```

A failed gate prevents every later gate from running. In particular:

- A failed environment gate leaves profile validation as `not_run` and never
  invokes `mkarchiso`.
- A failed profile gate never invokes `mkarchiso`.
- A nonzero `mkarchiso` result never becomes an artifact-validation success.
- A checksum failure makes the complete build fail.

Run the canonical workflow from the repository root:

```sh
./scripts/build-iso.sh
```

Use `--clean` only to discard the contents of `work/iso/kde/` after the safety
gates pass:

```sh
./scripts/build-iso.sh --clean
```

The build-local pacman configuration is generated under `work/iso/kde/` from
the profile input and the installed SchweisOS repository snippet. The default
mode is `SCHWEISOS_ISO_BUILD_MODE=development`. Development ISO builds keep
trusted package signatures required, but allow an unsigned local repository
database with:

```ini
SigLevel = PackageRequired PackageTrustedOnly DatabaseOptional DatabaseTrustedOnly
```

The source package configuration remains stricter for future release use:
`schweisos-pacman-config` continues to ship `SigLevel = Required TrustedOnly`.
Setting `SCHWEISOS_ISO_BUILD_MODE=release` preserves that stricter repository
database signature policy in the generated build-local configuration. This
distinction lets local Archiso builds consume the unsigned bootstrap
`schweisos.db` without changing release or runtime trust policy.

The wrapper never cleans ISO output. An existing ISO or ISO checksum must be
archived or removed explicitly before another build so stale output cannot be
mistaken for newly generated evidence.

## Build Environment Validation

First validate the machine-readable dependency policy and current host:

```sh
tests/validate-build-dependencies.sh
```

The validator has no host-check bypass mode. It always verifies both the
manifest and installed host state; individual PASS lines still provide useful
static authoring evidence when the overall result is blocked by the host.

Run the network-free host gate independently from any repository subdirectory:

```sh
tests/validate-build-environment.sh
```

The environment gate invokes the dependency validator in full mode and then
prints one concise PASS/FAIL summary covering:

- Exact canonical Arch identity and x86_64 architecture.
- An unprivileged caller, preserving narrow `sudo` use for cleanup and
  `mkarchiso` only.
- ADR-013 direct packages, required commands, and exact command provenance.
- Updates known to current pacman synchronization databases.
- Pacman's required, trusted package-signature policy.
- Required project directories and files.
- Readable source, executable scripts, and no world-writable project paths.
- Canonical, ignored, writable, non-world-writable generated locations and
  20 GiB space.
- Broken or unexpected source symlinks.
- Credential patterns and private signing-key material in Git-visible inputs.
- Installed SchweisOS host integration, a configured publication source,
  and conservative repository signature policy.
- SchweisOS identity package versions in the configured repository. In
  `SCHWEISOS_ISO_BUILD_MODE=development`, source/repository version drift is
  reported as a warning so local identity work can build against the current
  trusted bootstrap repository. In `SCHWEISOS_ISO_BUILD_MODE=release`, the same
  drift is fatal.

The validator does not run `sudo`, refresh databases, install packages, access
the network, invoke the profile validator, invoke `mkarchiso`, inspect user
keyrings, or scan home directories. Public trust-anchor keys may later be
legitimate `schweisos-keyring` inputs; private keys and secret-key containers
are prohibited.

## ISO Profile Validation

Run the profile-only static gate separately. It needs basic parser tooling such
as `bash` and `pacman-conf`, but it does not require Archiso to be installed or
an Arch build host:

```sh
tests/validate-iso-profile.sh
```

It checks:

- Required Archiso files and the `profiledef.sh` contract.
- UTC-stable metadata derived from a fixed `SOURCE_DATE_EPOCH`.
- Valid, group-sorted, duplicate-free packages.
- UEFI systemd-boot templates and supported placeholders.
- The baseline mkinitcpio hooks and kernel preset.
- The explicit live-overlay allowlist and shipped permissions.
- Symlink targets, repository endpoint absence, key material, and package
  payload absence.
- Build-time pacman syntax and signature policy in a disposable sysroot.

The parser fixture uses the real version-controlled SchweisOS bootstrap files.
It does not modify `/etc`, contact repositories, or create an endpoint.

## Reproducibility Preparation

The profile derives its date-based label and version from `SOURCE_DATE_EPOCH`
in UTC. For a new or explicitly clean build, the wrapper uses a caller-provided
epoch or current time as a development-only default. The chosen value is
recorded in the log and manifest and passed across the privilege boundary to
`mkarchiso`.

Existing Archiso work is never resumed automatically. Upstream run-once
markers are not bound to the current Git commit or profile inputs and can skip
steps after sources change. A non-empty `work/iso/kde/` therefore requires an
explicit `--clean`. Before deletion, the wrapper holds a repository-wide build
lock, rejects mountpoints at or beneath the work directory, and confines
cleanup to the work filesystem.

Stable package ordering is enforced by profile validation. SchweisOS does not
add its own archive-ordering layer where upstream Archiso already owns ordering
and timestamps. Reproducibility remains a goal, not a claim: it requires two
clean builds with equal source revision, package repository state, toolchain,
and epoch.

Known limits include rolling repository state, FAT/mtools metadata, package
install hooks, initramfs generation, and tool-version differences. Repository
snapshotting and measured comparisons belong to later release engineering.

## Expected Outputs

A successful build for the current `0.2.0` profile produces:

- `out/iso/schweisos-0.2.0-x86_64.iso`
- `out/iso/schweisos-0.2.0-x86_64.iso.sha256`
- `work/iso/kde/build_date`
- reusable content in `cache/pacman/`
- `logs/iso/build-<id>.log`
- `logs/iso/build-<id>.json`
- `logs/iso/build-manifest.json`

Release-ready artifact staging is a separate post-build subsystem. Its current
`YYYY.MM`/date-based filename contract predates the versioned Archiso profile
and does not accept `schweisos-0.2.0-x86_64.iso`. The mismatch is fail-closed:
do not rename or copy an ISO to bypass it. Reconcile the two contracts and
update their tests before using this example:

```sh
scripts/create-release-artifacts.sh \
  --release-id YYYY.MM \
  --iso out/iso/schweisos-YYYY.MM.DD-x86_64.iso \
  --build-manifest logs/iso/build-manifest.json
```

The release artifact step is intentionally not invoked when build validation
fails and never calls `mkarchiso` itself. It creates `release/YYYY.MM/`
atomically, validates the staged directory, and refuses to overwrite existing
release evidence.

The production package/repository signing workflow is operational, but ISO
detached signing is not yet integrated into this artifact stage. A successful
build and checksum therefore remain development evidence, not a publishable
release by themselves.

After `mkarchiso`, exactly one `.iso` must exist in `out/iso/`. It must have the
profile-derived name, be a regular non-symlink file, and have a positive byte
size. No arbitrary minimum size is asserted before real artifacts have been
measured.

SHA256 generation and verification are mandatory. The atomic `.sha256`
sidecar contains only the ISO basename and is verified both before and after
placement. If `b2sum` is installed, a verified BLAKE2b-512 digest is recorded
in the manifest; no second sidecar is created yet.

## Build Manifest

Every attempted build maintains a per-run `logs/iso/build-<id>.json` manifest
and atomically replaces `logs/iso/build-manifest.json` as a latest-attempt
view. Earlier per-run evidence is not overwritten. The schema identifier is
`schweisos.iso-build-manifest.v1`. It records:

- UTC build and completion timestamps.
- Git commit and start/finish dirty-state booleans, without changed-file names.
- Distribution ID and architecture, without host identity.
- Archiso version and `SOURCE_DATE_EPOCH` when available.
- Expected artifact name.
- Environment, profile, and artifact validation states.
- `mkarchiso` exit status when invoked.
- Artifact basename, size, SHA256, and optional BLAKE2b-512.
- Text-log basename and a stable failure code.

Unavailable values remain explicit JSON `null`; unreached validators use
`not_run`. The manifest never contains usernames, home paths, hostnames,
machine IDs, UIDs, environment dumps, Git remotes, repository URLs,
credentials, key fingerprints, private keys, changed-file lists, or raw error
messages. Detailed diagnostics belong in the text log.

The timestamped text log is created with private permissions. Upstream
`mkarchiso` and pacman diagnostics may still contain local absolute paths or
configured repository URLs, so logs must be reviewed before they are shared.
Both manifests are installed with read-only-for-others permissions and contain
only the bounded metadata above.

The manifest and hashes are integrity and audit evidence. They are not a
signature, authenticity proof, or release authorization.

## Ownership Boundary

`scripts/build-iso.sh` owns orchestration, the build-local cache directive,
logging, invocation, and artifact checks. Host policy is centralized in
`validate-build-environment.sh`; profile policy is centralized in
`validate-iso-profile.sh`.

The wrapper does not:

- Build or modify SchweisOS packages.
- Change global pacman configuration or trust policy.
- Generate, import, or use signing keys.
- Sign packages, repositories, checksums, or ISOs.
- Publish artifacts or synchronize mirrors.
- Edit the ISO profile.
- Add branding, installer policy, or desktop configuration.

The ISO consumes already published, trusted package artifacts. Package build,
repository publication, ISO construction, signing, and release publication
remain separate workflows.

## Current Build Readiness

The ordered validators, dependency manifest, failure manifest, invocation
path, and post-build checks have produced and inspected a development ISO. The
original pre-build blocker snapshot is preserved as historical evidence in
[`environment-readiness.md`](environment-readiness.md).

Every clean build still requires all of the following:

- A canonical Arch Linux x86_64 host.
- A fully synchronized and upgraded system.
- Every direct package in `build/build-dependencies.txt` and the complete
  upstream Archiso command toolchain.
- Host-installed `schweisos-keyring`, `schweisos-mirrorlist`, and
  `schweisos-pacman-config` through an approved bootstrap process.
- A real signed SchweisOS repository source resolving every profile package,
  including all five SchweisOS packages, under `Required TrustedOnly`.
- Both validators passing, empty or explicitly cleaned work state, and no
  pre-existing ISO or ISO checksum in `out/iso/`.

No placeholder endpoint, fake mirror, unsigned production shortcut, or
signature-policy exception may satisfy these conditions. A previous successful
build is never evidence that a later host or repository state may skip them.

Related decision: [ADR-013 ISO Build Workflow](../adr/ADR-013-iso-build-workflow.md).
