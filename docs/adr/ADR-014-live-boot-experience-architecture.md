# ADR-014 Live Boot Experience Architecture

Version: 1.2

## Status

Accepted

## Date

2026-07-28

## Related ADRs and DDRs

- ADR-002 UEFI First
- ADR-008 Documentation First
- ADR-009 Distribution Identity Packages
- ADR-010 Licensing Policy
- ADR-012 ISO Build Architecture
- ADR-013 ISO Build Workflow
- ADR-015 GRUB Theme Architecture
- DDR-001 Boot Experience

## Context

The initial KDE Archiso profile intentionally used a minimal upstream-compatible
boot path. It selected Archiso's supported `uefi.systemd-boot` mode, kept a
single systemd-boot entry, used the Archiso initramfs hook chain, and booted the
live session through SDDM autologin. That was a good pre-alpha baseline, but it
left the first user-visible experience as an unstyled boot menu followed by
verbose boot logs.

SchweisOS now needs a polished live-medium boot experience without weakening the
project's architectural boundaries:

- stay on upstream Archiso and upstream systemd-boot;
- avoid custom boot frameworks and bootloader forks;
- avoid copying canonical logo assets into the ISO profile;
- avoid making `schweisos-branding` own desktop or boot behavior;
- keep logs and a terminal-oriented diagnosis path available when boot fails;
- avoid implementing installed-system boot behavior before installer
  architecture exists.

## Decision

The KDE Archiso profile owns the SchweisOS live-medium boot experience.

The profile will:

- keep Archiso's upstream `uefi.systemd-boot` boot mode;
- keep systemd-boot as a minimal text menu with a short timeout, a polished
  `SchweisOS Live` default entry, and a visible `SchweisOS Live (Debug)` entry;
- preserve the firmware-selected console mode, disable loader editing, and
  suppress automatic firmware and operating-system entries so the live-medium
  menu contains only the two reviewed SchweisOS paths;
- use `quiet splash loglevel=3 systemd.show_status=auto` only on the normal live
  boot entry;
- keep a separate debug entry without `quiet` or `splash`, with verbose kernel
  logging and visible systemd status;
- include the upstream Arch `plymouth` package in the live package set;
- add upstream mkinitcpio `kms` and `plymouth` hooks to the live initramfs hook
  chain;
- provide a profile-owned SchweisOS Plymouth theme under
  `/usr/share/plymouth/themes/schweisos`;
- configure Plymouth through `/etc/plymouth/plymouthd.conf`;
- have the Plymouth theme consume the packaged runtime logo from
  `/usr/share/schweisos/branding/schweisos.png`, which is provided by
  `schweisos-branding` from the single canonical source at
  `branding/assets/logo/schweisos.png`;
- use the upstream Plymouth script plugin for a bounded fade-in, subtle
  pre-rendered scale/opacity breathing cycle, and a rotating loading-dot trail
  sampled from the canonical logo, without adding another image source;
- reveal diagnostics automatically by quitting Plymouth when `emergency.target`
  is reached, SDDM fails, Plymouth start/quit units fail, or the Plymouth
  runtime directory changes and the PID is absent before the normal quit
  handoff marker is written.

The theme and fallback units are live-medium profile exceptions. They are not
installed-system policy and do not imply that SchweisOS has implemented an
installer bootloader workflow, Secure Boot, BIOS support, or installed-system
Plymouth integration.

If the same boot artwork or fallback policy becomes persistent installed-system
behavior later, it must move into a separate package or installer-owned
configuration with its own ADR update.

## Ownership

- `iso/profiles/kde/efiboot/` owns live-medium systemd-boot loader inputs.
- `iso/profiles/kde/packages.x86_64` owns live image package composition,
  including the `plymouth` package.
- `iso/profiles/kde/airootfs/` owns the live-only Plymouth selection, theme,
  mkinitcpio hook extension, unexpected-exit watcher, and failure fallback
  services.
- `schweisos-branding` owns only the runtime logo file consumed by the theme.
- `branding/assets/logo/schweisos.png` is the one canonical source artwork
  owner for SchweisOS boot and runtime logo consumers.
- Installed-system boot configuration remains future installer architecture.

## Alternatives Considered

### Keep Verbose Boot Logs

This preserved maximum transparency, but it made the first boot feel unfinished
and overly technical for desktop users. It also failed to use the existing brand
identity at the moment users first meet the system.

### Hide Logs Permanently

This would improve polish but violate SchweisOS's transparency and recovery
rules. Users must be able to see failures without needing hidden knowledge.

### Graphical Bootloader Theme

systemd-boot is intentionally simple and text-oriented. Adding a graphical
bootloader layer would either require unsupported expectations, a different
bootloader, or bootloader artwork outside the current UEFI-first Archiso
contract. The live medium instead keeps systemd-boot minimal and lets Plymouth
own graphical presentation after the kernel starts. ADR-015 separately permits
an inert packaged theme for the future installed-system GRUB alternative; it
does not change this live-medium decision.

### Put Plymouth in `schweisos-branding`

That would make a minimal asset package own boot behavior. It would contradict
the documented branding boundary and make future theme behavior harder to
review, package, remove, or replace cleanly.

### Create a New Plymouth Theme Package Now

A package is the right owner if Plymouth becomes reusable installed-system
behavior. For the current live-only Plymouth requirement, a new package would
expand signing, repository, and release maintenance without adding a reusable
contract yet. The profile-owned implementation is bounded and can be migrated
later. The separately approved GRUB package owns a different, installed-system
bootloader concern.

## Consequences

Positive consequences:

- The default live boot becomes quiet, branded, and modern.
- The systemd-boot menu exposes only the reviewed normal and diagnostic paths
  and avoids an extra console-mode transition.
- The Plymouth splash communicates ongoing work with restrained continuous
  motion rather than a static logo or a false percentage.
- The debug path remains explicit and visible in systemd-boot.
- Emergency boot, SDDM failure, Plymouth service failures, and unexpected
  Plymouth daemon exits automatically reveal diagnostics.
- The implementation uses upstream Arch packages and hooks.
- The official logo has one canonical source and one runtime package owner.
- Installed-system boot policy remains unimplemented and honestly documented.

Negative consequences:

- The Archiso initramfs hook list now intentionally differs from the minimal
  Archiso baseline.
- The live profile carries a small amount of theme and fallback configuration
  until a reusable boot-theme package is justified.
- Static validation cannot prove visual quality; manual boot and hardware
  qualification remain required before release claims.

## Validation

The ISO profile validator must fail closed if:

- `plymouth` is missing from the live package set;
- the normal boot entry is not quiet/splash-enabled;
- the debug boot entry hides logs;
- the mkinitcpio hook list omits `kms` or `plymouth`;
- the Plymouth theme copies branding assets instead of consuming the packaged
  branding directory;
- the theme does not use `schweisos.png`, lacks the documented fade/pulse and
  rotating indicator primitives, or introduces a second image dependency;
- emergency or Plymouth failure fallback units are missing;
- the unexpected-exit watcher or normal-quit marker is missing;
- unexpected files enter the live overlay.

The change must not run `mkarchiso`, build an ISO, generate release artifacts,
or claim boot validation without an actual boot test.
