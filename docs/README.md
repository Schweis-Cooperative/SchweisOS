# SchweisOS Documentation Index

Version: 0.4
Status: Active
Date: 2026-07-27

This directory is the source of truth for SchweisOS engineering decisions. Important decisions must not remain only in chat history; they must be written into the relevant document and, when architectural, recorded as an ADR.

## Required Reading Order

1. [Project Vision](../VISION.md)
2. [Architecture Design Document](architecture/ADD.md)
3. [Architecture Decision Records](adr/README.md)
4. [Security Model](security/security-model.md)
5. [Packaging Guide](packaging/packaging-guide.md)
6. [Package Repository Workflow](release/repository-workflow.md)
7. [Release Signing Workflow](release/release-signing-workflow.md)
8. [Release Artifact Pipeline](release/release-artifact-pipeline.md)
9. [Release Engineering Guide](release/release-engineering-guide.md)
10. [ISO Build Workflow](build/README.md)
11. [Testing Strategy](testing/testing-strategy.md)
12. [Developer Handbook](developer/developer-handbook.md)
13. [New Conversation Master Prompt](developer/MASTER_PROMPT.md)
14. [Product Roadmap](roadmap/product-roadmap.md)

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
