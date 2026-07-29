# Packages Directory

Version: 0.4
Status: Active
Date: 2026-07-29

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
- Installer configuration:
  - `schweisos-calamares-config`

`schweisos-grub-theme` is inert groundwork for the future installer-owned GRUB
alternative. It is not part of the current live ISO and does not install or
configure a bootloader.

`schweisos-calamares-config` owns the first Calamares configuration, installer
launcher, target package manifest, pacstrap policy, and installed-system
systemd-boot integration helpers. It does not package Calamares itself and it
is not installed into the target system by the MVP package manifest.

Policy reference: [docs/packaging/packaging-guide.md](../docs/packaging/packaging-guide.md).
