# Packages Directory

Version: 0.2
Status: Active
Date: 2026-07-27

This directory contains SchweisOS-owned package sources.

Packages must stay small, auditable, upstream-friendly, and aligned with their
documented ownership boundary. A package should not absorb unrelated behavior
just because it is convenient for ISO assembly.

Current bootstrap package families:

- Distribution identity and trust:
  - `schweisos-release`
  - `schweisos-keyring`
  - `schweisos-mirrorlist`
  - `schweisos-pacman-config`
- Runtime visual identity:
  - `schweisos-branding`

Policy reference: [docs/packaging/packaging-guide.md](../docs/packaging/packaging-guide.md).
