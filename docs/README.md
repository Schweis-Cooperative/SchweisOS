# SchweisOS Documentation Index

Version: 0.7
Status: Active
Date: 2026-07-29

This directory is the source of truth for SchweisOS engineering and design
decisions. Important decisions must not remain only in chat history; they must
be written into the relevant document and, when architectural, recorded as an
ADR.

## Required Reading Order

1. [Project Vision](../VISION.md)
2. [Architecture Design Document](architecture/ADD.md)
3. [Architecture Decision Records](adr/README.md)
4. [Design Decision Records](ddr/README.md)
5. [Security Model](security/security-model.md)
6. [Packaging Guide](packaging/packaging-guide.md)
7. [Package Repository Workflow](release/repository-workflow.md)
8. [Release Signing Workflow](release/release-signing-workflow.md)
9. [Release Artifact Pipeline](release/release-artifact-pipeline.md)
10. [Release Engineering Guide](release/release-engineering-guide.md)
11. [ISO Build Workflow](build/README.md)
12. [Testing Strategy](testing/testing-strategy.md)
13. [Boot Experience](boot/README.md)
14. [Installer](installer/README.md)
15. [Developer Handbook](developer/developer-handbook.md)
16. [New Conversation Master Prompt](developer/MASTER_PROMPT.md)
17. [Product Roadmap](roadmap/product-roadmap.md)

Historical operational snapshots remain useful evidence but are not active
requirements:

- [Build Environment Readiness](build/environment-readiness.md)
- [GitHub Repository Bootstrap](developer/github-bootstrap.md)
- [Release Preparation Report](release/RELEASE_PREPARATION_REPORT.md)

## Documentation Rules

- Canonical living policy, architecture, roadmap, and operational documents
  must carry a version, status, and date. Package-local READMEs, indexes,
  templates, license texts, and immutable historical records may use their
  native format.
- Every major technical decision must have an ADR.
- Every durable user-facing design decision must have a DDR. DDRs complement
  ADRs; they do not replace ADRs for architecture, security, packaging, or
  release-engineering decisions.
- ADD updates must link to the ADRs that justify them.
- Roadmap updates must describe scope, not promises.
- Security-impacting changes must update the Security Model.
- Packaging-impacting changes must update the Packaging Guide.
- Release-impacting changes must update the Release Engineering Guide.

## Monorepo Layout

- `docs/`: living engineering documentation
- `build/`: machine-readable build policy inputs
- `iso/`: archiso profile and live media configuration
- `packages/`: SchweisOS PKGBUILD sources
- `tools/`: maintainer-facing tools
- `scripts/`: small automation scripts
- `release/`: local staged release artifacts, not a publication endpoint
- `branding/`: source visual identity assets
- `website/`: future project website source
- `.github/`: future CI and GitHub metadata
- `tests/`: smoke, packaging, ISO, and regression tests

Implementation directories should remain small and aligned with their approved
design documents.
