# SchweisOS Release Preparation Report

Version: 0.1
Status: Draft
Date: 2026-07-24

Working Mode: Release Engineer

## Goal

Prepare `Schweis-Cooperative/SchweisOS` for its first public engineering milestone using the licensing policy established in [ADR-010 Licensing Policy](../adr/ADR-010-licensing-policy.md).

## Files Created

- `LICENSE`: repository license summary and license-domain map.
- `COPYING`: GPL-3.0-or-later license text from the local SPDX license database.
- `CONTRIBUTING.md`: contribution workflow, Working Modes, and inbound-equals-outbound policy.
- `CODE_OF_CONDUCT.md`: initial community standards.
- `SECURITY.md`: security reporting and supported-version policy.
- `SUPPORT.md`: support boundaries for bootstrap phase.
- `CODEOWNERS`: initial ownership policy for GitHub review routing.
- `docs/project/README.md`: purpose of project governance documents.
- `docs/release/RELEASE_PREPARATION_REPORT.md`: this report.

## Files Modified

- `.github/README.md`: changed from reserved placeholder to active metadata explanation.
- `.github/PULL_REQUEST_TEMPLATE.md`: added licensing review checklist.
- `.github/ISSUE_TEMPLATE/config.yml`: added documentation contact link.
- `.github/labels.yml`: added governance, security, support, and needs-decision labels.
- `.gitignore`: removed package-specific temporary source-copy entries; kept general build/package ignores.
- `docs/developer/github-bootstrap.md`: updated repository owner to `Schweis-Cooperative/SchweisOS`, added homepage recommendation, and removed generic owner placeholder.
- `docs/adr/README.md`: includes ADR-010 in the index.

## Repository Structure Review

Every intended top-level project directory has a README:

- `.github/README.md`
- `branding/README.md`
- `docs/README.md`
- `iso/README.md`
- `packages/README.md`
- `scripts/README.md`
- `tests/README.md`
- `tools/README.md`
- `website/README.md`

The internal local directories `.git/`, `.agents/`, and `.codex/` are not project documentation directories.

## GitHub Template Review

Current templates:

- `.github/ISSUE_TEMPLATE/bug_report.yml`
- `.github/ISSUE_TEMPLATE/feature_request.yml`
- `.github/ISSUE_TEMPLATE/architecture_decision.yml`
- `.github/ISSUE_TEMPLATE/config.yml`
- `.github/PULL_REQUEST_TEMPLATE.md`

The PR template now requires licensing impact review in addition to documentation, ADR, security, packaging, release, and validation checks.

Security vulnerabilities should not be reported through public issue templates. `SECURITY.md` directs reporters toward private vulnerability reporting when available.

## Gitignore Review

The `.gitignore` keeps general build, package, ISO, VM image, log, editor, and OS metadata artifacts ignored.

Package-specific generated source-copy ignores were removed. Future packages should avoid producing untracked source copies in the package root; build artifacts should stay covered by general patterns such as `pkg/`, `src/`, and `*.pkg.tar.*`.

## GitHub Metadata Recommendation

Repository:

```text
Schweis-Cooperative/SchweisOS
```

Description:

```text
Independent Arch-based Linux distribution focused on KDE Plasma, gaming readiness, privacy, security, and source-aware software integration.
```

Homepage:

```text
https://github.com/Schweis-Cooperative/SchweisOS/tree/main/docs
```

Topics:

```text
arch-linux
linux
linux-distribution
linux-desktop
kde-plasma
gaming-linux
privacy
security
open-source
pacman
archiso
calamares
flatpak
aur
distrobox
podman
uefi
systemd-boot
```

Default labels are defined in `.github/labels.yml`.

Initial milestone:

```text
Alpha 0.1 - Documentation and ISO bootstrap
```

Milestone description:

```text
Establish the SchweisOS engineering documentation baseline, package/repository policy, initial signed repository design, and the first minimal KDE archiso boot target.
```

## Manual Actions Required on GitHub

- Ensure the `Schweis-Cooperative/SchweisOS` repository exists and points to this local repository as `origin`.
- Set the repository description.
- Set the repository homepage.
- Add recommended repository topics.
- Create the initial milestone.
- Create or sync default labels from `.github/labels.yml`.
- Create the `Schweis-Cooperative/maintainers` team or update `CODEOWNERS` to use the correct existing maintainer team.
- Enable private vulnerability reporting if available for the repository.
- Review repository visibility before making the project public.

## Manual Terminal Commands

Check authentication:

```bash
gh auth status -h github.com
```

If needed:

```bash
gh auth login -h github.com
```

Set or verify remote:

```bash
git remote -v
git remote set-url origin git@github.com:Schweis-Cooperative/SchweisOS.git
```

Push local commits:

```bash
git push -u origin main
```

Apply GitHub repository metadata:

```bash
gh repo edit Schweis-Cooperative/SchweisOS \
  --description "Independent Arch-based Linux distribution focused on KDE Plasma, gaming readiness, privacy, security, and source-aware software integration." \
  --homepage "https://github.com/Schweis-Cooperative/SchweisOS/tree/main/docs" \
  --add-topic arch-linux \
  --add-topic linux \
  --add-topic linux-distribution \
  --add-topic linux-desktop \
  --add-topic kde-plasma \
  --add-topic gaming-linux \
  --add-topic privacy \
  --add-topic security \
  --add-topic open-source \
  --add-topic pacman \
  --add-topic archiso \
  --add-topic calamares \
  --add-topic flatpak \
  --add-topic aur \
  --add-topic distrobox \
  --add-topic podman \
  --add-topic uefi \
  --add-topic systemd-boot
```

Create milestone:

```bash
gh api repos/Schweis-Cooperative/SchweisOS/milestones \
  -f title="Alpha 0.1 - Documentation and ISO bootstrap" \
  -f description="Establish the SchweisOS engineering documentation baseline, package/repository policy, initial signed repository design, and the first minimal KDE archiso boot target."
```

Label sync should be handled by a future documented maintainer tool or a manually reviewed `gh label create/edit` sequence based on `.github/labels.yml`.

## Recommended Commit Messages

Recommended split:

```text
docs: add SchweisOS constitution and licensing policy
pkg: add schweisos-release package skeleton
community: add public repository governance files
release: document first public milestone preparation
```

If squashing this release-preparation work into one commit:

```text
release: prepare repository for first public engineering milestone
```

## Notes

This report does not implement keyring, mirrors, repository signing, ISO, archiso, Calamares, or package repository publishing.

One package-scope follow-up remains outside this task: the existing
`schweisos-release` package placeholder license file and PKGBUILD license
metadata still need to be aligned with ADR-010 in a later Engineer task.
