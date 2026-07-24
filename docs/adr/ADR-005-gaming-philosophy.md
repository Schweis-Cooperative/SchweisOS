# ADR-005 Gaming Philosophy

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-003 Package Sources
- ADR-007 Update Philosophy

## Context

Gaming is a core SchweisOS goal. Linux gaming advice often includes unverified kernel flags, scheduler tweaks, and sysctl changes. Defaults that cannot be measured or reversed create support burden.

## Decision

SchweisOS will support gaming through packages, driver guidance, compatibility tools, and repeatable tests. It will not apply unverified performance tweaks by default.

## Alternatives

- Ship aggressive performance tuning by default.
- Provide no gaming-specific layer.
- Fork kernels or Mesa packages early.

## Consequences

The distribution earns trust through stability and evidence. Some users may expect more dramatic tuning, but the project avoids fragile defaults and unnecessary forks.
