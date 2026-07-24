# SchweisOS Constitution

Version: 1.0
Status: Ratified
Date: 2026-07-24

This Constitution is the highest-level governance and engineering policy document of SchweisOS. It defines the values that guide all architecture, engineering, release, documentation, and community decisions.

Operational details belong in the ADD, ADRs, handbooks, guides, and release documents. This document defines the principles those documents must obey.

## Mission

SchweisOS exists to make the power of Arch Linux more accessible for desktop users while preserving user control, technical honesty, privacy, security, and upstream compatibility.

## Vision

SchweisOS aims to become a sustainable, transparent, Arch-based desktop distribution that can be trusted by users, maintained by a small team, and improved over many years without losing its engineering discipline.

## Core Principles

- Stay close to upstream Arch.
- Avoid unnecessary forks.
- Prefer small working systems over unfinished grand designs.
- Keep maintenance cost visible.
- Give users control over their systems.
- Make important decisions public and documented.
- Do not hide risk behind friendly interfaces.
- Do not ship telemetry by default.
- Optimize only where behavior can be measured or justified.

## Documentation First

Documentation is part of the product, not an afterthought.

Significant architecture, security, packaging, release, and user-experience decisions must be documented before implementation. Code may implement documented decisions; it must not silently create policy.

## Upstream First

SchweisOS should use upstream Arch packages, upstream project defaults, and standard Linux mechanisms wherever practical.

Forks, downstream patches, custom tools, or replacement technologies require clear justification, documented alternatives, and a maintenance plan.

## Privacy Principles

SchweisOS must not collect, transmit, or monetize user data by default.

Any diagnostic, crash-reporting, feedback, account, synchronization, or telemetry feature must be optional, clearly explained, and initiated with explicit user consent.

## Security Principles

Security claims must match implemented protections.

SchweisOS must prefer signed packages, verifiable releases, clear trust boundaries, conservative defaults, and honest communication about limitations. Security-sensitive changes require documentation and review before release.

## Transparency Principles

Users and contributors must be able to understand what SchweisOS changes, what it inherits from Arch, what it adds, and where software comes from.

Official repositories, Arch repositories, Flatpak, AUR, and compatibility containers must not be presented as the same trust domain.

## User Freedom

SchweisOS must not take ownership of the system away from the user.

The terminal remains available. Graphical tools may guide, warn, and simplify, but they must not prevent users from understanding or controlling their systems.

## Engineering Philosophy

Engineering decisions must be boring where possible and innovative only where necessary.

The project favors maintainable integration, reversible changes, clear defaults, testable behavior, and long-term readability over novelty, branding, or short-term convenience.

## Performance Philosophy

Performance work must be evidence-based.

SchweisOS must not ship undocumented internet tweaks, unverifiable claims, or irreversible performance changes as defaults. Performance improvements should be measurable, explainable, and safe to disable.

## Decision Making Process

Substantial decisions follow this order:

1. Define the problem.
2. Compare alternatives.
3. Evaluate maintenance cost.
4. Evaluate security and privacy impact.
5. Evaluate user freedom and transparency.
6. Record the decision.
7. Implement only after the decision is documented.

The correct Working Mode must be declared before substantial work begins.

## ADR Policy

Architecture Decision Records are required for important technical decisions, reversals, or changes to established architecture.

An ADR must describe context, decision, alternatives, consequences, status, date, and related ADRs. Superseded decisions must remain in history and link to their replacement.

## Open Source Policy

SchweisOS should be developed in the open using open-source licensing.

The project should prefer open formats, open tools, public documentation, and reproducible processes. Closed components may only be referenced or integrated when legally redistributable, clearly labeled, and aligned with user choice.

## Community Standards

SchweisOS community work should be respectful, evidence-seeking, security-aware, and welcoming to users who are still learning.

Contributors should argue from facts, tests, documentation, and maintainability. Harassment, deceptive behavior, hidden data collection, or pressure to accept unclear tradeoffs is incompatible with the project.

## Amendment Process

This Constitution is intentionally difficult to change.

Amendments require:

1. A written proposal explaining the motivation.
2. A compatibility review against the Mission, Vision, and Core Principles.
3. A security and privacy impact review.
4. A maintenance impact review.
5. An ADR recording the amendment decision.
6. An update to this document with a new version number and date.

No amendment may be merged as part of an unrelated implementation change. Constitutional changes must be reviewed as their own explicit project decision.
