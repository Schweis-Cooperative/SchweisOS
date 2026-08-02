# ADR-016 Installer Architecture

Version: 0.5

## Status

Accepted for Faz 1 source implementation

## Date

2026-08-02

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
- ADR-018 Installer Payload and Selection Architecture
- DDR-001 Boot Experience
- DDR-002 Installer Experience

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
module configuration, branding descriptor, slideshow resource, desktop
launcher, target package manifest, a pacstrap-only pacman configuration, and
small audited installer helpers.

Calamares itself is not copied into the repository and is not vendored in the
ISO profile. Because Arch official repositories do not provide the Calamares
binary in the evaluated environment, SchweisOS admits a reviewed Calamares
package source and requires a signed SchweisOS repository package before an
installer ISO can resolve `calamares` and `schweisos-calamares-config`.
Package resolution must fail closed until that dependency is available from an
approved repository source.

The SchweisOS Calamares binary package carries one narrow downstream patch for
live-media safety. Upstream Calamares' `WritableOnly` device filter removes the
live root device and ISO9660 media, but a Ventoy/file-based boot presents the
active USB storage as a writable exFAT disk while the live root is mounted from
an ISO file or device-mapper mapping. That allows the booted USB itself to
appear as an installation target and fail destructively during partition-table
creation. SchweisOS therefore filters the parent disk of the active Archiso
media from the Calamares partition device model when the SchweisOS live marker
is present. The filter derives the media from `img_dev`, `archisodevice`, and
`/run/archiso/bootmnt` runtime evidence; it does not hide ordinary removable
target disks that are not the current boot medium.

The live ISO must let the autologged-in `live` user start the installer and
other administrative live-session tools without knowing a root password. This
is implemented as a live-only account, sudoers, and polkit exception in
`iso/profiles/kde/airootfs/`. The exception is intentionally scoped to the
local active live session and must never be copied into the installed system.

The visible launcher is `Install SchweisOS`. The SchweisOS Calamares binary
package omits upstream's generic `Install System` desktop entry, so launcher
ownership is resolved at package construction rather than with a profile
overlay or desktop-menu precedence assumption. `schweisos-calamares-config`
owns the public launcher, a hidden first-session XDG autostart entry, an
exact-path Polkit action, and the bounded privilege/display helper.

Installer presentation remains package-owned rather than profile-owned. The
SchweisOS Calamares branding descriptor uses the canonical runtime logo as a
compact `productBanner`, keeps product icon/sidebar logo references on the same
canonical asset, deliberately omits the oversized `productWelcome` image, and
ships a text-first QML slideshow with the SchweisOS welcome message and current
contributors list.

Calamares 3.4 still runs its UI as root. The packaged helper accepts no
arguments, removes unsafe loader/plugin environment variables, and forces the
Qt `xcb` backend. Polkit's `allow_gui` annotation carries the live session's
X11 authorization to that exact helper so it can use packaged XWayland under a
native Plasma Wayland session. The public launcher adds a per-session
single-instance lock, UEFI/display/component preflight, a private local launch
log, and a KDE error dialog for non-zero startup results.

The installer autostarts three seconds after the first live Plasma session.
An atomic state marker in the ephemeral live home prevents any later automatic
reopen during the same medium boot. Closing the installer is respected; the
same branded menu entry remains available for manual reopening. The complete
interaction contract is owned by DDR-002.

The public launcher and autostart helper use one package-owned live-session
predicate. A valid session requires all of the following:

- the current account is the profile-owned `live` user;
- `/usr/lib/schweisos-live/session` is a regular, non-symlink file containing
  exactly `SCHWEISOS_LIVE_SESSION=1`;
- `/run/archiso/airootfs` is a mountpoint;
- `/proc/cmdline` contains the exact `archisobasedir=schweis` token.

The predicate must not depend on `/run/archiso/bootmnt`. Upstream Archiso's
`copytoram=auto` path deliberately unmounts and removes that transient path
after it has established the live root. Treating its absence as failure rejects
a healthy copied-to-RAM live session, including the observed Ventoy GRUB2
case. The marker is profile-owned because it is live-only; the reusable
predicate remains package-owned and combines the marker with runtime evidence
so copying the marker alone cannot authorize an installed system.

The original Faz 1 payload decision used `pacstrap` and prohibited live-root
deployment. ADR-018 supersedes that payload decision after offline installation
and deterministic package selection became accepted Faz 1 requirements. The
Calamares choice, launcher, privilege bridge, storage safety, UEFI,
systemd-boot, trust, and ownership decisions in this ADR remain active.

The Calamares welcome page must not make internet access a required minimum
condition. ADR-018 owns the accepted offline payload and package-selection
architecture.

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

The active live boot medium is not a supported installation target. A user may
install from one USB drive to another removable drive, but not onto the exact
USB or file-backed medium that is supplying the running live system. That disk
must be absent from Calamares' target selection rather than left to fail later
in `sfdisk`.

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
  Calamares branding and slideshow resources, the single visible installer
  launcher, live-session autostart, exact-path privilege bridge, target package
  and selection manifests, and installer helper scripts.
- `packages/calamares/` owns the reviewed upstream binary package, omission of
  its generic launcher, and the narrow live-media target filter patch; it does
  not own SchweisOS desktop presentation.
- `iso/profiles/kde/packages.x86_64` owns inclusion of Calamares and
  `schweisos-calamares-config` in the live image.
- `iso/profiles/kde/airootfs/` owns only live account authorization and the
  inert live-session marker; it must not contain installer payloads or launcher
  masks.
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

This alternative was originally rejected. ADR-018 records why the accepted
offline and selection requirements changed the tradeoff and defines the
bounded reconciliation contract that makes this path reviewable.

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
- Installed systems preserve signed package state and are reconciled according
  to ADR-018's offline payload contract.
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
- The live-media target filter is downstream maintenance burden. It is accepted
  only because the unfiltered upstream device model exposes the actively
  booted Ventoy/file-based USB as a writable installation target.
- Static validation cannot prove storage safety, successful boot, or graphical
  quality. ISO build, VM testing, and hardware testing remain mandatory before
  user-facing claims.
- The first MVP has no BIOS, Secure Boot, full-disk encryption, snapshots,
  rollback, or GRUB activation.
- The offline payload increases ISO size and requires strict live-state cleanup
  under ADR-018.
- The live ISO has broad local administrative authority by design. This is
  acceptable only because it is ephemeral, local/active-session scoped, and not
  installed to target systems.

## Validation

The installer configuration validator must fail closed if:

- `schweisos-calamares-config` sources are missing or unsafe;
- the Calamares binary package retains its generic desktop launcher;
- the Calamares binary package omits or stops applying the reviewed
  SchweisOS live-media target filter;
- the branded launcher, once-only autostart, exact-path Polkit action,
  XWayland bridge, single-instance lock, local log, or visible error path is
  missing;
- the launcher and autostart do not share the same live-session predicate;
- the live predicate omits the live user, exact profile marker, persistent
  Archiso `airootfs` mountpoint, or SchweisOS `archisobasedir` evidence;
- any installer launch path depends on transient `/run/archiso/bootmnt`;
- Calamares branding omits the required slideshow contract, uses invalid
  schema keys, uses a non-canonical logo path, displays the large
  `productWelcome` welcome image, or omits the package-owned welcome message
  and contributors list;
- package source checksums are skipped;
- Calamares configuration is not package-owned under `/etc/calamares`;
- the ISO profile omits required installer packages;
- target package entries are duplicated, unordered within groups, or omit
  SchweisOS identity/trust packages;
- target packages include live-only installer, Archiso, or Plymouth payloads;
- the installer payload or selection contract diverges from ADR-018;
- the Calamares welcome page blocks installation on a generic internet probe;
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

Payload and package-selection details are governed by
[ADR-018](ADR-018-installer-payload-and-selection-architecture.md).
