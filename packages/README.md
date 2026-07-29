# Packages Directory

Version: 0.5
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
launcher, once-only live autostart, exact-path privilege/display bridge,
visible startup diagnostics, target package manifest, pacstrap policy, and
installed-system systemd-boot integration helpers. The separately reviewed
Calamares binary package omits upstream's generic launcher so only the
SchweisOS entry is visible. Neither package is installed into the target
system by the MVP package manifest.

Policy reference: [docs/packaging/packaging-guide.md](../docs/packaging/packaging-guide.md).
