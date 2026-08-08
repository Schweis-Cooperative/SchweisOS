# schweisos-calamares-config

SPDX-License-Identifier: CC-BY-SA-4.0

Version: 0.5
Status: Installer MVP configuration, offline selection, and runtime launch integration
Date: 2026-08-02

`schweisos-calamares-config` provides the SchweisOS-owned configuration and
launcher for the graphical installer selected by ADR-016.

The package configures Calamares on the live ISO and must not remain installed
in the target. Calamares copies the already mounted, signature-verified live
root with its upstream `unpackfs` module. A SchweisOS-owned reconciliation step
then removes unselected software and exact live-only state before installed
system configuration begins. This gives the installer a complete offline
payload without maintaining a second package universe or weakening pacman
trust.

The installer starts from neutral UTC/default-locale configuration and does
not perform GeoIP lookup. Locale, timezone, keymap, hostname, and user creation
remain explicit user choices in the graphical flow. The complete IANA timezone
database comes from upstream Arch's `tzdata` package; SchweisOS does not keep a
downstream country or timezone list.

## Ownership

This package owns:

- `/etc/calamares/settings.conf`;
- `/etc/calamares/branding/schweisos/branding.desc`, `show.qml`, and
  `welcomeq.qml`;
- `/etc/calamares/modules/*.conf` for SchweisOS installer policy and package
  selection;
- `/usr/bin/schweisos-installer`;
- `/usr/lib/schweisos-calamares/*`, including the exact-path privileged
  XWayland bridge, once-only live autostart helper, network-state probe, target
  reconciliation, and installed-system configuration helpers;
- `/usr/share/applications/schweisos-installer.desktop`;
- `/etc/xdg/autostart/schweisos-installer-autostart.desktop`;
- `/usr/share/polkit-1/actions/org.schweisos.installer.policy`;
- `/usr/share/schweisos/calamares/target-packages.x86_64`.

It does not own Calamares itself, fork Calamares modules, patch pacman, build or
sign packages, publish mirrors, configure Secure Boot, configure full-disk
encryption, or activate the packaged GRUB theme.

## MVP Install Contract

The accepted MVP path is:

```text
Live ISO
  -> Calamares
  -> UEFI validation
  -> storage choices
  -> KDE Plasma desktop confirmation
  -> browser, kernel, installation-profile, and optional-feature selection
  -> user account and summary
  -> partition and mount target
  -> unpack the verified live root
  -> reconcile packages and remove exact live-only state
  -> configure target pacman include
  -> install systemd-boot for the selected kernel
  -> enable NetworkManager and SDDM
  -> user-created Plasma desktop
```

The default filesystem is ext4. Btrfs is exposed as an advanced filesystem
choice only when the live installer environment provides `btrfs-progs`; no
snapshot or rollback promise is made in this phase.

The default bootloader is systemd-boot on UEFI. GRUB remains a documented
future/alternative installed-system path and is not activated by this package.

## Software Selection Contract

The Desktop Environment page is mandatory but intentionally has one selectable
option: KDE Plasma, the only qualified Faz 1 desktop. The Browser page is also
mandatory. Firefox is the enabled default; LibreWolf, Zen Browser, and Brave
are approved architecture entries that remain disabled until reviewed signed
offline payload packages exist. Chromium, Chrome, Edge, Opera, and unowned
vendor binary channels are not approved choices. The installation-profile and
kernel pages are mandatory single-choice steps. The profile page provides
reviewed starting points such as Privacy, Gaming, Developer, Creator, Office,
and Minimal. Linux Zen is the SchweisOS default kernel and is visibly marked
recommended; standard, LTS, and hardened Arch kernels remain explicit
alternatives. Unselected kernels and unsupported browser payload are removed
from the copied payload.

The optional-feature page is a SchweisOS-owned QML page loaded by Calamares
`notesqml`. It reads the selected profile, preselects that profile's reviewed
defaults, and writes `packagechooser_extras`, `packagechooser_extras_mode`, and
`packagechooser_extras_profile` to GlobalStorage for the reconciliation helper.
It does not use the legacy `packagechooser` widget presentation. It exposes
package groups for privacy, security, gaming, development, virtualization,
multimedia, office, international fonts, printing, Bluetooth, accessibility,
Wayland diagnostics, X11 compatibility, power management, network tools,
rootless containers, storage diagnostics, recovery, and maintenance. Every
description explains the purpose and material limitation of the group. The
complete choice universe is present on the ISO, so selections do not depend on
network access.

Reconciliation fails closed if a required or selected package is missing from
the copied payload. It removes Calamares, Archiso construction packages, the
installer configuration, unselected packages, the live account, and an exact
allowlist of live-only files. It records the effective selection in
`/var/lib/schweisos/installer/selection.conf` and marks required/selected
packages explicit in pacman's local database.

## Live Launch Contract

The package owns the only visible installer entry. The separately packaged
Calamares binary omits its generic upstream desktop entry, so no profile-level
desktop-file override or menu-cache behavior is part of the contract.

The hidden XDG autostart entry runs only for the `live` Archiso session and
attempts one launch about three seconds after Plasma starts. State in the
ephemeral live home prevents automatic reopening after the installer is
closed. Manual use of `Install SchweisOS` remains available.

Autostart and the public launcher share
`/usr/lib/schweisos-calamares/is-live-session`. It requires the `live` user,
the exact `/usr/lib/schweisos-live/session` profile marker, a mounted
`/run/archiso/airootfs`, and `archisobasedir=schweis` on the kernel command
line. It intentionally ignores `/run/archiso/bootmnt`: upstream Archiso removes
that transient mount after a healthy `copytoram=auto` transition. The
multi-signal check prevents the live-only marker from authorizing an installed
system by itself.

Calamares 3.4 requires a privileged UI. The exact-path Polkit helper accepts no
arguments, sanitizes loader and Qt plugin environment variables, and selects
Qt's `xcb` backend over packaged XWayland. The public wrapper checks UEFI and
display authorization, prevents concurrent instances, captures a private
launch log, and displays a KDE error dialog for launch or runtime failures.
Immediately before Calamares starts, the privileged helper starts a bounded
SchweisOS-owned network probe that refreshes
`/run/schweisos-installer/network-state` for the first 90 seconds of the
installer session. This avoids a false offline state when NetworkManager
finishes connecting after the installer window appears. Probe failure is
recorded as installer state, not treated as an install blocker.

## Presentation and Network Status

The first page is a SchweisOS-owned `welcomeq` component with a text-first
layout. It describes the distribution, reads SchweisOS' own network-state file
with Calamares' network signal as fallback, exposes the language selector, and identifies
`Maintained by Marijua`. It deliberately has no centered product logo or
duplicated artwork. The sidebar and window icon reference the canonical runtime
logo at `/usr/share/schweisos/branding/schweisos.png`.

Internet status is informative, never an installation requirement. A
disconnected machine receives a clear offline message and can complete the
same package selection because the payload is already on the medium. A
connected machine is told that online features are enabled. The probe accepts
NetworkManager's `full` connectivity result when available; otherwise it
requires a route and verifies HTTPS reachability against SchweisOS and Arch
Linux endpoints with short timeouts. It does not use telemetry, accounts, or
silent bug reporting. The installer does not perform a hidden partial upgrade,
change mirrors silently, or mix live-build and target-package trust domains.

The execution-page slideshow is text-first and identifies `Marijua` as
`Project Maintainer`. Maintainer identity is package data that can be revised
without changing launcher, storage, or boot architecture.

## Calamares Binary Package

Arch official repositories do not provide Calamares in the evaluated package
set. SchweisOS therefore admits a reviewed Calamares binary package to the
signed SchweisOS repository. This configuration package depends on `calamares`
so package resolution fails closed until the reviewed binary is available.

Validation:

```bash
tests/validate-installer-config.sh
tests/test-installer-experience.sh
tests/test-installer-reconciliation.sh
```
