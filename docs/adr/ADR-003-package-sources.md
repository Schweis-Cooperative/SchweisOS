# ADR-003 Package Sources

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-001 Repository Strategy
- ADR-006 Distrobox Strategy
- ADR-007 Update Philosophy

## Context

Desktop Linux users often install software from several sources. Treating all sources as equivalent hides real trust and maintenance differences.

## Decision

SchweisOS will use a source-aware software model:

- Arch official repositories for system packages.
- SchweisOS repository for small distribution-specific packages.
- Flatpak for sandboxed desktop applications where appropriate.
- AUR as an explicitly unofficial community source.
- Distrobox as a future compatibility layer for foreign distribution packages.

## Alternatives

- Only official Arch repositories.
- Convert `.deb` or `.rpm` packages into Arch packages.
- Treat AUR as a normal repository in the UI.
- Prefer Flatpak for all GUI applications.

## Consequences

Users get more software while seeing where trust boundaries are. The maintenance burden is higher than an Arch-only system, so SchweisOS must keep UI and documentation honest and simple.
