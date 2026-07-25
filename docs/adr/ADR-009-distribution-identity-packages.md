# ADR-009 Distribution Identity Packages

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-001 Repository Strategy
- ADR-003 Package Sources
- ADR-007 Update Philosophy
- ADR-008 Documentation First

## Context

SchweisOS needs a small, explicit distribution identity layer before it can safely ship packages, installation media, or repository configuration.

This layer must identify the installed system as SchweisOS, establish package trust material, define where SchweisOS packages come from, and integrate the SchweisOS repository into pacman without replacing Arch package management.

Because SchweisOS is a one-developer project at bootstrap, this layer must remain minimal and auditable. It must not become a hidden policy engine, update manager, installer framework, or package fork collection.

## Decision

SchweisOS will define four initial distribution identity packages:

- `schweisos-release`
- `schweisos-keyring`
- `schweisos-mirrorlist`
- `schweisos-pacman-config`

These packages form the minimum host-level identity and trust foundation required before distribution packages, ISO builds, or installer profiles are implemented.

## Package Responsibilities

`schweisos-release` identifies the system as SchweisOS.

It owns distribution identity metadata such as release name, version metadata, project URLs, and `/etc/os-release` integration where applicable. It must not configure repositories, install defaults, modify package trust, or apply desktop behavior.

During bootstrap, `schweisos-release` may install SchweisOS identity metadata under a project-owned path such as `/usr/lib/schweisos-release/`. It must not use an install script to rewrite `/etc/os-release`, and it must not directly replace `/usr/lib/os-release` until the installer and base-system ownership model can handle Arch's `filesystem` package cleanly. This keeps the package auditable and avoids surprising changes on development hosts.

`schweisos-keyring` owns SchweisOS package signing trust material.

It installs and updates the public keys required to verify packages from official SchweisOS repositories. It must not disable pacman signature verification, weaken Arch trust settings, or trust third-party package sources.

`schweisos-mirrorlist` owns the list of official SchweisOS package mirrors.

It provides mirror endpoints for SchweisOS repositories only. It must not modify Arch mirror configuration, silently rank mirrors, or replace user-managed mirror choices without explicit action.

`schweisos-pacman-config` owns pacman integration for SchweisOS repositories.

It provides the pacman configuration snippets needed to enable official SchweisOS repositories using the SchweisOS keyring and mirrorlist. It must preserve Arch's full-system update model and must not encourage partial upgrades.

## Boundaries

These packages are infrastructure packages, not feature packages.

They must not:

- Install desktop themes or branding assets.
- Install gaming packages.
- Install Flatpak, AUR helpers, or Distrobox.
- Configure Calamares.
- Build ISO images.
- Apply performance tweaks.
- Send telemetry or enable reporting.
- Replace pacman behavior.

Feature-specific defaults belong in separate packages and require their own documented decisions when they affect architecture, security, or maintenance.

## Alternatives

Single all-in-one identity package:

This would reduce package count but mix identity, trust, mirrors, and pacman configuration into one upgrade unit. That makes auditing and recovery harder.

Installer-only repository configuration:

This avoids identity packages at first, but installed systems would lack a clean way to update trust material and repository configuration over time.

Manual user configuration:

This preserves maximum transparency but creates avoidable setup friction and makes the distribution harder to support consistently.

Early custom update manager:

This is out of scope. It would increase maintenance cost and risk violating Arch's package model before the distribution foundation is stable.

## Consequences

The identity layer becomes small, understandable, and testable. Each package has one responsibility, which makes breakage easier to diagnose and future replacement easier.

The tradeoff is slightly more package overhead. This is acceptable because the packages represent separate trust and configuration domains.

Future release engineering must ensure `schweisos-keyring` can be updated safely before package signature requirements change. Repository configuration changes must remain explicit and documented.
