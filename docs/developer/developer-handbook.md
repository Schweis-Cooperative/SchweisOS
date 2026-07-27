# SchweisOS Developer Handbook

Version: 0.2
Status: Draft
Date: 2026-07-27

## Engineering Principles

- Stay close to upstream Arch.
- Prefer configuration and meta packages over forks.
- Document before implementing major changes.
- Keep one-developer maintenance cost visible.
- Make changes reversible where possible.
- Do not hide the terminal; provide GUI guidance where it helps.
- Do not ship telemetry by default.

## Workflow

Before substantial work, declare `Working Mode`, `Current Goal`,
`Deliverables`, and `Out of Scope`.

Every substantial change should follow this sequence:

1. Define the problem.
2. Compare alternatives.
3. Evaluate risk.
4. Evaluate maintenance cost.
5. Evaluate security impact.
6. Propose or record the decision.
7. Create or update an ADR.
8. Update the ADD when architecture changes.
9. Update roadmap or guides when scope changes.
10. Implement.
11. Test.

## Repository Areas

- `docs/` owns project truth.
- `iso/` owns Archiso profile work.
- `packages/` owns PKGBUILD sources.
- `tools/` owns maintainer utilities.
- `scripts/` owns build and artifact entry points.
- `tests/` owns repeatable validation.
- `branding/` owns source visual identity.
- `build/` owns machine-readable build-host policy.
- `release/` is a generated local staging boundary, not a publication endpoint.

## Commit Rules

Use small commits with clear scope. Recommended prefixes:

- `docs:`
- `adr:`
- `iso:`
- `pkg:`
- `test:`
- `release:`
- `security:`

## Review Rules

Even with one developer, review should be simulated before merge:

- Does this fork upstream unnecessarily?
- Does this increase support burden?
- Is the user informed about trust boundaries?
- Is rollback possible?
- Are docs updated?
- Are tests proportional to risk?

## Definition of Done

A change is done only when implementation, documentation, and relevant validation are complete.

## Context Handoff

A new engineering conversation must begin with the reusable
[SchweisOS Master Prompt](MASTER_PROMPT.md). The prompt is a discovery and
safety contract, not a substitute for reading the repository at its current
commit.
