# ADR-001 Repository Strategy

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-003 Package Sources
- ADR-008 Documentation First

## Context

SchweisOS starts as a one-developer project. Splitting documentation, ISO profiles, packages, tests, and automation into many repositories would create coordination overhead before the project has stable release practices.

## Decision

SchweisOS will start as a monorepo with clear top-level boundaries: `docs/`, `iso/`, `packages/`, `tools/`, `scripts/`, `branding/`, `website/`, `.github/`, and `tests/`.

## Alternatives

- Multi-repository architecture from day one.
- Documentation-only repository plus later implementation repositories.
- Fork an existing Arch-based distribution tree.

## Consequences

The monorepo reduces early maintenance cost and keeps decisions close to implementation. The risk is that the repository may grow large later. This is acceptable because the directory boundaries are designed to allow future extraction.
