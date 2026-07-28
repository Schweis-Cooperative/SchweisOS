# SchweisOS

Version: 0.4
Status: Pre-alpha engineering
Date: 2026-07-28

SchweisOS is an independent Arch-based Linux distribution by Schweis Project.

Its goal is to keep the strengths of Arch Linux while reducing daily-use friction for desktop users. SchweisOS focuses on KDE Plasma first, gaming readiness, privacy, security, transparent software sources, and long-term maintainability.

SchweisOS is not a new kernel, a new package manager, or an Arch rewrite. It is a small and documented distribution layer that stays close to upstream Arch wherever possible.

## Current Status

SchweisOS has moved beyond a documentation-only bootstrap. The repository now
contains:

- Five live/repository foundation packages plus an inert, separately packaged
  SchweisOS GRUB theme for future installer integration.
- A KDE Archiso profile and a fail-closed ISO build wrapper.
- A restrained two-entry systemd-boot menu, animated Plymouth live splash,
  automatic diagnostic fallback, and a noninteractive handoff directly to the
  Plasma live session.
- A packaged graphical GRUB theme that is not yet installer-activated or part
  of the live ISO.
- Production public trust material, role-separated signing tooling, and signed
  repository tooling.
- Disposable pacman, package, repository, ISO-profile, release-artifact, and
  built-image validators.
- Pre- and post-build gates that generate per-build SquashFS, initramfs,
  identity, and checksum evidence. An old or copied ISO outside that pipeline
  is not release evidence.

This is still a pre-alpha engineering state. There is no installer, public
mirror network, public release channel, Secure Boot support, disk encryption,
or stable release. A generated ISO is not a public release until the documented
release gates, manual boot testing, verification material, and publication
process have all completed.

## Core Principles

- Stay as close to upstream Arch as practical.
- Avoid unnecessary forks of Arch packages.
- Prefer documented defaults over hidden automation.
- Keep the terminal available while improving GUI guidance.
- Do not ship telemetry by default.
- Treat AUR, Flatpak, and Distrobox as distinct software sources with distinct trust models.
- Make every important technical decision visible in documentation.

## Documentation

- [Project Vision](VISION.md)
- [Architecture Design Document](docs/architecture/ADD.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Product Roadmap](docs/roadmap/product-roadmap.md)
- [Developer Handbook](docs/developer/developer-handbook.md)
- [New Conversation Master Prompt](docs/developer/MASTER_PROMPT.md)
- [Packaging Guide](docs/packaging/packaging-guide.md)
- [Security Model](docs/security/security-model.md)
- [Release Engineering Guide](docs/release/release-engineering-guide.md)
- [Testing Strategy](docs/testing/testing-strategy.md)
- [Boot Experience](docs/boot/README.md)

## Repository Layout

SchweisOS uses a monorepo so a single maintainer can keep architecture,
packaging, ISO work, validation, release engineering, branding, and
documentation aligned. Canonical source areas are:

```text
branding/   source brand assets and policy
build/      machine-readable build-host requirements
docs/       architecture, policy, operations, and developer documentation
iso/        upstream-compatible Archiso profiles
packages/   SchweisOS-owned package sources
scripts/    build and release-artifact entry points
tests/      fail-closed repository-local validators
tools/      repository, release, and signing workflows
website/    reserved website boundary
```

Generated `cache/`, `logs/`, `out/`, `work/`, package build directories, and
operational private-key exports are not repository source.

See [docs/README.md](docs/README.md) and [ADR-001 Repository Strategy](docs/adr/ADR-001-repository-strategy.md).

## Development Rule

Documentation comes before implementation. Before adding an ISO profile, package, installer configuration, release automation, or user-facing behavior, update the relevant document and add an ADR when the decision is architectural.

## License

SchweisOS uses a separated licensing model:

- Project-owned source code and code-like files: `GPL-3.0-or-later`
- Project-owned documentation: `CC-BY-SA-4.0`
- Branding and official marks: explicit per-file terms and future trademark policy

See [LICENSE](LICENSE), [COPYING](COPYING), and [ADR-010 Licensing Policy](docs/adr/ADR-010-licensing-policy.md).
