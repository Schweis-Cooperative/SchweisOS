# schweisos-grub-theme

Version: 0.1
Status: Groundwork
Date: 2026-07-28

`schweisos-grub-theme` provides the reusable SchweisOS graphical theme payload
for GRUB. It is intended for the future installed-system GRUB alternative. It
is not part of the current KDE live ISO and does not change Archiso's selected
`uefi.systemd-boot` mode.

## Ownership

The package owns:

- `/usr/share/grub/themes/schweisos/theme.txt`;
- the small nine-slice selection-highlight images used by that theme;
- a relative runtime symlink named `schweisos.png`.

The symlink resolves to
`/usr/share/schweisos/branding/schweisos.png`, which remains owned by
`schweisos-branding` and is packaged from the single canonical source
`branding/assets/logo/schweisos.png`. This package contains no second logo
payload.

The package does not:

- install GRUB to a disk;
- edit `/etc/default/grub`;
- run `grub-mkconfig`;
- select a default bootloader;
- create menu entries;
- implement BIOS support;
- configure Secure Boot;
- configure Plymouth, SDDM, or Plasma.

Those actions require installer context and remain future installer
architecture.

## Activation Contract

Installing this package alone is deliberately inert. A future installer that
offers GRUB must:

1. install upstream Arch `grub`, `schweisos-branding`, and this package;
2. verify that the canonical logo symlink resolves;
3. ensure the complete resolved theme is readable by GRUB, including when
   `/boot` is a separate filesystem;
4. set `GRUB_THEME` to the deployed `theme.txt`;
5. generate `grub.cfg` through the normal upstream Arch workflow;
6. verify the generated configuration and test the result on the selected
   firmware path.

If the installer copies the theme into a bootloader-owned filesystem, it must
dereference the logo symlink during deployment. That creates a generated
installed-system copy, not a second repository source. The package and
`branding/assets/logo/schweisos.png` remain the canonical update inputs.

Rollback is to remove the `GRUB_THEME` selection, regenerate `grub.cfg`, and
keep upstream GRUB's default graphical or text menu. Removing this package must
never remove GRUB itself or change the installed bootloader.

Architecture: [ADR-015 GRUB Theme Architecture](../../docs/adr/ADR-015-grub-theme-architecture.md)
