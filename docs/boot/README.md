# SchweisOS Boot Experience

Version: 0.1
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
Emergency mode, SDDM failure, Plymouth service failure, or an unexpected
Plymouth daemon exit triggers the live-only fallback service, which quits the
splash and restores console diagnostics.

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
installed-system Plymouth, SDDM branding, and cross-stage runtime validation
remain future work.

## Canonical Decisions

- [ADR-002 UEFI First](../adr/ADR-002-uefi-first.md)
- [ADR-014 Live Boot Experience Architecture](../adr/ADR-014-live-boot-experience-architecture.md)
- [ADR-015 GRUB Theme Architecture](../adr/ADR-015-grub-theme-architecture.md)
- [DDR-001 Boot Experience](../ddr/DDR-001-boot-experience.md)
