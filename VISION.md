# SchweisOS Vision

Version: 1.0
Status: Canonical
Date: 2026-07-25

## Purpose

SchweisOS exists to make Arch Linux more approachable for desktop users without weakening the qualities that make Arch valuable: transparency, simplicity, user control, current software, and respect for upstream work.

The project is not an attempt to replace Arch Linux, hide Linux from users, or create a separate technology stack for its own sake. SchweisOS is a distribution layer built around integration, documentation, conservative defaults, and clear trust boundaries.

## Users

SchweisOS is built for people who want the strength of an Arch-based system but do not want avoidable uncertainty to be part of daily use.

It should serve experienced Arch users who expect reliability, inspectability, and honest system behavior. It should also serve newer Linux users who are ready to learn, but should not be forced to learn through fear, broken defaults, unclear warnings, or undocumented decisions.

The project should never assume that ease of use requires removing control from the user. A guided path is useful only when the user can still understand, inspect, and change the system.

## Problem Statement

Arch Linux is powerful because it is direct, current, and transparent. Those same qualities can be difficult for users who want a stable desktop workflow, a clear installation path, gaming support, and a better explanation of software sources and trust.

SchweisOS aims to reduce unnecessary complexity around those areas while preserving the underlying Arch model. It should clarify rather than obscure. It should guide rather than take over. It should make the common path safer without making advanced paths inaccessible.

## User Experience

A SchweisOS system should feel understandable.

Users should be able to tell what comes from Arch, what comes from SchweisOS, what comes from Flatpak, what comes from AUR, and what may come from compatibility containers or other external sources. These sources must not be presented as the same trust domain.

Smart defaults are acceptable. Hidden behavior is not.

Convenience is valuable when it reduces repeated work, explains risk, and remains reversible. Convenience becomes harmful when it silently changes the system, hides important tradeoffs, or prevents users from learning what their computer is doing.

## Engineering Philosophy

SchweisOS should be engineered as if it must still be understandable years after the original decisions were made.

The project should prefer small, boring, auditable components over large custom systems. New technology should be introduced only when it solves a real problem that existing upstream tools do not solve well enough.

Every important architectural decision should have a documented reason. Documentation is part of the product because it carries institutional memory, makes review possible, and allows contributors to understand not only what exists, but why it exists.

Maintenance cost is a technical property. A feature that cannot be maintained by the project should not become a default merely because it is attractive.

## Relationship With Arch Linux

SchweisOS is downstream of Arch Linux and should remain close to Arch wherever practical.

Arch packages, Arch tooling, Arch conventions, and Arch documentation should be respected. SchweisOS should not fork Arch packages without a clear reason, a documented maintenance plan, and an exit path back toward upstream.

SchweisOS should add value through integration, defaults, documentation, source awareness, and release discipline. It should not pretend that upstream Arch work is SchweisOS-owned work.

## Relationship With Upstream Open Source

SchweisOS depends on the work of many upstream projects. That dependency creates responsibility.

The project should contribute fixes, documentation, bug reports, and packaging improvements upstream whenever practical. Maintaining unnecessary downstream forks should be treated as a cost, not a badge of independence.

Open-source projects belong to their communities more than to any single person, company, or distribution. SchweisOS should be developed in a way that respects that shared ownership.

## Security, Privacy, and User Freedom

Security, privacy, and user autonomy are non-negotiable project values.

SchweisOS should not collect or transmit user data by default. Telemetry, crash reporting, diagnostics, accounts, synchronization, or feedback systems must be optional, clearly explained, and based on explicit user consent.

Security claims must match implemented behavior. The project should prefer signed packages, verifiable release artifacts, conservative trust boundaries, and honest documentation over vague promises.

User freedom means the system remains under the user's control. Graphical tools may assist, warn, and simplify. They must not replace the user's ability to inspect, configure, repair, or operate the system directly.

## Gaming and Performance

Gaming is an important SchweisOS use case, but gaming support must not come at the cost of system integrity.

The project should support gaming through appropriate packages, driver guidance, compatibility tools, documentation, and repeatable testing. It should not ship unverifiable internet tweaks, unsafe kernel changes, or hidden performance modifications for the sake of benchmark numbers.

Performance work should be measurable, explainable, reversible, and documented.

## Hardware Awareness

Hardware-specific optimizations should assist users, not silently modify their systems.

When hardware guidance is needed, SchweisOS should explain what is being changed, why it matters, what risk exists, and how the user can undo it. Automatic behavior should be limited to cases where the outcome is safe, expected, and documented.

## Community Philosophy

SchweisOS should be open to users who are learning and contributors who care about sustainable engineering.

The project should prefer patient explanation over gatekeeping, evidence over rumor, and reviewable decisions over personal authority. Disagreement should be resolved through facts, tests, maintenance analysis, and documented tradeoffs.

A healthy project is not owned only by the person who began it. It becomes stronger when its reasoning is visible enough for others to challenge, improve, and continue.

## Architectural Principles

Future architectural decisions should be guided by these principles:

- Stay close to upstream Arch.
- Prefer upstream collaboration over downstream forks.
- Keep distribution-owned components small and auditable.
- Document important decisions before implementation.
- Preserve clear software source and trust boundaries.
- Make defaults helpful, visible, and reversible.
- Protect privacy by default.
- Treat security-sensitive behavior as architecture, not polish.
- Keep the terminal available and the system inspectable.
- Optimize only when the change is measurable and explainable.
- Avoid features whose maintenance cost exceeds the project's capacity.
- Design for a single maintainer first, and for a larger contributor base later.

## Enduring Standard

SchweisOS should be judged by whether it makes an Arch-based desktop more understandable, safer to operate, and easier to maintain without taking control away from the user or separating itself unnecessarily from the upstream open-source ecosystem.
