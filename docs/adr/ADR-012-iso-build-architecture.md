# ADR-012 ISO Build Architecture

Version: 1.1

## Status

Accepted

## Date

2026-07-28

## Related ADRs

- ADR-001 Repository Strategy
- ADR-002 UEFI First
- ADR-003 Package Sources
- ADR-008 Documentation First
- ADR-009 Distribution Identity Packages
- ADR-011 Repository Architecture
- ADR-015 GRUB Theme Architecture

## Context

SchweisOS needs an installation and live environment, but it must not acquire a second operating-system build stack that a small project cannot maintain. The ISO architecture must remain close to Arch Linux, consume the same package and trust foundations as an installed SchweisOS system, and keep live-media concerns separate from reusable distribution behavior.

Without explicit boundaries, an archiso profile can easily become a collection of unowned files, one-off scripts, copied configuration, and branding that exists only inside the image. Such a profile is difficult to audit, update, test independently, or reproduce on an installed system.

This ADR defines the architecture and ownership boundaries for future ISO work. It does not implement an archiso profile, create build files, select exact package versions, or define the release-signing procedure.

## Decision

SchweisOS will build its x86_64 live and installation media with the upstream `archiso` package and its `mkarchiso` profile model.

SchweisOS will maintain a small project-owned profile, initially for KDE Plasma, while consuming archiso as an upstream tool. The ISO profile is an assembly description and release input. It is not a replacement package repository, a package build system, or the canonical owner of installed-system configuration.

The official ISO build must consume validated Arch packages and SchweisOS packages through pacman repositories. It must not build SchweisOS packages implicitly as part of ISO assembly. Package construction and publication remain governed by ADR-011.

## Why Archiso

Archiso is the Arch Linux toolset for producing live and installation media. It already provides the profile model, package installation flow, root filesystem image construction, boot artifact generation, and output assembly required by SchweisOS.

Using archiso provides:

- Alignment with Arch package management and live-media conventions.
- A small declarative surface for package selection and image metadata.
- Upstream maintenance for boot and filesystem-image mechanics.
- Familiar tooling for Arch contributors and release engineers.
- A shorter and more auditable path to the first bootable image.

SchweisOS gains no strategic value from owning ISO assembly mechanics. Its value belongs in tested packages, understandable defaults, installation UX, documentation, and release discipline.

## Upstream Relationship

SchweisOS will not fork archiso.

The project will install a released upstream `archiso` package and keep its own profile in this repository. If an archiso defect blocks SchweisOS, the preferred order is:

1. Adapt the SchweisOS profile when that preserves the intended design.
2. Report or contribute the fix upstream.
3. Use a small, temporary, documented downstream patch only when no practical upstream-compatible path exists.

Any persistent downstream archiso patch or fork requires a separate ADR with an owner, removal condition, security analysis, and update plan.

This boundary prevents SchweisOS from inheriting long-term responsibility for upstream boot logic, image formats, initramfs integration, and release-tool compatibility.

## Architectural Separation

ISO concerns are separated into five ownership domains.

| Domain | Canonical location | Responsibility |
| --- | --- | --- |
| ISO profile | `iso/profiles/kde/` | Declares image metadata, boot modes, package composition, and the smallest necessary live-only overlay |
| Packages | `packages/<pkgname>/` | Own reusable SchweisOS software, persistent configuration, desktop defaults, installer integration, and updateable files |
| Branding | `branding/` | Own source artwork and brand guidance; release-ready assets are delivered by an appropriately licensed package where practical |
| Configuration | Primarily the owning package under `packages/` | Provides versioned, testable, removable configuration; the profile contains only build-time or genuinely live-only configuration |
| Documentation | `docs/` | Owns project and user documentation; offline live-media documentation is delivered by a package when included in an image |

The same file must have one canonical owner. The profile must not contain copies of files whose maintained source belongs in `packages/`, `branding/`, or `docs/`.

## Expected Repository Layout

Future ISO work is expected to use this layout:

```text
iso/
  README.md
  profiles/
    kde/
      profiledef.sh
      packages.x86_64
      pacman.conf
      airootfs/
      efiboot/
      # syslinux/ only if legacy BIOS support is approved later
packages/
  <pkgname>/
branding/
docs/
```

The layout is descriptive, not an instruction to create these paths in this ADR.

Only one KDE profile should exist initially. Shared-profile generators, inheritance frameworks, and a second desktop profile must not be introduced until real duplication justifies them. If a GNOME image is added later, common content should first be moved into reusable packages rather than copied between profiles.

The profile's `pacman.conf` is a build-time input used by `mkarchiso` to resolve packages. It does not own the live or installed system's `/etc/pacman.conf`. Runtime SchweisOS repository integration remains the responsibility of `schweisos-keyring`, `schweisos-mirrorlist`, and `schweisos-pacman-config`.

## Profile Component Responsibilities

### `profiledef.sh`

`profiledef.sh` defines archiso profile metadata and image-construction policy, including the image name, label, publisher, architecture, output modes, supported boot modes, filesystem image settings, and exceptional overlay file permissions.

It must remain declarative and small. It must not become a general provisioning script, build SchweisOS packages, download untracked assets, embed secrets, or configure the installed system.

### `packages.x86_64`

`packages.x86_64` is the declarative package manifest for the x86_64 live image. It lists package names supplied by approved Arch and SchweisOS repositories.

It defines image composition, not package ownership. It must not contain shell logic, local absolute paths, or hidden download behavior. A package being present on the live image does not imply that the installer must install it to the target system.

### `airootfs/`

`airootfs/` is the filesystem overlay applied to the live root filesystem. It is reserved for the smallest set of files and links that are specific to live-media operation and cannot reasonably be delivered by a package.

Acceptable uses may include archiso-required live-session links or narrowly scoped live-only markers. Every overlay file must have a documented reason, intended owner, permissions, and removal condition.

`airootfs/` must not contain:

- Copies of reusable SchweisOS configuration.
- Package payloads or manually extracted packages.
- Untracked binaries.
- Private keys, signing material, credentials, or machine-specific data.
- Files that should survive into or be maintained on the installed system.
- Branding or documentation copied from their canonical source locations.

### `efiboot/`

`efiboot/` owns profile input required by archiso's selected UEFI boot mode, such as systemd-boot loader configuration when that upstream-supported mode is used.

It configures how the live medium starts. It does not define how the target system is partitioned or which bootloader the installer writes. Changes here must follow archiso's current profile contract and should stay as close to its supported defaults as practical.

### `syslinux/`

`syslinux/` is the archiso profile area for legacy BIOS boot configuration when a Syslinux BIOS boot mode is selected.

Legacy BIOS is not a first-release requirement under ADR-002. Therefore the initial SchweisOS profile is not expected to contain `syslinux/`. Adding it later would expand the boot and test matrix and requires an explicit scope decision; this ADR documents the boundary but does not approve legacy support.

## Package-First Configuration Policy

Files should be delivered through packages whenever they provide SchweisOS behavior beyond ISO assembly.

Package ownership provides:

- Pacman file ownership and conflict detection.
- Versioned upgrades and controlled removal.
- Checksums, package signatures, and repository provenance.
- Independent build, inspection, and validation.
- Reuse across the live environment and installed systems.
- A small ISO profile whose changes remain easy to review.

Configuration should therefore be packaged instead of copied into `airootfs/` whenever it is persistent, reusable, security-relevant, user-visible, or expected to evolve after installation. An overlay is not an acceptable shortcut around creating a maintainable package.

An official ISO should receive SchweisOS-owned packages from an approved repository tier. The ISO profile must not silently prefer an unpackaged local file over a released package.

## Expected Future Package Ownership

The following classes of files are expected to become official SchweisOS packages before they are treated as stable ISO content:

| File or behavior class | Expected package ownership |
| --- | --- |
| Distribution identity, trust, mirror discovery, and repository integration | Existing `schweisos-release`, `schweisos-keyring`, `schweisos-mirrorlist`, and `schweisos-pacman-config` packages |
| KDE system defaults and project-owned desktop configuration | `schweisos-kde-settings` |
| Installer configuration, modules, and desktop launcher | `schweisos-calamares-config` or another installer package approved by the installer ADR |
| Reusable release-ready visual assets | `schweisos-branding` for minimal runtime identity assets; broader visual customization requires separate package design |
| Reusable installed-system GRUB presentation | Existing inert `schweisos-grub-theme`; deployment and activation remain installer-owned |
| Offline user and troubleshooting documentation | A future `schweisos-docs` package or another documented documentation package |
| Substantial live-session services, policies, or helpers | A narrowly scoped future live-configuration package if ordinary upstream packages cannot provide them |

Names that do not already exist are architectural expectations, not package implementations. Their final names and contents may be refined by later ADRs. Small archiso-native boot templates and genuinely ephemeral live-only links remain profile-owned.

## Boot Philosophy

SchweisOS is UEFI-first.

The live medium should use an upstream-supported archiso UEFI boot path and preserve archiso defaults where practical. Deviations must solve a documented SchweisOS requirement and carry a boot-test obligation.

The live-media boot path and the installed-system bootloader are separate concerns:

- Archiso controls how the installation medium boots.
- The installer controls how the installed system boots.
- systemd-boot remains the default for installed UEFI systems under ADR-002.
- GRUB remains an installed-system alternative when supported by the installer.
- The packaged GRUB theme is presentation groundwork and does not by itself
  implement or activate that alternative.
- Legacy BIOS is not required for the first release.
- Secure Boot remains outside the first-release scope unless a later ADR changes that decision.

Using a particular archiso boot mode must not silently redefine installed-system boot policy.

## Live ISO Goals

The first live ISO is intended to provide:

- A functional KDE Plasma live session.
- Working network discovery and connection needed for installation and support.
- A clear installer launcher without hiding that installation changes disk state.
- Access to installation, source-trust, and troubleshooting documentation, including an offline path for essential material.
- A compact set of troubleshooting tools for storage, networking, logs, hardware discovery, and boot diagnosis.

The live environment should be sufficient to evaluate hardware compatibility, start installation, access documentation, and diagnose common installation failures. It is not intended to become a separate rescue distribution or a fully customized daily-use system.

Exact package selection, session startup behavior, installer technology, user accounts, and troubleshooting tool names belong to implementation review or later focused ADRs.

## Build and Trust Boundaries

The ISO is a downstream release artifact of the package repositories described by ADR-011.

For an official build:

- Arch and SchweisOS package sources must be explicit.
- SchweisOS packages must already have passed their package lifecycle and signing requirements.
- Build-time repository configuration must not weaken the installed system's trust policy.
- The profile and all project-owned inputs must be version controlled.
- Signing secrets must never be stored in the profile or image overlay.
- Build outputs and work directories must remain generated artifacts outside the profile source.

ISO checksum, ISO signing, reproducible-build environment, repository snapshotting, and publication procedures require release-engineering design. They are not implemented or finalized by this ADR.

## Security and Maintenance Impact

A small profile reduces the privileged, image-wide configuration surface that must be reviewed. Package-first ownership lets pacman verify and account for SchweisOS files, while keeping trust and repository behavior consistent between live and installed environments.

Relying on upstream archiso transfers routine boot and image-format maintenance to the Arch project, but it also means SchweisOS must test profile compatibility when archiso changes. The profile must follow supported interfaces rather than depend on internal implementation details.

Direct overlay files receive less lifecycle management than packaged files. They are therefore treated as exceptions and must be reviewed carefully for permissions, ownership, secrets, and conflicts with package-owned paths.

## Alternatives Considered

### Fully Custom ISO Build System

A custom system could provide complete control over image construction, but SchweisOS would have to maintain boot assembly, root filesystem creation, initramfs integration, package installation, image formats, and compatibility with upstream changes. This offers little user-visible value and is not sustainable for the current project size.

### Forking Archiso

A fork would make deep changes possible, but it would create a permanent synchronization and security burden. SchweisOS requirements fit the supported profile model, so a fork is unjustified. Targeted fixes should be contributed upstream.

### Putting All Customizations in `airootfs/`

This is initially convenient, but it produces unowned files, duplicates canonical sources, bypasses package validation, and makes installed-system updates inconsistent with the live image. It would turn the profile into an implicit package format and increase audit cost with every release.

## Consequences

Positive consequences:

- SchweisOS stays aligned with upstream Arch live-media tooling.
- The project maintains a profile instead of an ISO build framework.
- Reusable behavior is independently packaged, signed, tested, installed, updated, and removed.
- Live and installed systems share the same SchweisOS package sources.
- Profile reviews focus on composition and exceptional live-only files.
- Future desktop profiles can reuse packages without copying configuration.

Negative consequences:

- More configuration work must be completed as proper packages before it can enter a stable image.
- Archiso upgrades may require profile updates and renewed boot testing.
- The project must distinguish build-time `pacman.conf` behavior from runtime pacman configuration.
- Very small live-only customizations require judgment about whether an overlay or package is the correct owner.

The additional packaging discipline is intentional. A small profile with reusable packages reduces long-term maintenance cost and keeps SchweisOS close to upstream Arch.

## Architecture Validation

This decision is validated when:

- The ADR index includes ADR-012.
- The Architecture Design Document references ADR-012 and reflects its ownership boundaries.
- Documentation changes pass `git diff --check`.

Boot testing, ISO inspection, package resolution, VM testing, and installer validation cannot occur until a profile is implemented and are explicitly outside this ADR.

## References

- [mkarchiso manual](https://man.archlinux.org/man/mkarchiso.1.en)
- [Archiso profile overview](https://wiki.archlinux.org/title/Archiso)
- [Upstream archiso project](https://gitlab.archlinux.org/archlinux/archiso)
