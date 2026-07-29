# ADR-014 Live Boot Experience Architecture

Version: 1.7

## Status

Accepted

## Date

2026-07-29

## Related ADRs and DDRs

- ADR-002 UEFI First
- ADR-008 Documentation First
- ADR-009 Distribution Identity Packages
- ADR-010 Licensing Policy
- ADR-012 ISO Build Architecture
- ADR-013 ISO Build Workflow
- ADR-015 GRUB Theme Architecture
- ADR-017 Live ISO Loopback Boot Compatibility
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
- carry the upstream Archiso-supported `/boot/grub/loopback.cfg` compatibility
  path for Ventoy-style outer GRUB launchers without enabling GRUB as the
  native live ISO bootloader;
- preserve the firmware-selected console mode, disable loader editing, and
  suppress automatic firmware and operating-system entries so the live-medium
  menu contains only the two reviewed SchweisOS paths;
- use `quiet splash loglevel=3 systemd.show_status=auto` only on the normal live
  boot entry;
- keep a separate debug entry without `quiet` or `splash`, with verbose kernel
  logging and visible systemd status;
- set `systemd.firstboot=no` on both entries, provide the upstream Archiso
  `LANG=C.UTF-8` and UTC live defaults, and reserve locale, timezone, keymap,
  account, and storage choices for the installer;
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
- use the upstream Plymouth script plugin for a temporary reference-matched
  near-black-stage boot animation: delayed logo fade-in, delayed five-dot
  circular chase loading motion sampled from the canonical logo, and
  progress/quit fade-out behavior, without adding another image source;
- replace the upstream Plymouth client commands' error-ignoring service
  prefixes in live-only drop-ins so explicit show, quit, and wait failures reach
  systemd;
- bound guarded quit and `plymouth --wait` to 20 seconds, retain the final
  splash frame during a successful SDDM handoff, preserve the normal-quit
  marker only after a successful guarded quit, and reveal diagnostics
  automatically when
  `emergency.target` is reached, SDDM fails, a Plymouth unit fails, or the
  Plymouth runtime directory changes and no live `plymouthd` remains before
  the normal handoff;
- accept a normal quit handoff only when `plymouth-quit.service` has completed
  with `Result=success` and `ExecMainStatus=0`; an inactive service with a
  failed result is treated as a failed handoff, not as success;
- run a bounded-lifetime one-second liveness watchdog until the guarded normal
  handoff service reports the explicit successful result, closing both the
  stale-PID hard-crash gap that a path event alone cannot detect and the
  early-marker handoff race.

The theme and fallback units are live-medium profile exceptions. They are not
installed-system policy and do not imply that SchweisOS has proven an
installable system, Secure Boot, BIOS support, or installed-system Plymouth
integration.

If the same boot artwork or fallback policy becomes persistent installed-system
behavior later, it must move into a separate package or installer-owned
configuration with its own ADR update.

## Ownership

- `iso/profiles/kde/efiboot/` owns live-medium systemd-boot loader inputs.
- `iso/profiles/kde/grub/loopback.cfg` owns only live-medium GRUB loopback
  compatibility for multiboot launchers; it does not own a native GRUB live
  boot path.
- `iso/profiles/kde/packages.x86_64` owns live image package composition,
  including the `plymouth` package.
- `iso/profiles/kde/airootfs/` owns the live-only Plymouth selection, theme,
  mkinitcpio hook extension, neutral first-boot defaults, guarded handoff
  helpers, path watcher, bounded-lifetime liveness watchdog, and failure
  fallback services.
- `schweisos-branding` owns only the runtime logo file consumed by the theme.
- `branding/assets/logo/schweisos.png` is the one canonical source artwork
  owner for SchweisOS boot and runtime logo consumers.
- Installed-system boot configuration remains installer-owned architecture.

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
does not change this live-medium decision. ADR-017 separately permits a small
GRUB loopback compatibility file for multiboot launchers; it is not a native
graphical GRUB live bootloader path.

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

### Keep the Earlier Breathing/Ambient Splash

The earlier SchweisOS Plymouth splash used a dark-blue ambient field, subtle
logo breathing, and an elliptical ring-style loader. Manual review found that
it still felt like separate boot stages and did not match the requested motion
language closely enough. The current theme intentionally follows a
project-provided Windows 8 boot-animation reference for timing, fade cadence,
dark-stage minimalism, and five-dot loading motion only. Microsoft branding is
not copied, no Windows artwork is used, and the near-black stage is matched to
the canonical SchweisOS logo's edge tone so the opaque source image does not
look like a separate card. This is not accepted as the final SchweisOS visual
identity; it is a temporary implementation to establish motion quality before a
fully original SchweisOS animation replaces it.

## Consequences

Positive consequences:

- The default live boot becomes quiet, branded, and modern.
- The systemd-boot menu exposes only the reviewed normal and diagnostic paths
  and avoids an extra console-mode transition.
- The Plymouth splash communicates ongoing work with restrained continuous
  five-dot circular motion and dark-stage fade timing rather than a static
  logo, a false percentage, or a visible console gap.
- The debug path remains explicit and visible in systemd-boot.
- Emergency boot, SDDM failure, Plymouth service failures, and unexpected
  Plymouth daemon exits automatically reveal diagnostics.
- The live system no longer stops at `systemd-firstboot`; successful graphical
  boot proceeds through SDDM autologin directly to Plasma.
- Ventoy-style outer GRUB launchers receive an explicit loopback handoff to the
  same Archiso kernel and initramfs paths as the native systemd-boot entries.
- Source/package version drift and missing canonical branding payloads stop the
  build before Archiso can compose a stale splash.
- Post-build validation proves that the built root and initramfs contain the
  reviewed theme, script runtime, and canonical logo before checksums are
  published.
- The implementation uses upstream Arch packages and hooks.
- The official logo has one canonical source and one runtime package owner.
- Installed-system boot policy remains unimplemented and honestly documented.

Negative consequences:

- The Archiso initramfs hook list now intentionally differs from the minimal
  Archiso baseline.
- The live profile carries a small amount of theme and fallback configuration
  until a reusable boot-theme package is justified.
- The current animation deliberately borrows motion timing from a Windows 8
  reference video as a temporary calibration target. That prevents the boot
  experience from being treated as the final original SchweisOS motion identity
  and requires a future DDR/ADR update when original animation work replaces
  it.
- The profile now has a tiny `grub/` directory. Validators must ensure it
  remains limited to `loopback.cfg` and does not become a shadow GRUB boot
  implementation.
- Static validation cannot prove visual quality; manual boot and hardware
  qualification remain required before release claims.
- The path watcher and one-second watchdog can prove that the recorded PID is
  not a live `plymouthd`, but no static validator can prove that a running
  graphics stack is producing visible pixels. The explicit debug entry and
  Escape-to-details behavior remain necessary recovery surfaces.

## Validation

The ISO profile validator must fail closed if:

- `plymouth` is missing from the live package set;
- the normal boot entry is not quiet/splash-enabled;
- the debug boot entry hides logs;
- the approved GRUB loopback file is absent, adds a full GRUB live
  configuration, or drifts from the same kernel/initramfs and normal/debug
  policy;
- either entry permits interactive `systemd-firstboot`, or the live root omits
  the Archiso `C.UTF-8` and UTC defaults;
- the mkinitcpio hook list omits `kms` or `plymouth`;
- the Plymouth theme copies branding assets instead of consuming the packaged
  branding directory;
- the theme does not use `schweisos.png`, lacks the documented delayed
  fade-in, progress fade-out, five-dot circular chase, and loading-indicator
  primitives, or introduces a second image dependency;
- Plymouth client errors remain ignored, quit waiting is unbounded, or
  emergency/SDDM/Plymouth fallback units are missing;
- the unexpected-exit path watcher, bounded-lifetime liveness watchdog,
  retained-splash normal handoff, guarded normal-quit marker, systemd
  `Result`/`ExecMainStatus` success check, or daemon-health check is missing;
- unexpected files enter the live overlay.

The build environment gate must additionally reject SchweisOS package/source
version drift in every mode and reject a resolved branding package whose
canonical logo path or hash differs from repository source. After `mkarchiso`,
the built-ISO boot validator must inspect the SquashFS and initramfs before
checksums are published. These static gates do not replace a VM or hardware
boot test.
