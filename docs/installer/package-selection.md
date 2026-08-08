# Installer Package Selection Contract

Version: 1.0
Status: Faz 1 source implementation; runtime qualification pending
Date: 2026-08-02

SPDX-License-Identifier: CC-BY-SA-4.0

## Purpose

SchweisOS lets users choose the supported desktop target, browser, kernel,
installation profile, and a bounded set of optional features without turning
installation into an unreviewed package manager. The selection model preserves
Arch package semantics, works without network access, and keeps the trust
boundary visible.

## Payload and Trust

Every selectable package is resolved while the ISO is built from the official
Arch repositories or the signed SchweisOS repository. Calamares does not use
the AUR, Flatpak, third-party vendor repositories, or an unsigned package
cache. The live root is the installation payload and has already passed the
same pacman signature policy as the running medium.

After Calamares mounts the target, upstream `unpackfs` copies that payload. The
SchweisOS reconciliation helper then:

1. validates every selection identifier;
2. removes unselected kernels, optional groups, unsupported browser payload,
   and forbidden browser payload if it ever enters the live root through a
   dependency or old repository generation;
3. removes Calamares, Archiso construction packages, the live account, and an
   exact list of live-only files;
4. verifies every required and selected package remains installed;
5. marks required and selected packages explicit in pacman's local database;
6. records the resolved choices in
   `/var/lib/schweisos/installer/selection.conf`.

Any missing selected package or unknown identifier stops installation.

## Required Payload and Choices

### Desktop Environment

Faz 1 installs KDE Plasma. The installer intentionally exposes a Desktop
Environment page, but that page has exactly one selectable option:
KDE Plasma. The purpose is a professional guided flow, a clear support
boundary, and future extensibility without pretending that other desktops are
already qualified.

Future desktop choices such as GNOME, XFCE, LXQt, Cinnamon, MATE, Budgie,
COSMIC, Hyprland, Sway, Wayfire, Niri, Openbox, Qtile, i3, bspwm, River,
Enlightenment, UKUI, and Deepin require separate package ownership and QA
before they can become selectable in the installer. A maintainer adding a
second desktop selection must provide:

- an accepted package-set manifest for each desktop or window manager;
- installed-session, display-manager, portal, audio, network, and update
  validation for each choice;
- licensed screenshot assets and source/license metadata;
- reconciliation rules that remove unselected desktop payload cleanly;
- QEMU, raw USB, Ventoy Normal, Ventoy GRUB2, and hardware qualification
  evidence for the expanded matrix.

Until that work exists, displaying selectable non-KDE choices would be a false
promise and is forbidden by validation.

### Browser

The Browser page is present in Faz 1. Firefox is the default and the only
enabled browser in the current ISO payload. It provides broad compatibility,
privacy controls, and sustained Arch support from accepted repository trust
domains.

LibreWolf, Zen Browser, and Brave are approved browser candidates in the UI
architecture but remain disabled until SchweisOS can ship reviewed, signed,
offline-available packages for them. Chromium, Chrome, Edge, Opera, and other
unowned external binary channels are not part of the approved browser set.
Disabled entries must explain why they cannot be selected; they must not
silently map to AUR helpers, vendor binaries, or network downloads.

### Kernel

The Kernel page is a required single-choice QML page:

- Linux Zen — default and visibly recommended for desktop responsiveness and
  gaming workloads.
- Linux — standard Arch kernel and the closest path to Arch's default.
- Linux LTS — reduced kernel churn and conservative hardware support.
- Linux Hardened — additional hardening with an explicit compatibility
  tradeoff.

Exactly one kernel remains installed. systemd-boot entries and initramfs
generation use the selected kernel name.

### Installation Profile

The profile page is a required single-choice QML step that selects a reviewed
starting point. The following profiles are package-owned data, not hardcoded
launcher behavior:

- Privacy (Recommended): Security, Maintenance Tools, and X11 Compatibility.
- Gaming: Gaming, Power Management, and X11 Compatibility.
- Developer: Development, Containers, Network Tools, and Storage Diagnostics.
- Creator: Multimedia and International Fonts.
- Office: Office, Printing, International Fonts, and Bluetooth.
- Minimal: no optional feature groups.

The next page preselects the profile's feature groups and lets the user add or
remove optional groups before installation. After that page has been reviewed,
the Optional Features selection is authoritative: reconciliation does not
silently re-add profile defaults the user removed.

## Optional Feature Groups

The Optional Features page is a SchweisOS-owned QML page loaded through
Calamares' `notesqml` module. It reads the selected profile, preselects that
profile's reviewed defaults, and writes `packagechooser_extras`,
`packagechooser_extras_mode`, and `packagechooser_extras_profile` to
GlobalStorage for the reconciliation helper. This avoids the legacy widget
presentation of upstream `packagechooser` while keeping target package policy
in the audited reconciliation helper. The page exposes named groups rather than
hundreds of individual packages:

- Privacy: Tor Browser launcher.
- Security: firewalld and Plasma firewall integration.
- Gaming: GameMode, MangoHud, and Lutris.
- Development: Git, CMake, and Ninja.
- Virtualization: QEMU Desktop and Virtual Machine Manager.
- Multimedia: VLC.
- Office: LibreOffice Fresh.
- International Fonts: Noto core, CJK, and emoji fonts.
- Printing: CUPS and its graphical configuration tool.
- Bluetooth: BlueZ and command-line utilities.
- Accessibility: Orca and Speech Dispatcher.
- Wayland Tools: Wayland protocol diagnostics.
- X11 Compatibility: XWayland for supported legacy applications inside the
  default Wayland session.
- Power Management: power-profiles-daemon.
- Network Tools: OpenSSH and rsync.
- Containers: Distrobox and rootless Podman; Distrobox is not a sandbox.
- Storage Diagnostics: smartmontools and nvme-cli.
- Recovery Tools: GParted and TestDisk.
- Maintenance Tools: pacman-contrib and Reflector.

Groups default to the selected profile's starting point. Changing the profile
and returning to the Optional Features page refreshes those defaults until the
user reviews the page. Once reviewed, the exact checked groups are recorded as
custom selection state and become the installed-system contract. Descriptions
state why each group exists and any important limitation. Core hardware
firmware, NetworkManager, Plasma, pacman trust, and the SchweisOS identity
packages remain required and are not presented as optional toggles.

## Connectivity Behavior

All supported choices install offline. Connectivity shown on the welcome page
is informational. When online, normal signed repository services are available
after installation. The installer does not silently refresh mirrors, perform a
partial upgrade, replace the selected kernel, or change package choices based
on connectivity.

## Adding a Choice

A maintainer must update all of the following in one reviewed change:

- the relevant `packagechooser-*.conf` or `optionalfeatures.conf` plus the
  package-owned QML user-facing explanation;
- the reconciliation allowlist and package mapping;
- the ISO package set so the choice is physically available offline;
- desktop/session and screenshot licensing evidence if the choice changes the
  installed desktop environment;
- source, profile, runtime-payload, and built-ISO validators;
- this contract and any affected runbook;
- package release metadata and checksums.

The package must exist in an accepted repository and must not introduce an
unreviewed background service, telemetry, forced account, partial-upgrade
workflow, or hidden trust-domain transition.
