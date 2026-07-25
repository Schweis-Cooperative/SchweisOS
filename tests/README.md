# Tests Directory

Version: 0.4
Status: Active
Date: 2026-07-25

This directory owns repository-level validation that crosses package boundaries.

`validate-build-dependencies.sh` is the read-only dependency-policy and host
toolchain validator:

```bash
tests/validate-build-dependencies.sh
```

It verifies the sorted, unique, package-name-only manifest; the approved direct
package set; availability in existing official Arch synchronization databases;
exact installed packages; required commands; and command package ownership. It
does not refresh databases, install packages, resolve providers as substitutes,
or modify the host. It has no mode that skips host checks.

`validate-build-environment.sh` is the network-free, non-destructive ISO build
host gate:

```bash
tests/validate-build-environment.sh
```

It invokes the dependency validator in full mode, then aggregates a concise
PASS/FAIL report for canonical Arch x86_64 identity, known upgrade state,
ADR-013 dependencies and command provenance, pacman
trust policy, at least 20 GiB free space, generated path safety, repository
layout and permissions, symlinks, secrets, private signing material, and
SchweisOS repository readiness. It neither mutates host package state nor runs
the profile validator or `mkarchiso`. `scripts/build-iso.sh` runs this gate
before every other substantive build step.

`validate-iso-profile.sh` performs profile-only static validation of the KDE
Archiso profile without requiring Archiso itself or network access:

```bash
tests/validate-iso-profile.sh
```

It validates the profile contract, package manifest, build-time pacman syntax,
UEFI templates, mkinitcpio inputs, live-overlay allowlist, permissions,
symlinks, and absence of signing material. Pacman parsing uses a disposable
sysroot populated from the real bootstrap configuration files; it does not
modify `/etc`, contact repositories, or invent endpoints. Repository
availability remains a separate build-host preflight.

`validate-repository-bootstrap.sh` checks the Sprint A ownership and trust
contract between `schweisos-mirrorlist` and `schweisos-pacman-config`. It builds
both packages in a disposable directory and does not contact the network,
publish a repository, alter host pacman configuration, or install packages.
It passes `--nodeps` to `makepkg` because the bootstrap SchweisOS dependencies
need not be installed on the development host; source checksums, package
creation, metadata, and payload ownership are still validated.

Run it from any directory inside the repository:

```bash
tests/validate-repository-bootstrap.sh
```

`install-local-bootstrap-packages.sh` validates that the four locally published
identity packages can coexist in one isolated pacman database and filesystem
root. It requires a previously created local `schweisos` repository:

```bash
tools/repo/publish-local-packages.sh
tests/install-local-bootstrap-packages.sh
```

The test installs the SchweisOS-owned repository snippet and local development
endpoint into the disposable root, then verifies that pacman can parse them. It
still installs package artifacts through direct package files from the local
database directory and confines pacman root, database, cache, hooks, log, and
GPG paths to a temporary directory. Unsigned developer artifacts are accepted
only through the disposable config's `LocalFileSigLevel`; official repository
policy remains `Required TrustedOnly`.

The test uses pacman's `--assume-installed` facility for the external Arch
`filesystem` and `pacman` dependencies. It is a SchweisOS package-set test, not
an Arch base-system installation test.

Strategy reference: [docs/testing/testing-strategy.md](../docs/testing/testing-strategy.md).

`validate-release-artifacts.sh` validates one prepared release artifact
directory without building, signing, publishing, or touching host configuration:

```bash
tests/validate-release-artifacts.sh release/YYYY.MM
```

It checks the canonical release layout, exactly one ISO, mandatory SHA256
verification, optional BLAKE2b-512 verification, manifest consistency, release
notes, unexpected files, permissions, symlink attacks, path traversal, and
private-information patterns.

`test-release-artifacts.sh` runs disposable release artifact scenarios using
temporary fixture files:

```bash
tests/test-release-artifacts.sh
```

It covers successful validation, missing checksums, invalid checksums, empty
ISO fixtures, duplicate ISOs, corrupt manifests, unexpected files, symlink
attacks, path traversal, permission violations, JSON validation, and atomic
duplicate-output rejection. It never invokes `mkarchiso`.
