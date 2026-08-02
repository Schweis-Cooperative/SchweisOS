# DDR-002 Installer Experience

Version: 1.3
Status: Accepted for Faz 1 source implementation
Date: 2026-08-02

SPDX-License-Identifier: CC-BY-SA-4.0

## Context

SchweisOS users arrive in a temporary Plasma live session to evaluate or
install the operating system. The first installer integration exposed both
Calamares' generic `Install System` launcher and the distribution-owned
`Install SchweisOS` launcher. It also required the user to discover and start
the installer manually. Both launchers delegated directly to a privileged
Calamares process and could fail without any visible result.

That experience did not communicate one coherent product. It also made a
configuration, display-authorization, or privilege failure indistinguishable
from a slow application start.

## Goals

- Present exactly one user-visible installer named `Install SchweisOS`.
- Start it automatically about three seconds after the first live Plasma
  session becomes usable.
- Never reopen it automatically after the user closes it.
- Keep the same launcher available for deliberate manual reopening.
- Prevent duplicate Calamares windows.
- Explain launch failures in the desktop and preserve a local diagnostic log.
- Preserve UEFI-only Faz 1 limits before the user reaches destructive steps.
- Use the canonical SchweisOS icon without copying artwork.
- Explain connectivity without blocking offline installation.
- Let users choose one supported browser, one supported kernel, and bounded
  optional feature groups from the verified ISO payload.

## Non-Goals

- Changing the accepted Calamares installation engine.
- Adding BIOS, Secure Boot, encryption, LVM, or GRUB installation paths.
- Hiding installation-time failures or weakening Calamares diagnostics.
- Installing live-session launch policy into the target system.
- Claiming successful installation without VM and hardware evidence.

## Decision

### One Product Launcher

The SchweisOS Calamares binary package omits upstream's generic
`calamares.desktop`. `schweisos-calamares-config` owns the only visible desktop
entry. Its application name, icon, startup notification, and executable path
are distribution-owned and stable.

This is a packaging decision, not a Plasma menu-cache workaround. The live ISO
profile does not carry a second desktop-entry mask.

### First-Session Autostart

`schweisos-calamares-config` installs a hidden XDG autostart entry and a small
helper. The helper and public launcher call one shared live-session predicate.
It requires the `live` user, the exact profile-owned
`/usr/lib/schweisos-live/session` marker, the persistent
`/run/archiso/airootfs` mountpoint, and the exact
`archisobasedir=schweis` kernel-command-line token.

The predicate deliberately does not require `/run/archiso/bootmnt`. Archiso
removes that transient mount after a successful automatic copy-to-RAM boot, so
its absence is valid by the time Plasma and the installer start. The combined
predicate still fails closed on installed systems: a marker alone is
insufficient without the live user, Archiso root mount, and kernel contract.
After the predicate passes, autostart creates an atomic per-live-home attempt
marker, waits three seconds, and invokes the same public launcher used by the
application menu.

The attempt and launch markers live under
`$XDG_STATE_HOME/schweisos-installer`, or `~/.local/state/schweisos-installer`
when `XDG_STATE_HOME` is unset. The live home survives logout and login during
one boot, so automatic startup happens once for the medium boot. Rebooting the
read-only medium creates a fresh live home. Manual launches ignore the
autostart marker and remain available.

### Privilege and Display Bridge

Calamares 3.4 runs its UI with administrative privileges. Native Wayland does
not provide a supported general-purpose path for a root GUI client. SchweisOS
therefore uses an exact-path Polkit action whose `allow_gui` annotation carries
only the X11 display authorization needed by a fixed privileged helper. The
helper rejects arguments and unsafe loader/plugin environment variables, then
forces Qt's `xcb` backend over the live Plasma session's packaged XWayland
server.

The live-only Polkit rule authorizes the local active `live` user without a
password. Outside that live policy, the action retains Polkit's normal active
administrator authentication requirement. Neither the installer package nor
the live authorization files enter the target package manifest.

### Visible Failure and Diagnostics

The public launcher performs non-destructive checks before elevation:

- it is running in the SchweisOS live session;
- the medium was booted through UEFI;
- `DISPLAY` and `XAUTHORITY` are available;
- Calamares, Polkit, KDE's dialog helper, and the exact privileged helper are
  executable.

One non-blocking file lock covers the complete Calamares lifetime. A second
launch reports that the installer is already open. Standard output and error
from the privileged process are written with mode 0600 to
`$XDG_STATE_HOME/schweisos-installer/launch.log`. A non-zero launch result
produces a KDE error dialog that names the log. The launcher also records the
failure in the journal when `systemd-cat` is available. No log is uploaded.

### Installer Presentation

Calamares uses its native, upstream-maintained widget layout with a centered
1000x680 window. Its window and sidebar colors use Calamares 3.4's
case-sensitive schema. Product icon and sidebar logo refer to
`/usr/share/schweisos/branding/schweisos.png`, which is owned by
`schweisos-branding` and originates from the one canonical repository logo.

The first page is a SchweisOS-owned `welcomeq` component. It is text-first,
describes the distribution, exposes the language selector, reports network
state, and identifies `Maintained by Marijua`. It does not render a centered
product logo, a compact product banner, or duplicated artwork.

Network state is informative: a disconnected user is explicitly told that
offline installation is fully available, and internet is absent from the
required-condition list. The welcome page does not trust Calamares'
`Network.hasInternet` result alone, because hardware tests showed that value can
remain false while Firefox has working HTTPS connectivity. Before the UI starts,
the privileged SchweisOS launcher writes `/run/schweisos-installer/network-state`
after checking for a route and probing SchweisOS/Arch HTTPS endpoints with short
timeouts. The QML welcome page reads that file and uses Calamares' signal only as
fallback while the file is unavailable.

The branding component also includes Calamares' required `slideshow` key and a
SchweisOS-owned `show.qml` resource. The slideshow is deliberately small:
Calamares owns the progress-page container, while SchweisOS owns only a branded
QML presentation that avoids duplicated artwork, introduces the system in
plain language, and identifies `Marijua` as `Project Maintainer`. Maintainer
identity is package data so it can be revised without altering the launcher or
boot architecture.

### Offline Software Selection

The ISO carries Firefox as the fixed Faz 1 browser plus the complete supported
kernel and optional-feature universe. The installer does not show a separate
browser page until additional browser packages are owned by accepted Arch or
SchweisOS repository sources. A required single-choice page selects exactly
one kernel. Linux Zen is the desktop/gaming-focused default and is visibly
marked recommended; standard, LTS, and hardened Arch kernels remain
alternatives.

A required installation-profile page appears before the kernel and optional
feature pages. The profile selects a reviewed starting point such as Privacy,
Gaming, Developer, Creator, Office, or Minimal. The following optional-feature
page remains available for manual additions. Reconciliation merges the profile
and manual choices idempotently so the UI can be approachable without becoming
a hidden package manager.

Optional feature groups are bounded, repository-backed, and described in terms
of purpose and important limitations. They do not expose AUR, Flatpak, or
third-party vendor trust as if those sources were equivalent to the Arch and
SchweisOS repositories.

Upstream Calamares `unpackfs` copies the already mounted verified live root.
The package-owned reconciliation step validates the choice identifiers,
removes unselected software and exact live-only state, verifies required and
selected packages, and records the effective selection. Unknown choices or a
missing payload package fail installation. This makes offline installation a
real payload contract rather than a network-probe workaround.

### Storage Target Safety

The installer must not offer the exact live boot medium as an installation
target. In a Ventoy/file-based boot, the USB that carries the ISO can appear to
Calamares as a writable exFAT disk because the running root filesystem is
mounted from an ISO file or device-mapper mapping. Leaving that disk visible
lets a user select the same DataTraveler/Ventoy medium that booted the live
session and fail later during `sfdisk` partition-table creation.

SchweisOS treats that as a UX and safety failure, not a user mistake. The
booted medium is removed from the Calamares target-device list before the user
reaches partitioning. The filter uses the active Archiso `img_dev`,
`archisodevice`, `/run/archiso/img_dev`, and `/run/archiso/bootmnt` evidence
instead of a broad "all USB devices" rule. Installing from one USB drive to a
different removable target remains allowed; installing over the active live
medium does not.

## User Flow

```text
Plasma live session
  -> hidden XDG autostart runs once
  -> three-second desktop-settle delay
  -> SchweisOS launcher preflight
  -> exact-path Polkit authorization
  -> Calamares over XWayland
  -> kernel and optional-feature selection
  -> unpack verified live payload and reconcile target
  -> close or complete installation
  -> no automatic reopen
  -> optional manual Install SchweisOS launch
```

## Failure Flow

```text
preflight or privilege/display bridge failure
  -> no disk-changing Calamares job starts

Calamares runtime failure
  -> do not assume the target disk is unchanged
  -> if the active boot medium was visible, treat it as a packaging regression

either failure class
  -> private launch log is retained
  -> KDE error dialog identifies the log
  -> journal receives the failure summary
  -> manual retry remains available
```

## Accessibility and Maintenance

Running a privileged GUI through XWayland is an explicit compatibility bridge,
not the desired long-term security model. It is bounded to the ephemeral live
session and uses upstream Calamares' own privilege requirement. When Calamares
provides a supported unprivileged frontend with a privileged backend, SchweisOS
should reevaluate this bridge in an ADR update.

The implementation adds small audited Bash launch helpers, one Polkit policy,
two desktop entries, and behavioral tests. It does not add a daemon, custom GUI
framework, or installed-system service.

## Validation

Static validation must reject:

- any generic Calamares launcher left in the binary package;
- more than one visible SchweisOS installer entry;
- a visible autostart entry;
- missing live-session, once-only, delay, or manual-reopen behavior;
- a live-session predicate that depends on transient
  `/run/archiso/bootmnt`, or omits the profile marker, persistent
  `/run/archiso/airootfs` mountpoint, live user, or SchweisOS kernel token;
- an unrestricted or argument-accepting privileged helper;
- a Polkit action without an exact executable path and `allow_gui` annotation;
- missing XWayland or visible-error dependencies;
- invalid Calamares branding keys or non-canonical logo references;
- a centered `productWelcome` or `productBanner` on the text-first welcome
  page;
- a welcome component that makes internet connectivity required;
- a slideshow without the SchweisOS welcome message or project-maintainer
  identity;
- browser or kernel selection without exactly one supported default;
- a selectable package absent from the offline ISO payload;
- an installation flow that copies the live root without mandatory target
  reconciliation;
- a Calamares binary package that allows the active SchweisOS live boot medium
  to appear as a writable installation target;
- launcher/autostart sources installed with the wrong package modes;
- installer payload copied into `airootfs/`.

Static checks cannot prove window rendering, Polkit interaction, storage
safety, installation completion, or first boot. Those remain mandatory VM and
hardware qualification gates.

## Related Decisions

- ADR-004 Default Filesystem
- ADR-008 Documentation First
- ADR-010 Licensing Policy
- ADR-012 ISO Build Architecture
- ADR-016 Installer Architecture
- ADR-018 Offline Installer Payload and Package Selection
