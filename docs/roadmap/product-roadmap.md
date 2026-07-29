# SchweisOS Product Roadmap

Version: 1.3
Status: Active pre-alpha roadmap
Date: 2026-07-29

This roadmap describes intended scope, not fixed release promises.

Completed foundations are marked explicitly. An implemented engineering
component is not automatically a public-release feature.

## Alpha

- [x] Documentation and ADR baseline.
- [x] Distribution identity, production public keyring, mirrorlist, pacman
  integration, and minimal branding packages.
- [x] Role-separated package and repository signing workflow.
- [x] Signed local production repository and disposable pacman validation.
- [x] Minimal KDE Archiso profile and versioned development ISO build.
- [x] Inert packaged GRUB theme groundwork with canonical-logo ownership.
- [x] Reconcile ISO and release-artifact naming/version contracts.
- [ ] Implement ISO detached signing and verification.
- [ ] Complete repeatable VM/live-session qualification for the current image.
- [ ] Complete installer prototype proof for UEFI + systemd-boot + ext4.
- [x] Add installer architecture, Calamares configuration package source, and
  static installer validation.
- [ ] Build/sign/admit Calamares and `schweisos-calamares-config` packages.
- [ ] Build an installer ISO and complete installation smoke testing.

## Beta

- Optional Btrfs installer path.
- Flatpak support polished.
- AUR first-use warning workflow.
- Gaming meta package and validation checklist.
- ISO signing and verification operational.
- Hardware test matrix started.
- Bug report flow with explicit user consent.

## 1.0

- KDE Plasma official release.
- UEFI-first installer with systemd-boot default and activation/validation of
  the packaged GRUB alternative.
- ext4 default and Btrfs optional.
- Public signed SchweisOS repository and documented mirror operations.
- Clear documentation for updates, AUR, Flatpak, gaming, and limitations.
- No Secure Boot or full disk encryption promise unless separately completed.

## 1.x

- Documented Distrobox/Podman baseline and curated templates.
- Improved gaming validation.
- More robust release automation.
- Wider hardware testing.
- Optional security improvements if maintenance cost remains acceptable.

## 2.x

- GNOME as second official desktop.
- Possible Distrobox GUI workflow.
- Secure Boot research.
- Full disk encryption research.
- Snapshot and rollback research for Btrfs.
