# SchweisOS

Version: 0.1
Status: Bootstrap documentation
Date: 2026-07-24

SchweisOS is an independent Arch-based Linux distribution by Schweis Project.

Its goal is to keep the strengths of Arch Linux while reducing daily-use friction for desktop users. SchweisOS focuses on KDE Plasma first, gaming readiness, privacy, security, transparent software sources, and long-term maintainability.

SchweisOS is not a new kernel, a new package manager, or an Arch rewrite. It is a small and documented distribution layer that stays close to upstream Arch wherever possible.

## Current Status

This repository is in the project bootstrap phase.

It currently contains engineering documentation only. It intentionally does not yet contain an archiso profile, Calamares configuration, package sources, build scripts, or release automation.

## Core Principles

- Stay as close to upstream Arch as practical.
- Avoid unnecessary forks of Arch packages.
- Prefer documented defaults over hidden automation.
- Keep the terminal available while improving GUI guidance.
- Do not ship telemetry by default.
- Treat AUR, Flatpak, and Distrobox as distinct software sources with distinct trust models.
- Make every important technical decision visible in documentation.

## Documentation

- [Architecture Design Document](docs/architecture/ADD.md)
- [Architecture Decision Records](docs/adr/README.md)
- [Product Vision](docs/vision/product-vision.md)
- [Product Roadmap](docs/roadmap/product-roadmap.md)
- [Developer Handbook](docs/developer/developer-handbook.md)
- [Packaging Guide](docs/packaging/packaging-guide.md)
- [Security Model](docs/security/security-model.md)
- [Release Engineering Guide](docs/release/release-engineering-guide.md)
- [Testing Strategy](docs/testing/testing-strategy.md)

## Repository Layout

SchweisOS starts as a monorepo so a single maintainer can keep architecture, packaging policy, ISO work, tests, and documentation aligned. The layout is designed so larger areas can be split into separate repositories later without renaming core concepts.

See [docs/README.md](docs/README.md) and [ADR-001 Repository Strategy](docs/adr/ADR-001-repository-strategy.md).

## Development Rule

Documentation comes before implementation. Before adding an ISO profile, package, installer configuration, release automation, or user-facing behavior, update the relevant document and add an ADR when the decision is architectural.

## License

License selection is not finalized yet. No source release should be published as stable until the project license is explicitly chosen and documented.
