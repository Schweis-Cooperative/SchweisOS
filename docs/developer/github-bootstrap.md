# GitHub Repository Bootstrap

Version: 0.1
Status: Draft
Date: 2026-07-24

This document defines the first GitHub-facing metadata for SchweisOS.

## Description

Recommended repository description:

```text
Independent Arch-based Linux distribution focused on KDE Plasma, gaming readiness, privacy, security, and source-aware software integration.
```

## Topics

Recommended repository topics:

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

## Initial Milestone

Name:

```text
Alpha 0.1 - Documentation and ISO bootstrap
```

Description:

```text
Establish the SchweisOS engineering documentation baseline, package/repository policy, initial signed repository design, and the first minimal KDE archiso boot target.
```

Suggested milestone scope:

- Complete ADD and initial ADR baseline.
- Finalize package repository/keyring design.
- Prepare minimal archiso profile.
- Boot KDE live ISO in a UEFI VM.
- Define first installer smoke test.

## Labels

The canonical label set lives in [../../.github/labels.yml](../../.github/labels.yml).

## GitHub CLI Setup Commands

Replace `OWNER` with the GitHub owner or organization. Use `--private` instead of `--public` if the repository should not be public yet.

```bash
gh auth login -h github.com
gh repo create OWNER/SchweisOS --source=. --public --remote=origin --push --description "Independent Arch-based Linux distribution focused on KDE Plasma, gaming readiness, privacy, security, and source-aware software integration."
gh repo edit OWNER/SchweisOS --add-topic arch-linux --add-topic linux --add-topic linux-distribution --add-topic linux-desktop --add-topic kde-plasma --add-topic gaming-linux --add-topic privacy --add-topic security --add-topic open-source --add-topic pacman --add-topic archiso --add-topic calamares --add-topic flatpak --add-topic aur --add-topic distrobox --add-topic podman --add-topic uefi --add-topic systemd-boot
gh api repos/OWNER/SchweisOS/milestones -f title="Alpha 0.1 - Documentation and ISO bootstrap" -f description="Establish the SchweisOS engineering documentation baseline, package/repository policy, initial signed repository design, and the first minimal KDE archiso boot target."
```

GitHub's CLI does not natively sync labels from this YAML file without an extension or helper. Until a label sync tool is selected, create labels with `gh label create` or use a small maintainer script in a later documented step.
