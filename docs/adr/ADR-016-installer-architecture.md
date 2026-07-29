# ADR-016 Installer Architecture

Version: 0.1

## Status

Accepted for Faz 1 source implementation

## Date

2026-07-29

## Related ADRs and DDRs

- ADR-002 UEFI First
- ADR-004 Default Filesystem
- ADR-007 Update Philosophy
- ADR-008 Documentation First
- ADR-009 Distribution Identity Packages
- ADR-011 Repository Architecture
- ADR-012 ISO Build Architecture
- ADR-014 Live Boot Experience Architecture
- ADR-015 GRUB Theme Architecture
- DDR-001 Boot Experience

## Context

SchweisOS has a KDE live ISO profile, signed SchweisOS package foundation,
date-based release identity, canonical branding, and a documented live boot
experience. It still lacks the first installed-system workflow. Without an
installer, users can try the live system but cannot turn SchweisOS into a
daily-driver operating system through a supported path.

The installer must preserve SchweisOS's constitutional engineering rules:

- stay close to upstream Arch;
- preserve pacman's full-system update model;
- keep Arch, SchweisOS, AUR, Flatpak, and Distrobox trust domains separate;
- avoid hidden telemetry, forced accounts, and silent external submission;
- make disk-changing operations explicit;
- keep failure diagnostics available;
- keep reusable configuration package-owned rather than copied into `airootfs/`.

The project evaluated two practical first paths:

1. `archinstall`, which is available from official Arch repositories and has a
   lower packaging burden, but does not provide the polished graphical
   installation experience expected by SchweisOS's desktop audience.
2. Calamares, which is the established distribution-independent graphical
   installer and supports separately packaged distribution configuration, but
   is not available from official Arch repositories in the evaluated
   environment and therefore requires a reviewed SchweisOS repository package
   for the Calamares binary before an installer ISO can be built.

## Decision

SchweisOS Faz 1 selects Calamares as the graphical installer architecture.

The first installable MVP is:

```text
UEFI live ISO
  -> Calamares graphical flow
  -> explicit UEFI preflight
  -> Calamares partition and mount modules
  -> SchweisOS-owned pacstrap shellprocess
  -> target pacman repository include
  -> systemd-boot installation
  -> NetworkManager and SDDM enablement
  -> first user logs into Plasma
```

The source owner for SchweisOS installer configuration is the new
`schweisos-calamares-config` package. The package installs Calamares settings,
module configuration, branding descriptor, desktop launcher, target package
manifest, a pacstrap-only pacman configuration, and small audited installer
helpers.

Calamares itself is not copied into the repository and is not vendored in the
ISO profile. Because Arch official repositories do not provide the Calamares
binary in the evaluated environment, SchweisOS admits a reviewed Calamares
package source and requires a signed SchweisOS repository package before an
installer ISO can resolve `calamares` and `schweisos-calamares-config`.
Package resolution must fail closed until that dependency is available from an
approved repository source.

The live ISO must let the autologged-in `live` user start the installer and
other administrative live-session tools without knowing a root password. This
is implemented as a live-only account, sudoers, and polkit exception in
`iso/profiles/kde/airootfs/`. The exception is intentionally scoped to the
local active live session and must never be copied into the installed system.
The visible launcher is `Install SchweisOS`; the profile hides Calamares'
generic upstream `Install System` desktop entry with a live-only XDG override.

The installer must not clone the live root filesystem into the target system.
Live-root cloning would copy Archiso-only mkinitcpio configuration, live
autologin, Plymouth live fallback units, installer payload, and other
ephemeral state into the installed system and then rely on cleanup. The MVP
instead uses upstream Arch installation primitives through `pacstrap` with a
SchweisOS-owned target package manifest. This keeps the installed system
package-owned from the start and avoids live-only state migration.

## Installed-System Policy

### Firmware and Bootloader

The MVP supports UEFI only. If `/sys/firmware/efi` is absent, the installer
must fail before partitioning or package installation. BIOS support remains out
of scope until separately approved.

The default installed-system bootloader is systemd-boot. The installer mounts
the EFI system partition at `/boot`, runs `bootctl install`, writes a minimal
loader configuration, writes one `SchweisOS` loader entry, and regenerates the
target initramfs with `mkinitcpio -P`.

The loader entry binds the root filesystem by UUID and uses quiet conservative
kernel output. Installed-system Plymouth policy remains future work; the MVP
must not rely on the live ISO Plymouth theme or live diagnostic fallback units.

GRUB remains an alternative policy. The existing `schweisos-grub-theme` package
is inert groundwork. The MVP does not run `grub-install`, does not generate
`grub.cfg`, and does not activate the GRUB theme.

### Disk Layout and Filesystem

The MVP defaults to GPT, a 512 MiB EFI system partition mounted at `/boot`, and
an ext4 root filesystem.

Btrfs is exposed only as an advanced filesystem option when the live installer
environment provides `btrfs-progs`. No snapshot, rollback, compression-policy,
or subvolume promise is made in Faz 1. Snapshot architecture belongs to the
roadmap's recovery phase.

Full-disk encryption is not implemented in the MVP. It requires a separate
security, recovery, and bootloader decision before it can be advertised.

### Locale, Timezone, Keymap, User, and Hostname

Locale, timezone, keymap, user creation, user password, and hostname are
installer-owned choices. The live ISO keeps neutral `C.UTF-8` and UTC defaults
only for the ephemeral live session. The graphical installer starts from a
privacy-preserving UTC/default-locale baseline with GeoIP disabled and requires
the user to make installation choices explicitly.

The first user belongs to the `wheel` group and may use sudo after
installation. The installer must not create a forced online account, telemetry
identity, or hidden recovery account.

### Package and Repository Policy

The target package manifest is owned by `schweisos-calamares-config`. It
installs a minimal KDE Plasma desktop, core user tools, rootless container
tools already present in the live image, and the SchweisOS identity/trust
foundation packages.

The target system must install:

- `schweisos-release`;
- `schweisos-keyring`;
- `schweisos-mirrorlist`;
- `schweisos-pacman-config`;
- `schweisos-branding`.

The installer owns adding:

```ini
Include = /etc/pacman.d/schweisos.conf
```

to the target `/etc/pacman.conf`. The package `schweisos-pacman-config`
continues not to mutate `/etc/pacman.conf` from an install hook.

Package signatures and repository trust must remain required. The installer
must not use `SigLevel = Never`, `TrustAll`, unsigned production packages, fake
mirrors, or temporary keys.

## Ownership

- `docs/adr/ADR-016-installer-architecture.md` owns this decision.
- `docs/installer/` owns installer, manual installation, and recovery runbooks.
- `packages/schweisos-calamares-config/` owns reusable Calamares configuration,
  installer launcher, target package manifest, pacstrap pacman configuration,
  and installer helper scripts.
- `iso/profiles/kde/packages.x86_64` owns inclusion of Calamares and
  `schweisos-calamares-config` in the live image.
- `iso/profiles/kde/airootfs/` must not contain installer payloads.
- `schweisos-grub-theme` remains inert and future installer-owned for GRUB
  activation.
- `tools/release/` and `tools/signing/` continue to own repository and signing
  workflows; the installer does not build or sign packages.

## Alternatives Considered

### Use `archinstall` as the MVP Installer

`archinstall` is maintained in official Arch repositories and is easier to
consume without a new SchweisOS binary package. It is a strong fallback for
manual or recovery documentation, but it does not meet the professional
desktop GUI goal for users arriving from Windows or macOS.

### Clone the Live Root with Calamares `unpackfs`

This is common in some distributions, but it is the wrong first SchweisOS
contract. It would require cleanup for live autologin, Archiso initramfs
configuration, live Plymouth behavior, installer payload, and ephemeral
services. Such cleanup is fragile and easy to miss. `pacstrap` produces a
clean package-owned installed system.

### Write a Custom Installer

A custom installer could express every SchweisOS policy directly, but it would
create a large GUI, storage, bootloader, and recovery maintenance burden before
the distribution has enough users or contributors to justify it.

### Enable GRUB in the MVP

GRUB remains important as an installed-system alternative, but supporting it in
the same first MVP would expand firmware, filesystem, generated-config, theme
deployment, and rollback validation. The MVP keeps one default UEFI path.

## Consequences

Positive:

- SchweisOS gets a graphical installer architecture without forking Archiso,
  pacman, KDE, or systemd.
- Installed systems are created through signed package installation, not live
  root cloning.
- systemd-boot policy becomes a real installed-system workflow.
- The target pacman include is installer-owned, preserving package boundaries.
- The package-owned configuration can be versioned, signed, tested, removed,
  and updated independently.
- Live-session passwordless administration makes the installer usable without
  teaching users an undocumented root password, while remaining outside the
  target install path.

Negative:

- Calamares binary packaging becomes a required SchweisOS repository task
  because Arch official repositories do not provide it in the evaluated
  environment.
- Static validation cannot prove storage safety, successful boot, or graphical
  quality. ISO build, VM testing, and hardware testing remain mandatory before
  user-facing claims.
- The first MVP has no BIOS, Secure Boot, full-disk encryption, snapshots,
  rollback, or GRUB activation.
- `pacstrap` from the live environment requires the live system to have a
  complete trusted SchweisOS repository configuration and package availability.
- The live ISO has broad local administrative authority by design. This is
  acceptable only because it is ephemeral, local/active-session scoped, and not
  installed to target systems.

## Validation

The installer configuration validator must fail closed if:

- `schweisos-calamares-config` sources are missing or unsafe;
- package source checksums are skipped;
- Calamares configuration is not package-owned under `/etc/calamares`;
- the ISO profile omits required installer packages;
- target package entries are duplicated, unordered within groups, or omit
  SchweisOS identity/trust packages;
- target packages include live-only installer, Archiso, or Plymouth payloads;
- the installer does not use `pacstrap` with the packaged pacman configuration;
- the target pacman include is not installed by an installer helper;
- the default filesystem is not ext4 or the ESP policy changes without an ADR;
- systemd-boot installation, UUID-bound loader entry, or initramfs regeneration
  is missing;
- GRUB activation commands appear in the MVP path;
- secrets, private keys, or credential patterns enter installer sources.

`validate-iso-profile.sh` remains responsible for live image composition and
must continue to reject installer payloads in `airootfs/`.

## References

- [Calamares Deploy Configuration](https://github-wiki-see.page/m/calamares/calamares/wiki/Deploy-Configuration)
- [calamares(8) manual](https://manpages.debian.org/testing/calamares/calamares.8.en.html)

## Remaining Gates Before User-Facing Install Claims

This ADR and source configuration do not by themselves prove an installable
release. Before SchweisOS advertises installation support, the project must:

1. Package or admit Calamares into the signed SchweisOS repository.
2. Build and sign `schweisos-calamares-config`.
3. Build a fresh ISO from a repository state containing both packages.
4. Run static ISO, built-ISO identity, and built-ISO boot validators.
5. Boot-test the live ISO.
6. Install in a VM using the graphical installer.
7. Verify first boot, user login, pacman repository policy, systemd-boot entry,
   SDDM, NetworkManager, KDE session, and basic update behavior.
8. Repeat on at least one real UEFI machine before hardware claims.
