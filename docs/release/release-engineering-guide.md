# SchweisOS Release Engineering Guide

Version: 0.1
Status: Draft
Date: 2026-07-24

## Goal

Release engineering must make SchweisOS builds repeatable, signed, and understandable. The first objective is a small, reliable alpha ISO, not a complex release factory.

## Release Artifacts

Future releases should publish:

- ISO image.
- Checksum file.
- Detached signature.
- Release notes.
- Known issues.
- Package repository snapshot or manifest.

## ISO Build Direction

SchweisOS will use archiso for live media. The project should start from a minimal profile and add only required packages and configuration.

Reference: [Archiso - ArchWiki](https://wiki.archlinux.org/title/Archiso).

## Versioning

Use human-readable release tracks:

- `alpha`
- `beta`
- `1.0`
- `1.x`
- `2.x`

Development builds may use date-based identifiers, but public releases must have release notes and verification material.

## Release Gates

Before any public ISO:

- VM boot test passes.
- Installer smoke test passes.
- Package signatures work.
- Documentation matches behavior.
- Known limitations are listed.
- No telemetry or report submission occurs without consent.

## Rollback

Rollback means the ability to recover release infrastructure, not automatic user system rollback. User-facing rollback requires a separate Btrfs/snapshot design.
