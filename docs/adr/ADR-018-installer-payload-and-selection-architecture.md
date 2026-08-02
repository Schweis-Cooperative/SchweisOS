# ADR-018 Installer Payload and Selection Architecture

Version: 1.0

## Status

Accepted for Faz 1 source implementation

## Date

2026-08-02

## Related ADRs and DDRs

- ADR-003 Package Sources
- ADR-007 Update Philosophy
- ADR-008 Documentation First
- ADR-011 Repository Architecture
- ADR-012 ISO Build Architecture
- ADR-016 Installer Architecture
- DDR-002 Installer Experience

## Context

ADR-016 selected a clean `pacstrap` installation from signed Arch and
SchweisOS repositories. That path produces a package-owned target and avoids
copying live-only state. It also makes the complete installation depend on
network access because the live image does not carry an installation package
pool. Removing Calamares' generic internet requirement prevents a false UI
blocker, but it does not create an offline installation source.

Faz 1 now requires both a working offline installation and user-selectable
software. Browser, kernel, and optional-feature choices must be deterministic,
must not mix AUR or arbitrary third-party trust into the installer, and must
not leave packages that the user explicitly rejected. A new unsigned local
repository, build-time signing key, or silent network fallback would violate
the repository and trust architecture.

The current live SquashFS already contains a package-owned Arch system whose
packages were resolved and signature-verified by the canonical ISO build. The
remaining problem is separating reusable target state from Archiso-only state
without turning cleanup into an unbounded blacklist.

## Decision

SchweisOS uses Calamares' upstream `unpackfs` module as the offline payload
source for Faz 1. It copies the mounted, validated Archiso SquashFS from
`/run/archiso/airootfs` into the mounted target. The installer then runs one
SchweisOS-owned reconciliation helper before user creation and bootloader
installation.

The reconciliation helper is fail-closed and declarative:

1. It accepts the fixed Firefox browser identifier plus only enumerated kernel
   and feature-set identifiers produced by packaged Calamares chooser
   instances.
2. It removes the exact, reviewed Archiso-only package set and exact
   profile-owned live paths.
3. It removes unsupported browser payload, unselected kernels, and unselected
   optional-feature packages from the target with pacman, preserving dependency
   checks and pacman hooks.
4. It removes the ephemeral `live` account and home.
5. It marks the required target manifest and selected packages explicit.
6. It records a non-secret installation selection manifest under
   `/var/lib/schweisos/installer/` for support and recovery diagnostics.

The live ISO package list contains the complete selectable package universe.
This makes every displayed choice available without a network connection and
increases ISO size. The universe is intentionally curated and is not an AUR
frontend. A choice may be displayed only when all of its packages come from
the official Arch repositories or the signed SchweisOS repository used by the
ISO build.

Browser selection is not exposed as a separate Faz 1 page. Firefox is the fixed
installed browser because it is available from the accepted repository trust
domains and has broad compatibility. Chromium, Chrome, Edge, Opera, and
unowned external binary channels are not presented. LibreWolf, Floorp, Zen
Browser, Waterfox, Mullvad Browser, and Brave are not exposed until SchweisOS
has a separately accepted, maintainable package source for them. The installer
must not silently translate those names to AUR helpers or third-party binary
downloads.

Kernel selection is single-choice. `linux-zen` is the default and is labelled
recommended for desktop responsiveness and gaming. `linux`, `linux-lts`, and
`linux-hardened` remain supported alternatives. Installed-system bootloader
generation reads the recorded selection rather than assuming the `linux`
package name.

Installation-profile selection is single-choice. Profiles are implemented as a
package-owned mapping from profile identifiers to optional feature identifiers:
`privacy`, `gaming`, `developer`, `creator`, `office`, and `minimal`. The
optional-feature page is still evaluated after the profile page, and duplicate
profile/manual selections are idempotent. This gives new users a safe starting
point without hiding the exact package groups that will remain in the target.

Optional feature sets are multi-choice and package-level descriptions explain
why each top-level package is present. Hardware-critical firmware, networking,
the Plasma session, package trust, boot support, and accessibility required to
complete installation are not optional toggles. Optional groups must remain
coarse enough that a one-maintainer project can test every combination.

Network detection is informative and privacy-bounded. Calamares checks
SchweisOS-owned HTTPS endpoints as optional requirements and records
`hasInternet`. No connectivity result blocks installation. The offline payload
and all chooser options remain complete without a connection. Online access
may refresh repository metadata only through the normal configured pacman
repositories; it must not change the selected package set or perform a partial
system upgrade during installation.

Timezone choice continues to use Calamares and the packaged IANA `tzdata`
database. SchweisOS does not maintain a downstream country or timezone list.
Runtime validation requires the IANA mapping and `Europe/Istanbul` zone before
the installer starts.

## Ownership

- `packages/calamares/` owns enabling the reviewed upstream Calamares modules.
- `packages/schweisos-calamares-config/` owns chooser configuration, the
  required target manifest, the selection reconciliation helper, the
  `unpackfs` contract, installed selection evidence, and installer UI.
- `iso/profiles/kde/packages.x86_64` owns inclusion of the complete offline
  choice universe in the live SquashFS.
- `tests/validate-installer-config.sh` owns source-contract validation.
- `tests/validate-installer-runtime-payload.sh` owns staged-live-root payload
  validation.
- `docs/installer/` owns maintainer and qualification guidance.

The installer does not own package signing, repository publication, AUR
automation, or arbitrary downloads.

## Alternatives Considered

### Keep Network-Only `pacstrap`

This remains the cleanest package-state construction, but it cannot meet the
accepted offline-install requirement without another payload source.

### Add an ISO-Local Repository

An ISO-local repository would preserve fresh package construction, but a
production repository database must be generated, signed, version-bound, and
validated by the release pipeline before the ISO build. That is a valid future
replacement if ISO size or live-root reconciliation becomes too expensive. It
is not accepted as a build-time unsigned database or a second signing path.

### Download Optional Packages After Installation

This makes the displayed choices unreliable offline, changes the result based
on mirror state, and risks partial installation. It is rejected.

### Install AUR or Third-Party Browser Binaries

This would hide a different trust model inside the installer. It is rejected.

## Consequences

Positive:

- the baseline and every displayed choice are available offline;
- package selection uses upstream Calamares chooser interfaces;
- the target retains pacman's package database and full-system update model;
- there is no unsigned repository, temporary key, or custom package manager;
- user selections are explicit, supportable, and recorded locally.

Negative:

- the ISO grows because mutually exclusive kernels and browsers are present in
  the live payload;
- the live-state reconciliation allowlist is security- and maintenance-
  critical;
- each Archiso profile change must be reviewed against the target cleanup
  contract;
- static tests cannot prove every package-removal hook or first boot.

Rollback is to restore ADR-016's network-only `pacstrap` sequence and remove
the chooser universe from the live package list. No installed-system format or
repository migration is required.

## Validation

Validation must fail if:

- `packagechooser`, `welcomeq`, `unpackfs`, or the required packages module is
  missing from the Calamares binary;
- a chooser identifier or package appears outside the declared allowlist;
- a displayed package is absent from the live ISO package universe;
- browser or kernel selection permits zero or multiple choices;
- the selected kernel is not used by systemd-boot generation;
- live-only packages, live authorization, Archiso hooks, live Plymouth units,
  the `live` account, or the installer itself remain in the target contract;
- the reconciliation helper accepts an unknown identifier, an unsafe target,
  or an unmounted target;
- internet becomes a required welcome condition;
- the runtime lacks `tzdata` or `Europe/Istanbul`;
- documentation claims VM or hardware success without evidence.

Before release-candidate status, a canonical ISO must complete offline and
online installation in UEFI QEMU, boot the installed system, and pass a real
hardware installation test. Ventoy Normal and GRUB2 modes and direct-written
USB remain separate boot-media qualification cases; static source validation
cannot prove them.
