# DDR-001 Boot Experience

Version: 1.0
Status: Accepted
Date: 2026-07-28

Related architecture: [ADR-014 Live Boot Experience Architecture](../adr/ADR-014-live-boot-experience-architecture.md)

## Goals

The SchweisOS live boot should feel like a complete, intentional operating
system from power-on until Plasma appears.

The experience should communicate:

- fast;
- clean;
- professional;
- trustworthy;
- transparent when something goes wrong.

This decision covers the KDE live ISO boot experience only. It does not define
the installed-system bootloader, installer behavior, Secure Boot, BIOS boot, or
installed-system Plymouth policy.

## UX Philosophy

SchweisOS should reduce unnecessary cognitive load without hiding the system.

Normal desktop users should not be greeted by a long stream of kernel and
systemd messages when the boot is healthy. That output is valuable for
diagnosis, but it is not a good default first impression for a desktop-focused
distribution.

At the same time, a polished splash must never become a curtain over failure.
If boot cannot continue, the system should reveal the normal Linux diagnostic
surface automatically. Advanced users should not have to guess a secret key
sequence just to see what failed.

The design language is intentionally restrained. SchweisOS should not imitate
Windows, macOS, another Linux distribution, gaming firmware, or a phone boot
animation. The boot should be quiet, direct, and confident.

## Design Decisions

### Minimal systemd-boot Menu

The live medium keeps systemd-boot because it is the upstream-supported Archiso
UEFI path selected by the project architecture.

The menu uses:

- a short timeout;
- a clear `SchweisOS KDE Live` default entry;
- a visible `SchweisOS KDE Live (debug)` entry;
- disabled interactive command-line editing for the normal live menu;
- no graphical bootloader imitation.

systemd-boot is text-oriented. The boot menu should be clean and branded through
wording, ordering, and restraint. The graphical brand moment belongs to
Plymouth after the kernel starts.

### Branded Plymouth Splash

The normal boot path starts Plymouth with a custom SchweisOS theme. The theme:

- uses a dark neutral background;
- centers the official SchweisOS logo;
- scales the logo conservatively for different display sizes;
- uses only subtle progress-linked opacity change;
- avoids text clutter, fake progress claims, audio, and decorative effects.

The theme consumes the packaged runtime logo from
`/usr/share/schweisos/branding`. It does not copy image files into the ISO
profile. This keeps `branding/` and `schweisos-branding` as the canonical asset
owners and prevents logo drift.

### Quiet Normal Boot, Explicit Debug Boot

The default boot entry uses:

- `quiet`;
- `splash`;
- `loglevel=3`;
- `systemd.show_status=auto`;
- `vt.global_cursor_default=0`.

The debug entry intentionally does not use `quiet` or `splash`. It keeps verbose
kernel logging and visible systemd status. If a user wants the raw Linux boot
surface immediately, it is one boot-menu choice away.

### Automatic Failure Reveal

The design principle is simple: hide routine noise, never hide failure.

The live profile adds a debug fallback service that quits Plymouth and restores
the text cursor. It is pulled in by `emergency.target` and attached as
`OnFailure=` handling for the Plymouth start and quit units and SDDM.

The profile also watches Plymouth's runtime directory. The normal
`plymouth-quit.service` writes a temporary normal-quit marker before it removes
the splash. If the runtime directory changes, the PID is absent, and that marker
does not exist, SchweisOS treats it as an unexpected Plymouth exit and starts
the same diagnostic fallback.

This means:

- a healthy boot stays polished;
- emergency mode reveals diagnostics;
- Plymouth startup or shutdown failure reveals diagnostics;
- unexpected Plymouth daemon exit before the normal handoff reveals diagnostics;
- display-manager failure reveals diagnostics;
- the fallback is best-effort and non-destructive;
- the original failure remains visible through systemd and the console.

### Direct Plasma Live Session

The live ISO should arrive at Plasma without a timezone wizard, text first-run
configuration, or manual setup screen. The current SDDM live autologin remains
the correct behavior for the live medium.

Installer decisions belong to the future graphical installer, not to the live
boot path.

## Boot Flow

```text
UEFI firmware
  -> upstream Archiso systemd-boot
  -> SchweisOS KDE Live entry
  -> Linux kernel and Archiso initramfs
  -> mkinitcpio kms + plymouth hooks
  -> SchweisOS Plymouth theme
  -> Archiso mounts live root
  -> systemd starts live services
  -> SDDM autologin
  -> Plasma desktop
```

The debug path is:

```text
UEFI firmware
  -> upstream Archiso systemd-boot
  -> SchweisOS KDE Live (debug)
  -> Linux kernel and Archiso initramfs without quiet/splash
  -> visible kernel and systemd status
```

The failure path is:

```text
normal boot
  -> Plymouth starts
  -> boot cannot continue, SDDM fails, Plymouth unit fails,
     or Plymouth PID disappears before normal quit
  -> schweisos-boot-debug-fallback.service
  -> Plymouth quits
  -> normal console diagnostics remain visible
```

## Plymouth Architecture

The live profile uses upstream Plymouth's `script` theme module.

The profile provides:

- `/etc/plymouth/plymouthd.conf` selecting `Theme=schweisos`;
- `/usr/share/plymouth/themes/schweisos/schweisos.plymouth`;
- `/usr/share/plymouth/themes/schweisos/schweisos.script`;
- a mkinitcpio hook list that includes upstream `kms` and `plymouth`;
- a systemd path watcher for Plymouth runtime directory changes;
- a normal-quit marker written by `plymouth-quit.service`;
- fallback drop-ins for emergency mode, Plymouth unit failures, and SDDM
  failure.

The theme metadata points `ImageDir` at `/usr/share/schweisos/branding`, which
is installed by `schweisos-branding`. The ISO profile owns the boot theme logic;
the branding package owns the logo asset; the source artwork remains under
`branding/`.

## Non-Goals

- No ISO build as part of this decision.
- No VM or hardware boot claim without future validation.
- No installed-system bootloader implementation.
- No Secure Boot policy.
- No BIOS boot path.
- No installer screen, timezone wizard, or first-run setup.
- No KDE theme, wallpaper, SDDM theme, or desktop defaults.

## Future Review Triggers

Revisit this DDR if:

- the installed-system installer starts configuring Plymouth;
- a reusable `schweisos-boot-theme` package becomes justified;
- Secure Boot changes the boot UX;
- BIOS/GRUB support is approved;
- hardware testing shows Plymouth causes unacceptable blank-screen or GPU
  compatibility issues;
- the logo or brand policy changes.
