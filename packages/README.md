# Packages Directory

Version: 0.3
Status: Active
Date: 2026-07-27

This directory contains SchweisOS-owned package sources.

Packages must stay small, auditable, upstream-friendly, and aligned with their
documented ownership boundary. A package should not absorb unrelated behavior
just because it is convenient for ISO assembly.

Current package families:

- Distribution identity and trust:
  - `schweisos-release`
  - `schweisos-keyring`
  - `schweisos-mirrorlist`
  - `schweisos-pacman-config`
- Runtime visual identity:
  - `schweisos-branding`
- Optional installed-system boot presentation:
  - `schweisos-grub-theme`

`schweisos-grub-theme` is inert groundwork for the future installer-owned GRUB
alternative. It is not part of the current live ISO and does not install or
configure a bootloader.

Policy reference: [docs/packaging/packaging-guide.md](../docs/packaging/packaging-guide.md).
