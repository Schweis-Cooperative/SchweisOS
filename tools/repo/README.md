# SchweisOS Local Repository Tools

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.1
Status: Local development repository bootstrap
Date: 2026-07-24

This directory contains maintainer tools for creating a local SchweisOS package repository for development and testing.

The tools are intentionally small and local-only. They do not create mirrors, contact network services, sign packages, generate GPG keys, publish artifacts, or modify the host pacman configuration.

## Purpose

The first SchweisOS repository workflow must prove that the Distribution Identity Layer packages can be built, published into a pacman repository database, and recognized by pacman without requiring real public infrastructure.

Supported packages:

- `schweisos-release`
- `schweisos-keyring`
- `schweisos-mirrorlist`
- `schweisos-pacman-config`

## Expected Directory Layout

Default generated layout:

```text
out/
  local-repo/
    x86_64/
      schweisos/
        schweisos.db
        schweisos.db.tar.gz
        schweisos.files
        schweisos.files.tar.gz
        schweisos-release-*.pkg.tar.zst
        schweisos-keyring-*.pkg.tar.zst
        schweisos-mirrorlist-*.pkg.tar.zst
        schweisos-pacman-config-*.pkg.tar.zst
```

`out/` is ignored by git and is used only for local developer artifacts.

## Scripts

```text
tools/repo/
  bootstrap-local-repo.sh
  publish-local-packages.sh
  validate-local-repo.sh
  README.md
```

### bootstrap-local-repo.sh

Creates the local repository directory.

```bash
tools/repo/bootstrap-local-repo.sh
```

### publish-local-packages.sh

Builds the current identity packages with `makepkg`, copies the resulting package archives into the local repository, and updates the repository database with `repo-add`.

```bash
tools/repo/publish-local-packages.sh
```

This script uses `makepkg --nodeps` because the local bootstrap stage must be able to build packages that depend on other SchweisOS packages before those packages are installed on the developer machine.

This is acceptable only for the local development repository. Release builds must use a clean environment and real dependency resolution.

To publish already-built package artifacts without rebuilding:

```bash
tools/repo/publish-local-packages.sh --no-build
```

### validate-local-repo.sh

Creates a disposable pacman configuration, syncs the local file-based repository database, and lists the packages visible to pacman.

```bash
tools/repo/validate-local-repo.sh
```

The validation uses:

```ini
SigLevel = Never
```

This is only for unsigned local development repositories. It must not be copied into official SchweisOS repository configuration.

When the script is run as a normal user, it uses `fakeroot` for the disposable pacman sync. If `fakeroot` is not available, it falls back to inspecting the repository database archive directly.

## Configuration

All scripts accept the same repository options:

```bash
tools/repo/publish-local-packages.sh \
  --repo-name schweisos \
  --arch x86_64 \
  --repo-root out/local-repo
```

Environment variables are also supported:

```bash
SCHWEISOS_REPO_NAME=schweisos
SCHWEISOS_REPO_ARCH=x86_64
SCHWEISOS_LOCAL_REPO_ROOT=out/local-repo
```

Relative repository roots are resolved from the project root. Absolute paths are accepted for developer override, but no script hardcodes a machine-specific absolute path.

## Package Publication Workflow

1. Edit a package under `packages/<pkgname>/`.
2. Run local package validation for that package.
3. Publish the identity package set:

   ```bash
   tools/repo/publish-local-packages.sh
   ```

4. Validate pacman visibility:

   ```bash
   tools/repo/validate-local-repo.sh
   ```

## Repository Update Workflow

Re-run:

```bash
tools/repo/publish-local-packages.sh
```

The script copies the current package artifacts into the local repository and runs:

```bash
repo-add out/local-repo/x86_64/schweisos/schweisos.db.tar.gz <packages>
```

The repository database is therefore regenerated or updated from the current local package artifacts.

## Developer Testing Workflow

For a disposable test root or VM, use a local pacman repository stanza similar to:

```ini
[schweisos]
SigLevel = Never
Server = file:///absolute/path/to/out/local-repo/x86_64/schweisos
```

This test stanza is intentionally different from `schweisos-pacman-config`, which uses signed package policy for official repositories.

Do not add the local unsigned repository to a normal workstation unless you are deliberately testing package installation behavior.

## What Can Be Validated Now

- The repository directory can be created.
- Existing identity packages can be built locally.
- Package archives can be copied into the repository directory.
- `repo-add` can create `schweisos.db` and `schweisos.files`.
- pacman can sync and list packages from the local file-based repository when root or `fakeroot` execution is available.

## What Cannot Be Validated Yet

- GPG package signatures.
- Repository database signatures.
- Public mirror synchronization.
- Canonical endpoint publication.
- End-to-end installation from `repo.schweisos.org`.
- Release artifact retention.

These require future signing, repository hosting, and release engineering infrastructure.

## Self Review

Architectural risks:

- `makepkg --nodeps` is intentionally used for bootstrap convenience. It must not become release build policy.
- `SigLevel = Never` is acceptable only for local unsigned development validation. Official SchweisOS repositories must require trusted package signatures.
- The local repository is mutable and not an artifact archive. It should not be treated as release evidence.

Unnecessary complexity avoided:

- No custom package manager.
- No mirror logic.
- No signing placeholder.
- No network publishing.
- No modification of host `/etc/pacman.conf`.

Future improvements:

- Add clean chroot build support.
- Add signed package publication once `schweisos-keyring` contains real public keys.
- Add repository database signing.
- Add artifact manifest generation for release candidates.
- Add promotion tooling from local development artifacts to staging once release infrastructure exists.
