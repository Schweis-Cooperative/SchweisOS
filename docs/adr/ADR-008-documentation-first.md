# ADR-008 Documentation First

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-001 Repository Strategy

## Context

SchweisOS starts with one developer and aims to become a long-lived distribution. Unwritten decisions become hidden maintenance cost.

## Decision

SchweisOS will follow a documentation-first engineering workflow. Important architecture, packaging, security, release, and testing decisions must be documented before implementation.

## Alternatives

- Code first, document later.
- Keep decisions only in issue discussions or chat history.
- Document only after the first ISO.

## Consequences

Progress may feel slower at the start, but future contributors and the maintainer will have a stable reference. This also reduces accidental scope creep.
