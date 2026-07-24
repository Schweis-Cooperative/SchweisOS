# ADR-006 Distrobox Strategy

Version: 1.0

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-003 Package Sources
- ADR-007 Update Philosophy

## Context

Some Linux applications are distributed mainly for Ubuntu, Debian, or Fedora. Repackaging `.deb` or `.rpm` files into Arch packages creates high maintenance risk and can break upstream assumptions.

## Decision

SchweisOS will research and later integrate Distrobox with rootless Podman as a compatibility layer for foreign distribution userlands. It will not convert `.deb` or `.rpm` packages into Arch packages as the default strategy.

For the first implementation stage, Distrobox support is documentation and optional package integration only. A GUI workflow may be designed after the CLI workflow is stable.

## Alternatives

- Convert foreign packages into Arch packages.
- Tell users to manually use containers with no SchweisOS integration.
- Use Flatpak only.
- Build a custom container manager.

## Consequences

This may become a real SchweisOS differentiator, but it carries security and support risk. Distrobox is tightly integrated with the host and must not be marketed as strong sandboxing. Rootful containers must not be part of the normal GUI workflow.
