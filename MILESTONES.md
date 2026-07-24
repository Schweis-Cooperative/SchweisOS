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
