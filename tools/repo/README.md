# SchweisOS Local Repository Tools

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.4
Status: Local bootstrap workflow
Date: 2026-07-28

These tools build and inspect a local `repo-add` repository for the five
current SchweisOS bootstrap packages.

This workflow is deliberately separate from the canonical publication flow in
[Package Repository Workflow](../../docs/release/repository-workflow.md). It
does not sign packages, sign repository databases, publish artifacts, simulate
mirrors, create network endpoints, or modify host pacman configuration.

The installed `schweisos-mirrorlist` package contains a separate local
development endpoint under `/var/lib/schweisos/local-repo/$repo/os/$arch` so
pacman can parse SchweisOS repository integration on a build host. This tools
directory uses the same `$repo/os/$arch` repository shape under
`out/local-repo/`. If a developer intentionally selects
`/var/lib/schweisos/local-repo` as the repository root, the generated database
is directly consumable by pacman and Archiso without manual copy steps.

## Supported Packages

- `schweisos-branding`
- `schweisos-release`
- `schweisos-keyring`
- `schweisos-mirrorlist`
- `schweisos-pacman-config`

## Generated Layout

```text
out/
  local-repo/
    README.md
    packages/
      schweisos-*.pkg.tar.zst
    schweisos/
      os/
        x86_64/
          schweisos.db
          schweisos.db.tar.gz
          schweisos.files
          schweisos.files.tar.gz
          schweisos-*.pkg.tar.zst
```

`packages/` owns local `makepkg` outputs. `schweisos/os/x86_64/` owns the
mutable package copies selected for the local repository and the files generated
by `repo-add`. The duplication keeps package build output separate from
repository creation.

The database name is fixed as `schweisos` because it must match the configured
pacman repository name. This keeps the generated `schweisos.db` directly
consumable by Archiso and pacman when the local development endpoint is
populated. `out/` is ignored by git.

## Tools

### bootstrap-local-repo.sh

Creates the generated layout and installs the canonical local ownership README:

```bash
tools/repo/bootstrap-local-repo.sh
```

This operation creates directories only. It does not build or publish packages.

### publish-local-packages.sh

Builds the five packages into `packages/`, copies the selected artifacts into
`schweisos/os/x86_64/`, and runs `repo-add`:

```bash
tools/repo/publish-local-packages.sh
```

The command uses `makepkg --nodeps` because SchweisOS bootstrap dependencies may
not yet be installed on the developer host. This exception is local only;
release builds require clean dependency-resolved environments.

The command never uses `makepkg --force`. If a declared output already exists,
the build stops rather than silently overwriting the local artifact. The
operator must inspect and deliberately clean or relocate generated local state
before retrying.

Only each package's primary artifact is selected for the local repository
database. If makepkg reports a matching `*-debug-*.pkg.tar.*` path, the publish
script does not require or publish it.

To rebuild the database from artifacts already present in `packages/`:

```bash
tools/repo/publish-local-packages.sh --no-build
```

The command produces no signatures and performs no network operation. Its
output must never be uploaded or relabeled as an official repository.

### validate-local-repo.sh

Validates layout ownership, the exact five-package repository membership,
database-to-artifact references, absence of signing material, and absence of
network endpoints:

```bash
tools/repo/validate-local-repo.sh
```

It does not create a pacman repository stanza and never changes signature
policy.

## Disposable Installation Test

After local publication, run:

```bash
tests/install-local-bootstrap-packages.sh
```

The test requires the `schweisos` database and fails with a diagnostic if
publication has not happened. It installs the five unsigned local package files
as one transaction into a temporary pacman root, then verifies that the installed
SchweisOS pacman snippet and mirrorlist parse through `pacman-conf`. The
disposable configuration:

- sets repository signature policy to `Required TrustedOnly`
- defines no repository section outside the installed SchweisOS-owned snippet
- permits unsigned local package files through `LocalFileSigLevel = Optional`
- uses temporary database, cache, hook, log, and GPG directories
- never reads or writes host pacman configuration or keyrings

The transaction assumes the external Arch `filesystem` and `pacman`
dependencies are present rather than installing an Arch base system into the
test root. It verifies only the five SchweisOS packages and their mutual file
and dependency compatibility.

The local-file exception is not official repository policy and does not test
the separate production signed-client path. It exists only for unsigned local
package co-installation validation.

## Configuration

All tools accept a local output override:

```bash
tools/repo/publish-local-packages.sh --repo-root /tmp/schweisos-local-repo
```

The equivalent environment variable is:

```bash
SCHWEISOS_LOCAL_REPO_ROOT=/tmp/schweisos-local-repo
```

No script accepts a production repository name, mirror URL, or publication
destination.

## Ownership Boundaries

| Component | Owns | Does not own |
| --- | --- | --- |
| Package directories | PKGBUILDs and source inputs | Repository databases |
| `packages/` | Local build artifacts | Publication state |
| `schweisos/os/x86_64/` | Local `repo-add` state and referenced copies | Signing or mirrors |
| Repository tools | Local creation and validation | Production release engineering |
| Integration test | Disposable package co-installation | Signed repository trust |

## Known Limitations

This workflow does not validate:

- clean-chroot release builds
- package signatures
- repository database signatures
- production keyring trust
- canonical publication
- mirror synchronization
- installation through a signed pacman repository

Those are release gates, not local bootstrap shortcuts.
