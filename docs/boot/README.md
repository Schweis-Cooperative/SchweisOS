# SchweisOS Boot Experience

Version: 0.3
Status: Partial implementation
Date: 2026-07-28

SchweisOS treats the live-medium boot path and the installed-system bootloader
as separate systems.

## Current Live-Medium Path

The KDE live ISO uses upstream Archiso `uefi.systemd-boot`.

```text
UEFI
  -> systemd-boot
  -> Linux and Archiso initramfs
  -> SchweisOS Plymouth splash
  -> SDDM live autologin
  -> Plasma
```

The normal `SchweisOS Live` entry is quiet and splash-enabled. The visible
`SchweisOS Live (Debug)` entry exposes kernel and systemd output immediately.
Both entries disable interactive `systemd-firstboot`; the live root provides
the upstream Archiso `C.UTF-8` and UTC defaults. A healthy boot therefore
continues through SDDM autologin directly to Plasma without a timezone,
keymap, or root-password wizard.

Emergency mode, SDDM failure, a propagated Plymouth service failure, a bounded
quit-wait timeout, or a detected unexpected Plymouth daemon exit triggers the
live-only fallback service, which quits the splash and restores console
diagnostics. A runtime-directory path watcher provides the fast path; a
one-second watchdog runs only until successful Plymouth handoff and detects
hard crashes that leave a stale PID file without a path event.

The systemd-boot menu is intentionally text-oriented. Its polish comes from
two concise entries, a short timeout, stable console mode, and removal of
unrelated automatic entries. It does not attempt to imitate a graphical
bootloader.

## Plymouth

The live profile owns the Plymouth behavior. It consumes the runtime logo from
`/usr/share/schweisos/branding/schweisos.png`, provided by
`schweisos-branding` from the canonical source
`branding/assets/logo/schweisos.png`.

The script plugin provides a bounded fade/rise intro, a subtle pre-rendered
breathing cycle, and a rotating loading trail sampled from the same logo. It
does not add a second logo or spinner asset.

Build validation is deliberately end-to-end. Before `mkarchiso`, the selected
signed `schweisos-branding` package must match the source version and canonical
logo hash. After construction, the built root and initramfs must contain that
logo plus the reviewed Plymouth theme and script before checksums are
published. This is the contract that prevents a current theme from being paired
with an old branding package.

## Installed-System Direction

The accepted installed-system default is systemd-boot on UEFI. GRUB is an
alternative that a future installer may offer.

`schweisos-grub-theme` now provides inert, reusable GRUB theme groundwork. It
does not install GRUB, activate itself, edit `/etc/default/grub`, generate
`grub.cfg`, add GRUB to the live ISO, or claim BIOS support. The future
installer owns those operations and must ensure that the resolved theme is
available on the bootloader-readable filesystem.

The intended visual journey is:

```text
UEFI
  -> systemd-boot or GRUB
  -> Plymouth
  -> SDDM
  -> Plasma
```

Only the live `systemd-boot -> Plymouth -> SDDM -> Plasma` portion is currently
implemented. The GRUB theme is packaged groundwork; installer activation,
installed-system Plymouth, SDDM branding, and VM/hardware qualification remain
future work.

## Canonical Decisions

- [ADR-002 UEFI First](../adr/ADR-002-uefi-first.md)
- [ADR-014 Live Boot Experience Architecture](../adr/ADR-014-live-boot-experience-architecture.md)
- [ADR-015 GRUB Theme Architecture](../adr/ADR-015-grub-theme-architecture.md)
- [DDR-001 Boot Experience](../ddr/DDR-001-boot-experience.md)
