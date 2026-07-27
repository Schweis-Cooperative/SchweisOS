# Contributing to SchweisOS

SPDX-License-Identifier: CC-BY-SA-4.0

Thank you for helping SchweisOS become a maintainable Arch-based desktop
distribution.

SchweisOS follows a documentation-first process. Significant architecture,
security, packaging, release, and user-experience decisions must be documented
before implementation.

## Working Modes

Substantial work should declare one Working Mode:

- Architect: architecture, ADD updates, ADRs, alternatives, sustainability.
- Engineer: implementation, packages, archiso profiles, scripts, tests.
- Release Engineer: repository, CI/CD, signing, release process, metadata.
- Reviewer: critical review only, no implementation.

The declaration must also state:

- `Current Goal`
- `Deliverables`
- `Out of Scope`

Work must remain consistent with that scope. An architectural change updates
the relevant ADR and ADD before or with implementation; a review request does
not authorize implementation.

## Contribution Licensing

SchweisOS uses a lightweight inbound-equals-outbound contribution policy.

By contributing, you agree that your contribution may be distributed under the
license that applies to the target file or project area:

- Source code and code-like files: `GPL-3.0-or-later`
- Documentation: `CC-BY-SA-4.0`
- Non-logo artwork: `CC-BY-SA-4.0` unless stated otherwise
- Third-party material: original upstream license

Do not submit work unless you have the right to license it this way.

## Before Opening a Pull Request

- Read [docs/project/CONSTITUTION.md](docs/project/CONSTITUTION.md).
- Check whether an ADR is required.
- Keep changes small and reviewable.
- Update documentation when behavior, architecture, packaging, release, or
  security policy changes.
- Include validation steps in the pull request.
- Do not add telemetry, account requirements, or hidden network behavior.

## Commit Style

Recommended prefixes:

- `docs:`
- `adr:`
- `pkg:`
- `iso:`
- `test:`
- `release:`
- `security:`
- `chore:`

## Review Expectations

Review should prioritize correctness, maintainability, security, privacy,
Arch compatibility, and user control over visual polish or novelty.
