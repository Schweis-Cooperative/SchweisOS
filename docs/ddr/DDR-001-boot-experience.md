# DDR-001 Boot Experience

Version: 1.9
Status: Accepted
Date: 2026-07-30

Related architecture:
[ADR-014 Live Boot Experience Architecture](../adr/ADR-014-live-boot-experience-architecture.md)
[ADR-015 GRUB Theme Architecture](../adr/ADR-015-grub-theme-architecture.md)
and [ADR-017 Live ISO Loopback Boot Compatibility](../adr/ADR-017-live-iso-loopback-boot-compatibility.md)

## Goals

The SchweisOS live boot should feel like a complete, intentional operating
system from power-on until Plasma appears.

The experience should communicate:

- fast;
- clean;
- professional;
- trustworthy;
- transparent when something goes wrong.

The repository-source portion of this decision covers the configured KDE live
ISO boot experience. It also defines the visual direction of the packaged GRUB
theme, but it does not implement installed-system bootloader activation,
installer behavior, Secure Boot, BIOS boot, or installed-system Plymouth
policy.

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

The design language is intentionally restrained. SchweisOS should not copy
another operating system's branding, layout, or identity. For the current
temporary Plymouth iteration only, the project is using a Windows 8 boot
animation video as a motion and timing reference: dark-stage pacing, fade
cadence, continuous five-dot loader motion, and handoff smoothness. Microsoft
artwork is not used, SchweisOS branding remains canonical, and a later DDR/ADR
update should replace this calibration target with a fully original SchweisOS
motion identity. The boot should be quiet, direct, and confident.

## Design Decisions

### Minimal systemd-boot Menu

The live medium keeps systemd-boot because it is the upstream-supported Archiso
UEFI path selected by the project architecture.

The menu uses:

- a three-second timeout;
- a clear `SchweisOS Live` default entry;
- a visible `SchweisOS Live (Debug)` entry;
- the firmware-selected console mode to avoid a visible resolution switch;
- disabled interactive command-line editing;
- disabled automatic operating-system and firmware entries so the menu remains
  limited to the reviewed normal and diagnostic paths;
- no graphical bootloader imitation.

systemd-boot is text-oriented. The boot menu should be clean and branded through
wording, ordering, and restraint. The graphical brand moment belongs to
Plymouth after the kernel starts.

### Graphical GRUB Alternative

GRUB may provide a graphical menu when a later GRUB-capable installer path
offers it as the installed-system alternative. Its SchweisOS theme uses:

- the same dark blue visual field as Plymouth;
- a centered official logo with ample negative space;
- neutral modern typography available in upstream GRUB;
- a rounded, translucent selection highlight with a restrained cyan edge;
- a thin timeout indicator;
- one muted keyboard-guidance line;
- no imitation of another operating system.

The theme package is intentionally inert and is not part of the live ISO. It
does not install or activate GRUB. This preserves a coherent visual direction
without claiming an installed boot workflow that does not exist.

### GRUB Loopback Compatibility

Some multiboot tools can launch an ISO through an outer GRUB loopback chain
instead of using native Archiso search. SchweisOS supports that
bootloader-visible handoff with a minimal `loopback.cfg` that
mirrors the normal and debug live entries and gives the Archiso initramfs the
ISO-file location through `img_dev` and `img_loop`.
The live initramfs includes Archiso's `archiso_loop_mnt` hook so those
parameters are consumed after the kernel starts instead of falling back to
native UUID-marker device discovery. For multiboot command lines that instead
carry `archisosearchuuid` without `img_dev/img_loop`, the initramfs also
includes SchweisOS' `schweisos_iso_file_fallback` hook. It searches only
removable media for an ISO carrying the requested Archiso UUID marker and then
hands the discovered loop device back to upstream Archiso. It does not perform
unconditional loop-module loading before `losetup`, because hardware testing
exposed repeated `Invalid ELF header magic` diagnostics immediately after the
fallback hook started.

This is not a visual GRUB boot experience and it is not the future installed
GRUB alternative. It exists only to make the same live kernel and initramfs
reachable from common USB multiboot launchers without adding clutter or a
second native bootloader personality.

Ventoy's “Normal Mode” and “GRUB2 Mode” labels do not by themselves prove
which contract reached the kernel. `/proc/cmdline` is canonical runtime
evidence: `img_dev` plus `img_loop` identifies the outer-GRUB ISO-file
handoff, while `archisosearchuuid` without them identifies the native search
and fallback path. Before either path is tested, the copied ISO must be the
only SchweisOS ISO on the medium and must match the validated source by
basename, size, SHA256, and byte comparison. All live entries request
post-build and media-copy integrity verification so a bad ISO or copied media
is reported as evidence before the artifact is treated as bootable. Default
boot entries keep Archiso's `checksum=y` self-test disabled because Ventoy
hardware testing showed that boot-time self-test can stall file-based
multiboot paths before the desktop.

### Branded Plymouth Splash

The normal boot path starts Plymouth with a custom SchweisOS theme. The theme:

- uses a near-black stage matched to the canonical logo edge tone so the
  opaque source image does not read as a separate card;
- centers the official SchweisOS logo;
- scales the logo conservatively for different display sizes;
- holds a short dark lead, then fades the logo in without moving or pulsing it;
- starts the loading indicator after the logo, matching the reference cadence;
- shows five small dots chasing each other around a compact circular path below
  the logo to communicate continuous activity without claiming false percentage
  accuracy;
- fades the logo and indicator near the end of Plymouth's reported boot
  progress and clears the final retained frame on quit;
- avoids text clutter, fake progress claims, audio, and decorative effects.

The theme consumes `/usr/share/schweisos/branding/schweisos.png`, packaged from
the single canonical source `branding/assets/logo/schweisos.png`. It does not
copy an image into the ISO profile. The loading dots are sampled at runtime from
the white eye in that same image, so animation introduces no second artwork
source and cannot drift to another logo.

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

Both entries use `systemd.firstboot=no`. The live root supplies the same neutral
`LANG=C.UTF-8` and UTC defaults as upstream Archiso. This prevents the generic
systemd locale, keymap, timezone, and root-password questionnaire from blocking
the graphical live session; those choices belong to the Calamares installer
flow. Boot-time `checksum=y` is not enabled by default; SchweisOS instead
requires built-ISO and copied-media validation to verify `airootfs.sfs` before
the artifact is accepted. This keeps the polished boot path compatible with
file-based multiboot launchers while preserving explicit integrity evidence.

### Automatic Failure Reveal

The design principle is simple: hide routine noise, never hide failure.

The live profile adds a debug fallback service that quits Plymouth and restores
the text cursor. It is pulled in by `emergency.target` and attached as
`OnFailure=` handling for the Plymouth start, quit, bounded quit-wait, and SDDM
units.

Upstream Plymouth service files intentionally prefix their client commands with
`-`, which makes client errors non-fatal to systemd. Live-only drop-ins replace
those commands without the error-ignoring prefix. Both guarded quit and
quit-wait have an explicit 20-second limit instead of relying on an unlimited
or changing upstream timeout. The guarded normal quit uses Plymouth's upstream
`--retain-splash` option so the final branded frame remains visible until the
display manager takes over, avoiding a healthy-boot console flash.

The profile watches Plymouth's runtime directory and runs a one-second liveness
watchdog until the normal handoff. A guarded quit helper writes a temporary
normal-handoff marker before requesting quit, removes it on failure or
interruption, and retains it only after success. A directory change provides
the fast detection path. The watchdog independently invokes the same health
helper, which verifies the recorded PID and process name; this also detects a
hard crash that leaves a stale PID file without changing directory metadata.
When no live `plymouthd` remains, SchweisOS starts the same diagnostic fallback.
The watchdog exits only when the marker exists and `plymouth-quit.service` has
completed with `Result=success` and `ExecMainStatus=0`; a merely inactive
oneshot service is not treated as success unless systemd also reports a
successful result. An in-progress or failed quit cannot retire it early. It
does not poll during the live desktop session. Expected diagnostic-fallback
requests exit cleanly after the request so the console does not show a
misleading watchdog unit failure; unexpected health-helper or systemd
state-query errors still propagate to systemd.

`tests/test-plymouth-watchdog.sh` exercises that state machine with disposable
command stubs while retaining the real helper's control flow. It covers a
completed handoff, an activating handoff that later succeeds, a failed
handoff, an absent daemon, a fallback-start error that must not mark the
watchdog failed, a live daemon that later stops, a health-helper error, and a
systemd state-query error. The last two errors propagate to systemd instead of
becoming false success.

Once composed into an image and runtime-qualified, the configured contract is
intended to mean:

- a healthy boot remains on the polished path;
- emergency mode is configured to reveal diagnostics;
- Plymouth startup or shutdown failure is configured to reveal diagnostics;
- unexpected Plymouth daemon exit before the normal handoff is configured to
  reveal diagnostics;
- display-manager failure is configured to reveal diagnostics;
- the fallback is best-effort and non-destructive;
- the original failure remains visible through systemd and the console.

A running Plymouth daemon can still have a renderer or hardware-specific
failure that is not observable through unit state alone. The build gate prevents
known missing-theme and missing-image failures, while the visible debug entry,
automatic systemd failure status, and Plymouth Escape-to-details behavior keep
manual diagnosis available.

### Direct Plasma Live Session

The live profile is configured to reach Plasma without a timezone wizard, text
first-run configuration, root-password prompt, or manual setup screen. The
profile's neutral locale/timezone files and `systemd.firstboot=no` own the
pre-SDDM contract; SDDM autologin owns the configured final handoff to the
`live` Plasma session.

Installer decisions belong to the graphical installer, not to the live boot
path.

## Configured Boot Flow

The following diagrams describe the reviewed source contract. They are not
evidence that the current payload has completed a VM or hardware boot.

```text
UEFI firmware
  -> upstream Archiso systemd-boot
  -> SchweisOS Live entry
  -> Linux kernel and Archiso initramfs
  -> mkinitcpio kms + plymouth + archiso_loop_mnt + ISO-file fallback contract
  -> Archiso verifies airootfs.sfs checksum
  -> SchweisOS Plymouth theme
  -> Archiso mounts live root
  -> neutral C.UTF-8/UTC live defaults; interactive systemd-firstboot disabled
  -> systemd starts live services
  -> SDDM autologin
  -> Plasma desktop
```

The debug path is:

```text
UEFI firmware
  -> upstream Archiso systemd-boot
  -> SchweisOS Live (Debug)
  -> Linux kernel and Archiso initramfs without quiet/splash
  -> visible kernel and systemd status
```

The generic outer-GRUB loopback path is:

```text
UEFI firmware
  -> an outer GRUB launcher that consumes Archiso loopback.cfg
  -> /boot/grub/loopback.cfg inside the SchweisOS ISO
  -> SchweisOS Live or SchweisOS Live (Debug)
  -> /schweis/boot/x86_64/vmlinuz-linux
  -> /schweis/boot/x86_64/initramfs-linux.img
  -> archiso_loop_mnt turns img_dev/img_loop into the ISO loop device
  -> Archiso verifies airootfs.sfs checksum
  -> Archiso mounts the ISO through img_dev/img_loop
  -> the same Plymouth, SDDM, and Plasma path as native live boot
```

The native Archiso search fallback path is:

```text
UEFI firmware
  -> a file-based multiboot launcher
  -> kernel command line with archisosearchuuid and no img_dev/img_loop
  -> /schweis/boot/x86_64/vmlinuz-linux
  -> /schweis/boot/x86_64/initramfs-linux.img
  -> archiso_loop_mnt runs but remains passive because img_dev/img_loop are absent
  -> schweisos_iso_file_fallback searches removable media for the ISO marker
  -> SchweisOS creates a read-only loop device for the matching ISO
  -> Archiso mounts that loop device through its normal mount handler
  -> the same Plymouth, SDDM, and Plasma path as native live boot
```

The future installed GRUB alternative is designed as:

```text
UEFI
  -> upstream GRUB with packaged SchweisOS theme
  -> installed Linux and initramfs
  -> future installed-system Plymouth policy
  -> SDDM
  -> Plasma
```

Only the theme payload exists today. Installer activation and the remaining
installed-system stages are not implemented.

The configured failure path is:

```text
normal boot
  -> Plymouth starts
  -> boot cannot continue, SDDM fails, Plymouth unit fails,
     quit waiting reaches its bound, or no live Plymouth daemon remains
     before normal quit
  -> schweisos-boot-debug-fallback.service
  -> Plymouth quits
  -> normal console diagnostics remain visible
```

## Plymouth Architecture

The live profile uses upstream Plymouth's `script` theme module.

The script maintains three bounded animation layers:

1. A near-black stage holds briefly before the logo appears, matching the
   temporary reference pacing, hiding the opaque logo image edge, and avoiding
   visible console artifacts during healthy boot.
2. A responsive, canonical-logo sprite fades in after the dark lead and stays
   still. The logo does not breathe, pulse, rotate, or scale during normal
   animation.
3. Five loading sprites, all sampled from the canonical logo, chase each other
   around a compact circular path below the logo. The leading dot is larger and
   brighter, with smaller trailing dots producing continuous motion without an
   additional spinner image or font dependency.

Plymouth's progress callback is used only to fade the logo and activity
indicator during the final portion of the handoff. The animation never displays
or invents a percentage.

The profile provides:

- `/etc/plymouth/plymouthd.conf` selecting `Theme=schweisos`;
- `/usr/share/plymouth/themes/schweisos/schweisos.plymouth`;
- `/usr/share/plymouth/themes/schweisos/schweisos.script`;
- a mkinitcpio hook list that includes upstream `kms`, `plymouth`, and
  `archiso_loop_mnt` plus SchweisOS' `schweisos_iso_file_fallback`;
- a systemd path watcher for Plymouth runtime directory changes and a
  one-second, boot-bounded liveness watchdog;
- a guarded normal-quit helper, daemon-health helper, and watchdog helper under
  `/usr/lib/schweisos-live/`;
- fallback drop-ins for emergency mode, Plymouth unit failures, and SDDM
  failure.

The theme metadata points `ImageDir` at `/usr/share/schweisos/branding`, which
is installed by `schweisos-branding`. The ISO profile owns the boot theme logic;
the branding package owns the runtime path; the source artwork has exactly one
canonical path: `branding/assets/logo/schweisos.png`.

The build environment requires the resolved signed branding package to match
the source PKGBUILD version and canonical logo hash. After image construction,
`validate-built-iso-boot.sh` compares the built root and initramfs theme, script,
logo, live defaults, and systemd units with their canonical sources. This
prevents a source-only update from producing a gradient-only splash from a stale
repository package.

## Evidence Status

There is no current successful ISO evidence for the newly changed first-boot
payload, Plymouth watchdog, built-boot validator, or exact v2 manifest
contract. The production build host must create that evidence later by running
the complete build pipeline. The older local ISO and its failed or legacy
manifests do not validate these changes. Static profile checks and the
disposable watchdog behavior test prove source contracts, not visible pixels,
SDDM success, Plasma arrival, or hardware compatibility.

## Non-Goals

- No ISO build as part of this decision.
- No VM or hardware boot claim without future validation.
- No installed-system bootloader runtime proof as part of this boot-experience
  decision.
- No automatic GRUB activation or native GRUB live-medium path. The only live
  GRUB source is the ADR-017 loopback compatibility file.
- No Secure Boot policy.
- No BIOS boot path.
- No live-session installer screen, timezone wizard, or first-run setup.
- No KDE theme, wallpaper, SDDM theme, or desktop defaults.

## Future Review Triggers

Revisit this DDR if:

- the installed-system installer starts configuring Plymouth;
- a reusable `schweisos-boot-theme` package becomes justified;
- Secure Boot changes the boot UX;
- the installer starts activating the packaged GRUB alternative;
- the temporary Windows 8 motion-reference calibration is replaced by a fully
  original SchweisOS animation;
- hardware testing shows Plymouth causes unacceptable blank-screen or GPU
  compatibility issues;
- the logo or brand policy changes.
