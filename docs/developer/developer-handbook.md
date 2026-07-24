# SchweisOS Developer Handbook

Version: 0.1
Status: Draft
Date: 2026-07-24

## Engineering Principles

- Stay close to upstream Arch.
- Prefer configuration and meta packages over forks.
- Document before implementing major changes.
- Keep one-developer maintenance cost visible.
- Make changes reversible where possible.
- Do not hide the terminal; provide GUI guidance where it helps.
- Do not ship telemetry by default.

## Workflow

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
- `iso/` will own archiso profile work.
- `packages/` will own PKGBUILD sources.
- `tools/` will own maintainer utilities.
- `scripts/` will own small automation scripts.
- `tests/` will own repeatable validation.

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
