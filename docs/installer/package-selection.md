# Installer Package Selection Contract

Version: 1.0
Status: Faz 1 source implementation; runtime qualification pending
Date: 2026-08-02

SPDX-License-Identifier: CC-BY-SA-4.0

## Purpose

SchweisOS lets users choose a browser, kernel, and bounded set of optional
features without turning installation into an unreviewed package manager. The
selection model preserves Arch package semantics, works without network
access, and keeps the trust boundary visible.

## Payload and Trust

Every selectable package is resolved while the ISO is built from the official
Arch repositories or the signed SchweisOS repository. Calamares does not use
the AUR, Flatpak, third-party vendor repositories, or an unsigned package
cache. The live root is the installation payload and has already passed the
same pacman signature policy as the running medium.

After Calamares mounts the target, upstream `unpackfs` copies that payload. The
SchweisOS reconciliation helper then:

1. validates every selection identifier;
2. removes unselected browsers, kernels, and optional groups;
3. removes Calamares, Archiso construction packages, the live account, and an
   exact list of live-only files;
4. verifies every required and selected package remains installed;
5. marks required and selected packages explicit in pacman's local database;
6. records the resolved choices in
   `/var/lib/schweisos/installer/selection.conf`.

Any missing selected package or unknown identifier stops installation.

## Required Choices

### Browser

- Firefox — default; broad compatibility, privacy controls, and sustained Arch
  support.
- Chromium — open-source Chromium engine and web-application compatibility.
- Falkon — lightweight KDE browser with Plasma integration.

Exactly one remains installed. Browser projects that are not available from an
accepted repository are not presented as fictitious choices.

### Kernel

- Linux Zen — default and visibly recommended for desktop responsiveness and
  gaming workloads.
- Linux — standard Arch kernel and the closest path to Arch's default.
- Linux LTS — reduced kernel churn and conservative hardware support.
- Linux Hardened — additional hardening with an explicit compatibility
  tradeoff.

Exactly one remains installed. systemd-boot entries and initramfs generation
use the selected kernel name.

## Optional Feature Groups

The optional page exposes named groups rather than hundreds of individual
packages:

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
- Power Management: power-profiles-daemon.
- Network Tools: OpenSSH and rsync.
- Containers: Distrobox and rootless Podman; Distrobox is not a sandbox.
- Storage Diagnostics: smartmontools and nvme-cli.
- Recovery Tools: GParted and TestDisk.
- Maintenance Tools: pacman-contrib and Reflector.

Groups default to unselected in Faz 1. Their descriptions state why the group
exists and any important limitation. Core hardware firmware, NetworkManager,
Plasma, pacman trust, and the SchweisOS identity packages remain required and
are not presented as optional toggles.

## Connectivity Behavior

All supported choices install offline. Connectivity shown on the welcome page
is informational. When online, normal signed repository services are available
after installation. The installer does not silently refresh mirrors, perform a
partial upgrade, replace the selected kernel, or change package choices based
on connectivity.

## Adding a Choice

A maintainer must update all of the following in one reviewed change:

- the relevant `packagechooser-*.conf` item and user-facing explanation;
- the reconciliation allowlist and package mapping;
- the ISO package set so the choice is physically available offline;
- source, profile, runtime-payload, and built-ISO validators;
- this contract and any affected runbook;
- package release metadata and checksums.

The package must exist in an accepted repository and must not introduce an
unreviewed background service, telemetry, forced account, partial-upgrade
workflow, or hidden trust-domain transition.
