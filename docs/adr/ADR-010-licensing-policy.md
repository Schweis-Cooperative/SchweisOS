# ADR-010 Licensing Policy

Version: 1.1

## Status

Accepted

## Date

2026-07-24

## Related ADRs

- ADR-001 Repository Strategy
- ADR-008 Documentation First
- ADR-009 Distribution Identity Packages

## Context

SchweisOS needs a clear licensing policy before adding official license files or publishing release artifacts.

The project has already approved that SchweisOS source code will be licensed under `GPL-3.0-or-later`, that SchweisOS is open source, that documentation and branding must be evaluated independently, and that lightweight contribution processes are preferred over complex legal agreements where appropriate.

Licensing must support the project's constitutional values: user freedom, transparency, upstream compatibility, maintainability, privacy, security, and long-term sustainability.

## Decision

SchweisOS will use a separated licensing model:

- Source code: `GPL-3.0-or-later`.
- Documentation: `CC-BY-SA-4.0`.
- Non-logo artwork and non-mark visual assets: `CC-BY-SA-4.0` by default unless a file states otherwise.
- Official names, logos, marks, and brand identifiers: not covered by the general software license; repository-shipped assets use explicit `LicenseRef-SchweisOS-Brand-Assets` terms until a fuller trademark and brand-use policy exists.
- Third-party software and assets: remain under their upstream licenses and must be documented without relicensing claims.

All new project-owned files should use SPDX identifiers where practical.

## Why GPL-3.0-or-later

`GPL-3.0-or-later` is chosen for SchweisOS source code because it protects the user's freedom to study, modify, share, and redistribute the project's own software while keeping improvements in the same copyleft family.

The "or later" form gives the project and downstream users a controlled compatibility path if a future GPL version becomes important. It avoids locking the project forever to GPLv3-only while still preserving strong copyleft.

This fits SchweisOS because the project is not trying to build a proprietary product layer on top of Arch. Its value should come from transparent engineering, not from restricting access to the integration code that defines the distribution.

## Scope of the Software License

The software license applies to project-owned source code, scripts, packaging helpers, build tooling, installer modules written by SchweisOS, tests, CI logic, and other executable or code-like files created by the project.

It does not automatically apply to:

- Documentation.
- Logos and trademarks.
- Third-party source code.
- Vendored material under another license.
- User-generated issue or discussion content unless contribution terms say otherwise.
- Generated binary packages that include third-party components under their own licenses.

When a file is project-owned code, it should include:

```text
SPDX-License-Identifier: GPL-3.0-or-later
```

## Documentation License

SchweisOS documentation will use `CC-BY-SA-4.0`.

Documentation is evaluated separately from source code because it is read, copied, translated, quoted, and adapted differently than executable code. `CC-BY-SA-4.0` gives users and contributors broad reuse rights while requiring attribution and preserving share-alike behavior for adapted documentation.

This is preferable to using GPL for documentation, because GPL is designed for software. It is also preferable to a permissive documentation license for SchweisOS because share-alike better matches the project's goal of keeping improvements to core project knowledge open.

Documentation files should include:

```text
SPDX-License-Identifier: CC-BY-SA-4.0
```

## Artwork and Branding License

SchweisOS separates general artwork from official brand identity.

Non-logo artwork, screenshots, wallpaper source files, diagrams, and visual documentation assets should use `CC-BY-SA-4.0` by default unless a file states otherwise.

Official logos, names, marks, slogans, and brand identifiers require separate treatment. SchweisOS is not currently a registered trademark, but the project should reserve the ability to protect its name and marks later. This protects users from misleading unofficial builds and protects contributors from brand confusion.

Until a trademark policy exists, official logos and brand marks must not be assumed to be freely reusable under the software license. Any brand asset included in the repository must carry explicit licensing and usage notes.

The initial SchweisOS logo and runtime icon assets use
`LicenseRef-SchweisOS-Brand-Assets`, whose canonical text is packaged as
`/usr/share/licenses/schweisos-branding/BRAND-ASSETS.md`. Those terms permit
unmodified redistribution with official SchweisOS source trees, packages,
installation media, release artifacts, documentation, screenshots, and mirrors
that distribute unmodified official artifacts. They also permit truthful
referential use. They do not permit confusing unofficial branding, modified
logos, or claims that a remix, fork, mirror, or unsigned artifact is an
official SchweisOS release.

## Third-Party Software Policy

SchweisOS must not imply that it relicenses upstream Arch packages or third-party software.

Third-party code, packages, fonts, icons, wallpapers, documentation, and binaries remain under their original licenses. SchweisOS packaging metadata should preserve upstream license information and comply with redistribution terms.

If a third-party component cannot be redistributed legally or clearly, it must not be included in official SchweisOS release artifacts.

## Contributor Policy

SchweisOS will use a lightweight inbound-equals-outbound contribution policy by default.

By contributing to SchweisOS, a contributor agrees that their contribution may be distributed under the license that applies to the target file or project area. No Contributor License Agreement is required at this stage.

This keeps contribution overhead low for a small project while preserving license clarity. If the project later needs a Developer Certificate of Origin or stronger provenance process, that decision must be recorded in a new ADR.

## Future Trademark Considerations

Copyright licenses do not provide a complete brand protection model.

SchweisOS should later create a trademark and brand-use policy before public release branding becomes important. That policy should explain how the SchweisOS name, logo, and marks may be used by official releases, community remixes, mirrors, documentation, screenshots, and downstream derivatives.

Trademark policy must not be used to hide source code or restrict ordinary user freedom. Its purpose should be preventing confusion about what is official.

## Compatibility With Arch and the GPL Ecosystem

SchweisOS licensing must remain compatible with upstream Arch and the wider GPL ecosystem.

Arch packages keep their own upstream licenses. SchweisOS project-owned tooling under `GPL-3.0-or-later` can coexist with packages under other licenses because SchweisOS is primarily aggregating, configuring, documenting, and building distribution artifacts rather than relicensing upstream software.

Where SchweisOS combines code into a single derived work, license compatibility must be checked before inclusion.

## Alternatives Considered

MIT or BSD for all project code:

This would reduce reuse friction, but it would not preserve copyleft for SchweisOS-specific integration work. It fits libraries better than a distribution identity and tooling layer.

GPL-3.0-only:

This would provide strong copyleft but reduce future compatibility flexibility. The approved project decision prefers `GPL-3.0-or-later`.

GPL for documentation:

This would create unnecessary friction because GPL is designed for software, not manuals, architecture documents, and contributor guides.

GFDL for documentation:

This is a documentation-specific copyleft license, but it is heavier than the project needs and less familiar for modern collaborative repository documentation.

CC-BY-4.0 for documentation:

This would be simpler and permissive, but it would not preserve share-alike behavior for improvements to SchweisOS documentation.

All assets under the software license:

This would blur the difference between executable code, documentation, artwork, and brand identity. It would also weaken future brand governance.

Full Contributor License Agreement:

This may become useful for a larger foundation-backed project, but it is too heavy for the current one-developer bootstrap phase.

## Consequences

This policy gives SchweisOS a clean licensing foundation:

- Source code has a strong copyleft license.
- Documentation is openly reusable and share-alike.
- Branding can remain protected from misleading unofficial use.
- Contributors can participate without a heavy legal process.
- Third-party licenses remain visible instead of being swallowed by a project-wide assumption.

The cost is that the repository must track more than one license domain. This is acceptable because source code, documentation, artwork, branding, and third-party packages have different legal and practical needs.

## Recommended Repository Files

`LICENSE` should exist at the repository root.

It should state the project licensing summary, not pretend that every file has one license. It should say that SchweisOS source code is licensed under `GPL-3.0-or-later`, documentation under `CC-BY-SA-4.0`, and brand assets under explicit per-file terms such as `LicenseRef-SchweisOS-Brand-Assets` plus any future trademark policy.

`COPYING` should exist at the repository root.

It should contain the full GPL-3.0 license text or clearly point to the canonical GPL-3.0 text when the exact full text is added. Keeping `COPYING` is conventional for GPL projects and makes source redistribution clearer.

`CONTRIBUTING.md` should exist at the repository root.

It should explain the lightweight inbound-equals-outbound policy, documentation-first workflow, SPDX expectations, issue/PR rules, and the fact that contributors must only submit work they have the right to license.

Recommended future support files:

- `COPYING.docs` for the full `CC-BY-SA-4.0` legal code or canonical reference.
- `TRADEMARKS.md` for SchweisOS name and logo usage once the brand policy is designed.
- `LICENSES/` if the project adopts a REUSE-style multi-license layout later.
