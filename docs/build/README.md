# SchweisOS Build Documentation

Version: 1.0
Status: Active
Date: 2026-07-30

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

Clean-source inspection explicitly includes all untracked paths and overrides
local `status.showUntrackedFiles` preferences. A user Git configuration cannot
turn an untracked repository input into false clean-build evidence.

The environment validator rejects updates known to the host's current pacman
synchronization databases. It does not refresh those databases because
validation must remain network-free and must not mutate host state. The
operator is responsible for synchronizing and fully upgrading the host first.

The same gate compares every SchweisOS identity package version declared by
its repository PKGBUILD with the version visible through the build host's
configured `schweisos` synchronization database. A missing or stale package
fails before profile validation and `mkarchiso`. This prevents an ISO from
silently embedding an older identity package than the source tree being built.
The rule is identical in development and release modes. For
`schweisos-branding`, the gate also opens the selected package and requires the
canonical regular logo path and SHA256 to match
`branding/assets/logo/schweisos.png`.
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
- `desktop-file-utils`
- `diffutils`
- `git`
- `jq`
- `mkinitcpio`
- `pacman`
- `sudo`
- `util-linux`

These are SchweisOS's direct dependencies. `desktop-file-utils` supplies
`desktop-file-validate` for installer launcher validation. `diffutils` supplies
`cmp` for byte-exact source and canonical-JSON comparisons. `jq` owns exact
JSON-schema validation and structured manifest reads. `mkinitcpio` supplies
`lsinitcpio`, which the post-build initramfs validator invokes directly.
Arch's current `archiso` package owns its runtime dependencies, including
filesystem, archive, ISO, bootstrap, and FAT tooling. SchweisOS does not
duplicate that transitive list in its manifest. The dependency validator still
checks every required command and its exact Arch package owner, so a missing
transitive dependency or unexpected replacement fails closed. It does not pin a
historical Archiso version; the current upstream Arch package is authoritative.

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
  -> validate-installer-config.sh
  -> validate-iso-profile.sh
  -> epoch and expected-name preparation
  -> output and privilege preflight
  -> build-local pacman configuration
  -> mkarchiso
  -> built-ISO identity validation
  -> built-ISO boot/root/initramfs validation
  -> built-ISO forensic doctor validation
  -> artifact checksum validation
  -> final build manifest
```

A failed gate prevents every later gate from running. In particular:

- A failed environment gate leaves installer/profile validation as `not_run`
  and never invokes `mkarchiso`.
- A failed installer configuration gate leaves profile validation as `not_run`
  and never invokes `mkarchiso`.
- A failed profile gate never invokes `mkarchiso`.
- A nonzero `mkarchiso` result never becomes an artifact-validation success.
- A built identity, boot-payload, or forensic doctor failure prevents checksum
  publication and leaves the build attempt failed.
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

The development exception does not allow unsigned package artifacts. When the
configured SchweisOS endpoint is a local `file://` repository, the build
environment validator reads `schweisos.db` before `mkarchiso` and fails if any
database entry lacks its referenced package file or detached `.sig` sidecar.
This keeps missing package signatures from surfacing later as an interactive
pacman transaction failure.

Development mode also does not allow source/package drift. Updating Git does
not update a signed repository: every `schweisos-*` package listed in the ISO
profile must match its PKGBUILD before either mode may invoke Archiso. The
resolved branding package must contain the current canonical logo payload, not
merely a valid signature over an older package.

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
- For a local `file://` SchweisOS endpoint, the presence of each package file
  and detached `.sig` sidecar referenced by `schweisos.db`.
- SchweisOS identity package versions in the configured repository; drift is
  fatal in every build mode.
- The selected `schweisos-branding` archive contains exactly one regular
  canonical runtime logo, no stale runtime logo path, and the same logo SHA256
  as repository source.

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
- Noninteractive live first-boot behavior through exact
  `systemd.firstboot=no`, `LANG=C.UTF-8`, and UTC contracts.
- The approved mkinitcpio hook contract and kernel preset, including the
  live-boot `kms`, `plymouth`, `archiso_loop_mnt`, and
  `schweisos_iso_file_fallback` hook extensions.
- Propagated Plymouth client failures, bounded quit waiting, guarded normal
  handoff, and automatic diagnostic fallback.
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

A successful build for the current release profile is configured to produce:

- `out/iso/schweisos-YYYY.MM.DD-x86_64.iso`
- `out/iso/schweisos-YYYY.MM.DD-x86_64.iso.sha256`
- `work/iso/kde/build_date`
- reusable content in `cache/pacman/`
- `logs/iso/build-<id>.log`
- `logs/iso/build-<id>.json`
- `logs/iso/build-manifest.json`

Release-ready artifact staging is a separate post-build subsystem. It consumes
an exact ISO artifact and a canonical, exact-schema, successful
`schweisos.iso-build-manifest.v2`. Before staging, the completed-manifest
validator runs in release mode and binds the supplied ISO's basename, byte
size, SHA256, and BLAKE2b-512 to the manifest. The requested `YYYY.MM.DD` must
equal the date in the ISO filename, and the release profile is derived from
the build manifest; an optional `--profile` assertion must match that value:

```sh
scripts/create-release-artifacts.sh \
  --release-id YYYY.MM.DD \
  --iso out/iso/schweisos-YYYY.MM.DD-x86_64.iso \
  --build-manifest logs/iso/build-manifest.json
```

The release artifact step is intentionally not invoked when build validation
fails and never calls `mkarchiso` itself. It creates `release/YYYY.MM.DD/`
atomically, validates the staged directory, and refuses to overwrite existing
release evidence.

Old local files under `out/iso/`, including older date-named ISOs, are not
release evidence. Production ISO evidence is produced by the release pipeline
on the approved production build host after the current commit has been pulled
and all mandatory validators have passed.

The production package/repository signing workflow is operational, but ISO
detached signing is not yet integrated into this artifact stage. A successful
build and checksum therefore remain development evidence, not a publishable
release by themselves.

After `mkarchiso`, exactly one `.iso` must exist in `out/iso/`. It must have the
profile-derived name, be a regular non-symlink file, and have a positive byte
size. No arbitrary minimum size is asserted before real artifacts have been
measured.

Before checksums are published, `validate-built-iso-identity.sh` verifies the
installed release identity and `validate-built-iso-boot.sh` verifies the
resolved branding and installer configuration versions, live defaults, systemd
units, Plasma session, and the Plymouth theme/script/plugin/logo inside the
initramfs. `scripts/schweisos-doctor` then performs read-only completed-ISO
forensics: ISO boot layout, native and loopback command lines, embedded
`airootfs.sfs` SHA512, SquashFS superblock metadata with live-media xattrs
disabled, package inventory, and Calamares offline welcome policy. These gates
use ignored work or temporary directories and remove only their own extraction
state.

SHA256 generation and verification are mandatory for ISO build output. The
atomic `.sha256` sidecar contains only the ISO basename and is verified both
before and after placement. If `b2sum` is installed, a verified BLAKE2b-512
digest is recorded in the build manifest. Release-eligible staging requires a
non-null BLAKE2b-512 value and then creates mandatory SHA256 and BLAKE2b-512
checksum files.

## Build Manifest

Every attempted build maintains a per-run `logs/iso/build-<id>.json` manifest
and atomically replaces `logs/iso/build-manifest.json` as a latest-attempt
view. Earlier per-run evidence is not overwritten. The schema identifier is
`schweisos.iso-build-manifest.v2`. It records:

- UTC build and completion timestamps.
- Git commit and start/finish dirty-state booleans, without changed-file names.
- Distribution ID and architecture, without host identity.
- Archiso version, `SOURCE_DATE_EPOCH`, its origin, build mode, and the
  profile.
- Expected artifact name and candidate count.
- Environment, installer, profile, built-ISO identity, built-ISO boot,
  built-ISO forensics, and aggregate artifact validation states.
- `mkarchiso` exit status when invoked.
- Artifact basename, size, SHA256, and BLAKE2b-512 when available during the
  build.
- Text-log basename and a stable failure code.

Unavailable values remain explicit JSON `null`; unreached validators use
`not_run`. The manifest never contains usernames, home paths, hostnames,
machine IDs, UIDs, environment dumps, Git remotes, repository URLs,
credentials, key fingerprints, private keys, changed-file lists, or raw error
messages. Detailed diagnostics belong in the text log.

The v2 writer always emits this exact top-level key set:

```text
schema, build_id, build_timestamp_utc, finished_at_utc, status, stage,
exit_code, git, host, archiso_version, source_date_epoch, epoch_origin,
build_mode, profile, expected_iso_name, validation, mkarchiso_exit_code,
artifact_candidate_count, artifact, build_log, failure_code
```

The nested objects are also exact: `git` contains only `commit`,
`dirty_at_start`, and `dirty_at_finish`; `host` contains only `id` and
`architecture`; `validation` contains only `build_environment`,
`installer_config`, `iso_profile`, `built_iso_identity`, `built_iso_boot`,
`built_iso_forensics`, and `artifact`; and the artifact object contains only
`name`, `size_bytes`, `sha256`, `blake2b_512`, and `sha256_file`.

`tests/validate-iso-build-manifest.sh` owns the completed-success contract. It
requires the file to byte-match its `jq --indent 2` normalization and rejects
missing, extra, duplicated, ambiguously parsed, incorrectly typed, or
noncanonical fields. A release-eligible manifest must describe a clean Git
tree, `build_mode=release`, `epoch_origin=environment`, a canonical Arch
x86_64 host, `status=success`, `stage=complete`, zero wrapper and `mkarchiso`
exit codes, exactly one artifact candidate, all six validation results as
`pass`, an artifact name equal to `expected_iso_name`, a positive integer
size, a valid SHA256, a non-null BLAKE2b-512 value, the canonical SHA256
sidecar name, and no failure code. BLAKE2b-512 remains nullable only for
development build evidence.

When supplied an ISO as its second argument, the same validator recomputes and
compares the artifact basename, byte size, SHA256, and BLAKE2b-512 when the
manifest records it. Release staging uses `--release` mode, so BLAKE2b-512 is
always recomputed and bound to the ISO bytes. The release identifier must also
reproduce the exact ISO name `schweisos-YYYY.MM.DD-x86_64.iso`, and profile
provenance comes from the manifest rather than caller-selected metadata.
In-progress, development, and failed v2 manifests remain useful private
attempt records but cannot satisfy the release completed-success schema.

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
`validate-build-environment.sh`; installer policy is centralized in
`validate-installer-config.sh`; profile policy is centralized in
`validate-iso-profile.sh`; completed-image identity and boot composition are
centralized in the two built-ISO validators.

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

The source tree defines the ordered validators, dependency manifest, failure
manifest, build invocation, first-boot defaults, Plymouth watchdog, and both
post-build checks. There is no current successful ISO evidence for these newly
changed payloads, validators, or the exact v2 contract. A fresh production-host
build must create that evidence later; the older local ISO and its failed or
legacy manifests do not validate the current source. The original pre-build
blocker snapshot remains historical context in
[`environment-readiness.md`](environment-readiness.md).

Every clean build still requires all of the following:

- A canonical Arch Linux x86_64 host.
- A fully synchronized and upgraded system.
- Every direct package in `build/build-dependencies.txt` and the complete
  upstream Archiso command toolchain.
- Host-installed `schweisos-keyring`, `schweisos-mirrorlist`, and
  `schweisos-pacman-config` through an approved bootstrap process.
- A real SchweisOS repository source resolving every profile package, including
  the SchweisOS foundation packages and package-owned installer configuration.
  Package signatures remain required and trusted in every mode; repository
  database signatures are also required and trusted in release mode.
- All pre- and post-build validators passing, empty or explicitly cleaned work
  state, and no
  pre-existing ISO or ISO checksum in `out/iso/`.

No placeholder endpoint, fake mirror, unsigned production shortcut, or
signature-policy exception may satisfy these conditions. A previous successful
build is never evidence that a later host or repository state may skip them.

Related decision: [ADR-013 ISO Build Workflow](../adr/ADR-013-iso-build-workflow.md).
