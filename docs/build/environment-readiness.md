# Build Environment Readiness

Version: 1.0
Status: Active blocker register
Date: 2026-07-25

## Purpose

This document classifies every failure reported while preparing the first
SchweisOS ISO build environment. It is an evidence snapshot, not a waiver.
Sprint D2 may proceed only when the full build dependency, environment, and ISO
profile validators all pass on the canonical host.

The observation was made read-only on an x86_64 EndeavourOS development host.
No package database was refreshed, no package was installed, no trust setting
was changed, and no `mkarchiso` execution occurred.

## Dependency Baseline

As of this review, Arch publishes `archiso` 88-1 in `extra`. Its official
runtime dependencies own the image-construction toolchain, including
`arch-install-scripts`, `dosfstools`, `e2fsprogs`, `erofs-utils`, `libarchive`,
`libisoburn`, `mtools`, and `squashfs-tools`. SchweisOS therefore records only
its direct build-host requirements in
[`build/build-dependencies.txt`](../../build/build-dependencies.txt):

- `archiso`
- `bash`
- `git`
- `pacman`
- `sudo`
- `util-linux`

The direct set is deliberately small. `archiso` owns its changing upstream
dependency graph; SchweisOS owns the additional commands it invokes directly.
The validator still checks all required transitive commands and their exact
package owners, so this separation does not weaken the build gate.

Reference metadata:

- [Arch Linux archiso package](https://archlinux.org/packages/extra/any/archiso/)
- [Arch Linux pacman file list](https://archlinux.org/packages/core/x86_64/pacman/files/)
- [Arch Linux util-linux file list](https://archlinux.org/packages/core/x86_64/util-linux/files/)

## Observed Failures

| Failing check | Classification | Why it fails | Code change required | Host preparation required | Infrastructure required | Expected owner |
| --- | --- | --- | --- | --- | --- | --- |
| Canonical host identity | Host issue | `/etc/os-release` identifies the development host as `endeavouros`, not `arch`. A derivative is not the canonical release host defined by ADR-013. | No | Use a canonical Arch Linux x86_64 build host. | No | Build host |
| Direct package presence | Dependency issue | `archiso` is not installed. The other five direct packages are present. | No; the manifest and validator are now canonical. | Install the manifest-defined package set through normal trusted Arch package management on the canonical host. | No | Build host |
| Required command availability | Dependency issue | `mkarchiso`, `mkfs.erofs`, `mksquashfs`, `pacstrap`, and `xorriso` are absent because `archiso` and parts of its upstream dependency chain are absent. | No | Satisfy the direct manifest through official Arch packages; verify that upstream dependencies provide the commands. | No | Build host |
| Full-upgrade state | Host issue | `pacman -Quq`, using the host's existing synchronization databases, reports 174 pending updates. The validator intentionally does not refresh databases. | No | Synchronize and fully upgrade the canonical host, then run the validator again. | No | Build host |
| Readiness document layout | Repository issue | During implementation, the environment validator correctly reported this required document as missing. This deliverable resolves the repository defect. | Completed in this sprint | No | No | Developer |
| SchweisOS repository integration | Host issue, then infrastructure issue | The build host must have `schweisos-keyring`, `schweisos-mirrorlist`, and `schweisos-pacman-config` installed so pacman can resolve the SchweisOS repository include. The bootstrap mirrorlist provides only a local development endpoint. Production trust material and a signed publication source still do not exist. | Package infrastructure now provides the required snippet and endpoint. | Install the approved integration packages on the build host. | Yes: real public keys, signed packages and database, and an approved publication source are required before repository installation can succeed. | Developer for package infrastructure; infrastructure, then build host for release use |

There is no observed standalone policy failure. The current host's pacman
configuration passes the required trusted-signature check, project paths and
permissions pass, and no credential pattern or private signing material was
found. Those passing checks remain mandatory.

## Ownership Boundaries

### Developer

- Maintains the dependency manifest and validators.
- Keeps repository layout, permissions, symlinks, and documentation valid.
- Must not make a noncanonical host appear canonical or encode host-specific
  exceptions.

### Build Host

- Provides canonical Arch Linux x86_64.
- Provides an up-to-date system and the exact manifest packages.
- Provides every expected command from its canonical Arch package owner.
- Installs approved SchweisOS integration packages before ISO validation.
- Ensures any local development endpoint used for repository integration points
  only at signed, reviewed SchweisOS artifacts.

### Infrastructure

- Establishes production SchweisOS public trust material under the approved
  signing policy.
- Publishes signed SchweisOS packages and a signed repository database through
  an approved source.
- Does not use developer workstations, unsigned local repositories, or fake
  endpoints as release infrastructure.

## Required Gates

Repository authors run the same full dependency gate used by the environment
validator:

```sh
tests/validate-build-dependencies.sh
```

There is no manifest-only or host-check bypass mode. On a non-ready host, the
manifest-related PASS lines remain useful evidence while the process correctly
returns nonzero. The legal build sequence is:

```text
validate-build-dependencies.sh
  -> validate-build-environment.sh
  -> validate-iso-profile.sh
  -> mkarchiso
```

`validate-build-environment.sh` invokes the full dependency validator itself;
the expanded sequence above makes the ownership boundary explicit. A failure
at any gate prevents `mkarchiso`.

## Sprint D2 Readiness

Repository-side dependency policy and validation are ready for transfer to a
canonical build host. Sprint D2 execution is **not ready** because the current
host is noncanonical and stale, the Archiso toolchain is incomplete, and the
production SchweisOS repository trust and publication path do not exist.

No code-only change can legitimately remove those blockers. They require build
host preparation and approved release infrastructure. Until then, producing an
ISO remains prohibited by the fail-closed workflow.
