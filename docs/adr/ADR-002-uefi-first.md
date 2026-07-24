# ADR-002 UEFI First

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-004 Default Filesystem

## Context

The first release must be small and testable. Supporting both modern UEFI and legacy BIOS from the beginning would expand installer testing and bootloader complexity.

## Decision

SchweisOS will prioritize UEFI systems. systemd-boot is the default bootloader. GRUB is supported as an alternative path, but legacy BIOS support is not required for the first release.

## Alternatives

- GRUB as the universal default.
- Support UEFI and BIOS equally in the first release.
- Use rEFInd as the default boot manager.

## Consequences

The default boot path is simpler and easier to test. The tradeoff is that older BIOS-only machines are not first-release targets. Documentation and installer checks must be explicit about this.
