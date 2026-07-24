# ADR-004 Default Filesystem

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-002 UEFI First

## Context

Btrfs enables snapshots and advanced layouts, but reliable rollback requires careful installer, bootloader, snapshot, and recovery design. The first release should avoid promising recovery features before they are tested.

## Decision

SchweisOS will use ext4 as the default filesystem. Btrfs will be available as an installer option but not the default.

## Alternatives

- Btrfs by default with snapshots.
- XFS by default.
- ext4 only, no Btrfs option.

## Consequences

The default install remains familiar and low maintenance. Users who want Btrfs can choose it. Snapshot and rollback design can be added later without destabilizing the first release.
