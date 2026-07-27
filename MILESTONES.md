# SchweisOS Milestones

This document records the permanent engineering milestone history of SchweisOS.

Milestones describe completed engineering states. They should not present planned, incomplete, or experimental work as finished.

## MS-001

Title: Trust Foundation & Local Repository Bootstrap

Date: 2026-07-24

Contributors:

- Marijua

Completed work:

- Established the initial documentation baseline for SchweisOS engineering.
- Defined the project constitution and documentation-first engineering process.
- Defined the licensing model, including GPL-3.0-or-later for project source code.
- Documented the Distribution Identity Layer.
- Defined the package repository architecture in ADR-011.
- Implemented the initial `schweisos-release` package.
- Implemented the initial `schweisos-keyring` package foundation without real cryptographic keys.
- Implemented the initial `schweisos-mirrorlist` package with a single canonical endpoint model.
- Implemented the initial `schweisos-pacman-config` package for SchweisOS-owned pacman repository snippets.
- Implemented local unsigned development repository tooling around `repo-add`.
- Validated that pacman can recognize and list the first local SchweisOS development repository.

Architectural significance:

SchweisOS now has a documented trust model, a clearly bounded Distribution Identity Layer, and the first locally consumable package repository for development testing.

This milestone does not represent a public package repository, signed repository, ISO, installer, mirror network, or stable release. It establishes the minimum engineering foundation needed to move toward those systems without inventing a new package manager or weakening Arch package semantics.

Next milestone:

MS-002 — First Signed Repository & First Package Installation

## MS-002

Title: First Signed Repository & First Package Installation

Date: 2026-07-27

Contributors:

- Marijua

Completed work:

- Completed the production public-key ceremony outside the online build
  workflow and admitted the reviewed public bundle.
- Promoted `schweisos-keyring` from a placeholder package to the production
  public trust package.
- Implemented role-separated operational signing for packages and repository
  databases.
- Built and validated the first signed local production repository containing
  the five current SchweisOS packages.
- Validated repository and package signatures in a disposable pacman client
  while preserving Arch Linux trust for upstream dependencies.
- Implemented the KDE Archiso profile, build-host and profile gates, build
  manifests, checksums, and post-build identity inspection.
- Produced a development ISO and verified its SquashFS distribution identity
  and required live package set without treating it as a public release.
- Added the minimal runtime branding package and aligned the effective
  `os-release` identity with the date-based SchweisOS release version.

Architectural significance:

SchweisOS now has a real public trust root, distinct operational signing roles,
a signed repository lifecycle, and a locally consumable KDE development image.
The image consumes signed SchweisOS packages without replacing Arch's package
trust or package manager.

This milestone does not represent a public mirror, stable release, completed
installer, ISO signature, Secure Boot implementation, or completed manual
hardware qualification.

Next milestone:

MS-003 — Installer Foundation & Installation Validation
