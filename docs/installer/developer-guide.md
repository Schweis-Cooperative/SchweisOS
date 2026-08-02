# Installer Developer Guide

Version: 1.0
Status: Active
Date: 2026-08-02

SPDX-License-Identifier: CC-BY-SA-4.0

## Ownership Map

- `packages/calamares/` owns the reviewed upstream Calamares binary package and
  suppresses its generic launcher.
- `packages/schweisos-calamares-config/` owns SchweisOS installer policy,
  presentation, launch integration, package selection, target reconciliation,
  and installed-system helpers.
- `iso/profiles/kde/` owns live-medium composition and only genuinely live-only
  overlay state.
- `tests/validate-installer-config.sh` validates package source contracts.
- `tests/validate-installer-runtime-payload.sh` validates installed runtime
  ownership and modes in a staged live root.
- `tests/validate-built-iso-boot.sh` and `scripts/schweisos-doctor` validate the
  completed ISO payload.

Do not copy installer configuration into `airootfs/` or duplicate it between
the Calamares binary and configuration packages.

## Presentation

`welcomeq.qml` owns the text-first first page, language selector, informative
network state, and maintainer attribution. `show.qml` owns only the execution
slideshow. `branding.desc` owns Calamares colors, dimensions, URLs, and
canonical runtime logo references.

The repository has one real logo source. Installer files reference the runtime
path installed from that source; they do not embed or copy a second logo.
Maintainer identity is written as `Maintained by` or `Project Maintainer`, not
as a contributor credit.

Use Calamares-supported QML and configuration interfaces. Do not patch
Calamares merely to change spacing, colors, or wording.

## Installation Pipeline

The execution order is security-sensitive:

```text
preflight
  -> partition
  -> mount
  -> unpackfs
  -> target reconciliation
  -> machine identity, fstab, locale, keyboard, users, and clock
  -> target pacman policy
  -> systemd-boot and selected-kernel initramfs
  -> services
  -> unmount
```

Reconciliation must run immediately after `unpackfs`. Moving it later risks
executing target configuration with the ephemeral live account, live
authorization rules, or unselected software still present. Removing it makes
the copied live system an invalid installed system.

## Package and Timezone Maintenance

Required target packages live in `target-packages.x86_64`. Selectable packages
are additionally mapped in the chooser configs, reconciliation helper, and ISO
package list. Keep those sources synchronized through validators; never make
an online package appear selectable when it is absent from the offline payload.

Timezone and country data come from upstream `tzdata` and Calamares. Do not
maintain a SchweisOS timezone allowlist. Source and runtime checks must ensure
the IANA index and `Europe/Istanbul` exist as representative completeness
guards.

## Validation Workflow

Run from the repository root after each logical change:

```bash
tests/validate-installer-config.sh
tests/test-installer-experience.sh
tests/test-installer-reconciliation.sh
tests/validate-iso-profile.sh
git diff --check
```

After packaging, validate the staged live root with:

```bash
tests/validate-installer-runtime-payload.sh /path/to/staged/live/root
```

After a canonical ISO build, run the built-ISO validator and doctor. Static
source checks do not prove rendering, partitioning, installation completion,
first boot, Ventoy behavior, or hardware support. Record those as separate
executed qualification evidence; never infer them from validator success.

## Release Discipline

Changing any file listed in a PKGBUILD `source` array requires a package release
bump, checksum refresh, package rebuild, package-role signature, candidate
validation, and atomic signed-repository activation before the ISO can consume
the new behavior. The ISO never builds or signs installer packages.
