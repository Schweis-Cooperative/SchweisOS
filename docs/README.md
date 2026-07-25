# SchweisOS Documentation Index

Version: 0.3
Status: Active
Date: 2026-07-25

This directory is the source of truth for SchweisOS engineering decisions. Important decisions must not remain only in chat history; they must be written into the relevant document and, when architectural, recorded as an ADR.

## Required Reading Order

1. [Project Vision](../VISION.md)
2. [Architecture Design Document](architecture/ADD.md)
3. [Architecture Decision Records](adr/README.md)
4. [Security Model](security/security-model.md)
5. [Packaging Guide](packaging/packaging-guide.md)
6. [Package Repository Workflow](release/repository-workflow.md)
7. [Release Signing Workflow](release/release-signing-workflow.md)
8. [Release Engineering Guide](release/release-engineering-guide.md)
9. [ISO Build Workflow](build/README.md)
10. [Build Environment Readiness](build/environment-readiness.md)
11. [Testing Strategy](testing/testing-strategy.md)
12. [Developer Handbook](developer/developer-handbook.md)
13. [Product Roadmap](roadmap/product-roadmap.md)
14. [GitHub Repository Bootstrap](developer/github-bootstrap.md)

## Documentation Rules

- Every document must carry a version, status, and date.
- Every major technical decision must have an ADR.
- ADD updates must link to the ADRs that justify them.
- Roadmap updates must describe scope, not promises.
- Security-impacting changes must update the Security Model.
- Packaging-impacting changes must update the Packaging Guide.
- Release-impacting changes must update the Release Engineering Guide.

## Monorepo Layout

- `docs/`: living engineering documentation
- `build/`: machine-readable build policy inputs
- `iso/`: future archiso profile and live media configuration
- `packages/`: future SchweisOS PKGBUILD sources
- `tools/`: future maintainer-facing tools
- `scripts/`: future small automation scripts
- `branding/`: future visual identity assets
- `website/`: future project website source
- `.github/`: future CI and GitHub metadata
- `tests/`: future smoke, packaging, ISO, and regression tests

The implementation directories are intentionally empty except for README placeholders until their corresponding design documents are approved.
