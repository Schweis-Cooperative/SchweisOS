# ADR-013 ISO Build Workflow

Version: 1.2

## Status

Accepted

## Date

2026-07-25

## Related ADRs

- ADR-008 Documentation First
- ADR-011 Repository Architecture
- ADR-012 ISO Build Architecture

## Context

ADR-012 defines the SchweisOS ISO profile architecture and ownership boundaries. The project also needs a canonical build workflow so ISO production can be repeated safely without turning the profile into an implicit build system.

The ISO build process runs privileged tooling, resolves packages from configured repositories, creates large generated artifacts, and may eventually produce public release media. Without a documented workflow, it is easy to mix source files, package artifacts, work directories, logs, cache state, signing material, and release outputs in ways that are difficult to audit or reproduce.

This ADR defines the ISO build environment and workflow policy. It does not implement build scripts, run `mkarchiso`, create release infrastructure, sign artifacts, or publish images.

## Decision

SchweisOS ISO builds will use upstream `mkarchiso` from the Arch `archiso` package on an Arch Linux build host.

The canonical build workflow is:

```text
version-controlled repository
  -> validated ISO profile
  -> prepared build directories
  -> mkarchiso using explicit work, output, and cache paths
  -> generated ISO artifacts
  -> static inspection and later boot testing
  -> release signing and publication outside the build script
```

The build workflow must remain an orchestration layer around upstream archiso. It must not become a package builder, package repository publisher, mirror synchronization tool, key management system, installer generator, or branding pipeline.

## Build Host

The canonical build host is an up-to-date Arch Linux x86_64 system.

The build host must:

- Use official Arch packages for the ISO build toolchain.
- Have enough disk space for the work directory, package cache, and output images.
- Build from a clean git working tree for official release artifacts.
- Use explicit local directories for generated state.
- Avoid machine-specific absolute paths in version-controlled configuration.
- Keep signing secrets outside the ISO profile and outside generic build logs.

Containerized or virtualized build hosts may be used later, but they must preserve the same package trust, privilege, filesystem, and logging rules. A future CI design may automate the workflow, but CI does not change the architectural boundaries in this ADR.

## Required Arch Packages

The machine-readable source of truth for direct build-host dependencies is
`build/build-dependencies.txt`. Its canonical package set is:

- `archiso`
- `bash`
- `git`
- `pacman`
- `sudo`
- `util-linux`

This list records packages SchweisOS consumes directly: upstream Archiso,
shell execution, source-state capture, pacman configuration and trust queries,
narrow privilege escalation, and build locking or mount inspection. Dependencies
such as `arch-install-scripts`, `dosfstools`, `e2fsprogs`, `erofs-utils`,
`libarchive`, `libisoburn`, `mtools`, and `squashfs-tools` are intentionally not
duplicated in the manifest. They are runtime dependencies of Arch's `archiso`
package and therefore remain owned by upstream package metadata.

`tests/validate-build-dependencies.sh` verifies both layers without changing
the host: the exact direct package set and the presence and Arch package
ownership of every required command, including transitive Archiso tools. This
detects missing dependencies or unexpected replacements while avoiding a
second, drifting copy of upstream dependency metadata.

`util-linux` provides `flock` for single-writer build state and `findmnt` for
mount-aware work-directory cleanup.

Recommended validation and release-adjacent tools:

- `shellcheck` for future shell script validation.
- `namcap` for package review where available.
- `diffoscope` for future reproducibility investigations.
- `qemu-desktop` and `edk2-ovmf` for later UEFI boot testing.
- `gnupg` for future signature verification and release signing workflows.

These recommended tools do not imply that signing keys live on the ISO build host. If a dedicated signing host is introduced, signing remains a separate release-engineering step.

## Build Directory Layout

Generated build state belongs outside the ISO profile.

The canonical local layout is:

```text
work/
  iso/
    kde/
out/
  iso/
cache/
  pacman/
logs/
  iso/
```

The future build script may allow these paths to be overridden, but defaults must be relative to the repository root and must not use hardcoded user-specific absolute paths.

Directory responsibilities:

| Directory | Responsibility | Version controlled |
| --- | --- | --- |
| `iso/profiles/kde/` | Source ISO profile | Yes |
| `work/iso/kde/` | Temporary archiso work state | No |
| `out/iso/` | Generated ISO artifacts and checksums | No |
| `cache/pacman/` | Build-local package cache | No |
| `logs/iso/` | Build logs and validation notes | No |

Official release artifacts may later be copied from `out/iso/` to designated artifact storage after validation. The output directory itself is not artifact storage.

## Ownership Boundaries

The ISO profile owns image composition. Build tooling owns repeatable execution.

The ISO profile may define:

- `profiledef.sh`
- `packages.x86_64`
- build-time `pacman.conf`
- supported archiso boot templates
- minimal live-only `airootfs/` exceptions

Build tooling may define:

- build directory creation
- host dependency checks
- git cleanliness checks for release mode
- profile static validation
- `mkarchiso` invocation
- log capture
- output naming checks
- post-build artifact inspection
- single-writer locking for generated build state
- per-attempt manifests and a latest-attempt manifest view

Build tooling must not own:

- SchweisOS package contents
- package signing keys
- repository publication
- mirror synchronization
- installer policy
- KDE defaults
- branding source assets
- undocumented live-session behavior

If a build script appears to need persistent system configuration, that configuration probably belongs in a package or a separate ADR.

## Reproducible Build Expectations

SchweisOS should treat reproducibility as a release-engineering goal, not as a claim before it is measured.

ISO builds should:

- Run from a known git commit.
- Record the archiso package version.
- Record the build host architecture.
- Record the package repository configuration used by the profile.
- Record the package database state or repository snapshot source when release infrastructure supports it.
- Use `SOURCE_DATE_EPOCH` when a release process defines a canonical timestamp.
- Keep work, output, cache, and logs separated.

Before official releases, SchweisOS should compare at least two builds from equivalent inputs. If bit-for-bit reproducibility is not yet achieved, the release notes must avoid claiming reproducible ISOs and should document the known limits.

## Cleaning Policy

Generated build directories are disposable.

The default cleaning policy is:

- `work/iso/<profile>/` may be removed before a clean build.
- `out/iso/` may be cleaned only when preserving required release artifacts elsewhere.
- `cache/pacman/` should be reusable across local builds but must not be treated as a source of truth.
- `logs/iso/` should be preserved for release builds until the release is completed or rejected.

Build work state must not be resumed unless it is cryptographically or
otherwise deterministically bound to the current source and repository inputs.
Until such a binding exists, non-empty work state requires explicit cleanup.
Cleanup must hold the build lock, reject mounted paths beneath the target, and
remain on the work directory's filesystem.

Build tooling must require an explicit clean mode before deleting generated directories. It must never remove broad paths such as the repository root, a user's home directory, `/`, or unresolved environment-variable paths.

## Logging Policy

Build logs are release evidence.

The workflow should capture:

- build start and end time
- git commit
- archiso version
- selected profile path
- work, output, cache, and log paths
- `mkarchiso` command line
- static validation results
- generated artifact names and checksums when available

Logs must not contain signing secrets, private keys, tokens, mirror credentials, or unrelated host environment dumps. Debug logging should be opt-in and reviewed before use in public release evidence.

## Root Privilege Requirements

`mkarchiso` requires privileged operations to create and populate the live filesystem image.

The future build workflow should:

- Run host validation without root where possible.
- Escalate only for the `mkarchiso` execution step and any directly required cleanup of root-owned build state.
- Prefer `sudo` for interactive local builds.
- Fail clearly when required privileges are missing.
- Avoid running unrelated validation, git operations, network publication, or signing steps as root.

Root privilege is a build mechanism, not a reason to broaden script responsibility.

## Future `scripts/build-iso.sh`

A future `scripts/build-iso.sh` should be a small wrapper around the documented workflow.

It should:

- Determine the repository root.
- Select an explicit profile, initially `iso/profiles/kde`.
- Verify required host commands and packages where practical.
- Verify the profile files expected by ADR-012.
- Create `work/`, `out/`, `cache/`, and `logs/` subdirectories.
- Support a clean mode for generated build state.
- Record git commit and tool versions.
- Invoke `mkarchiso` with explicit work and output directories.
- Capture logs in `logs/iso/`.
- Print the generated artifact paths.
- Exit non-zero on validation or build failure.
- Prevent concurrent wrappers from sharing work, output, cache, or manifest
  state.
- Validate generated artifact identity and checksums and atomically record a
  privacy-minimized build manifest.

It must not:

- Build SchweisOS packages.
- Run `makepkg` for package sources.
- Modify PKGBUILDs.
- Generate signing keys.
- Sign packages, repositories, or ISOs.
- Publish artifacts to `repo.schweisos.org`.
- Synchronize mirrors.
- Edit the ISO profile while building.
- Download untracked branding or installer assets.
- Modify the user's global `pacman.conf`.
- Hide `mkarchiso` errors behind generic success messages.

## Security Considerations

The ISO build host is privileged and release-sensitive. It should be treated as infrastructure, not as an ordinary development shell once public releases begin.

Key rules:

- Signing secrets must not be stored in the repository, ISO profile, `airootfs/`, package cache, or generic build logs.
- Official builds must consume packages through the trust model defined by ADR-011.
- Local unsigned development repositories must not be used for public release ISOs.
- Build outputs must be inspected before signing or publication.
- Package cache contents must not override repository trust decisions.
- Release signing and publication require their own controlled workflow.

## Alternatives Considered

### Manual `mkarchiso` Invocation Only

Manual invocation is acceptable during early experimentation, but it is too easy to vary paths, forget validation, lose logs, or build from a dirty tree. A documented wrapper is justified once builds become recurring.

### Custom ISO Build Framework

A custom framework would duplicate archiso responsibilities and increase maintenance cost. SchweisOS needs predictable orchestration, not ownership of image construction mechanics.

### Build Script That Also Builds Packages

Combining package builds and ISO builds looks convenient, but it collapses the package repository lifecycle into ISO assembly. That would weaken ADR-011, make signing boundaries unclear, and make it harder to reproduce which package artifacts were installed into a release image.

### Build Script That Publishes Releases

Publishing from the build script would mix local privileged build state with public release operations. Publication, signing, tagging, and mirror synchronization need separate release-engineering controls.

## Consequences

Positive consequences:

- ISO builds become repeatable without forking archiso.
- Generated state is separated from source files.
- Build logs become useful release evidence.
- Package and ISO lifecycles remain separate.
- The future build script can stay small and auditable.
- The architecture scales from one maintainer to CI without changing ownership boundaries.

Negative consequences:

- Early builds require a properly prepared Arch host.
- The workflow is stricter than ad hoc `mkarchiso` experimentation.
- Full reproducibility cannot be claimed until repository snapshotting and repeated build comparisons exist.
- Separate signing and publication workflows must still be designed.

## Validation

For this architecture change:

- `docs/adr/README.md` must include ADR-013.
- `docs/architecture/ADD.md` must reference the ISO build workflow.
- `docs/build/README.md` must describe build host requirements and the workflow.
- `git diff --check` must pass.
