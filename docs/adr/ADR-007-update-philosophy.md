# ADR-007 Update Philosophy

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-003 Package Sources
- ADR-006 Distrobox Strategy

## Context

Arch Linux expects full-system upgrades. Partial upgrades are a common source of breakage. SchweisOS must improve approachability without violating Arch's package model.

## Decision

SchweisOS will support full-system updates only for host packages. Update tooling may guide and explain, but it must not replace pacman semantics or encourage partial upgrades.

## Alternatives

- Provide package-by-package GUI updates.
- Freeze selected system packages.
- Build a new update manager that hides pacman behavior.

## Consequences

SchweisOS remains close to Arch and reduces unsupported states. The user experience must explain why full updates matter, especially to users coming from non-rolling distributions.
