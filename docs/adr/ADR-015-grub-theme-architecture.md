# ADR-015 GRUB Theme Architecture

Version: 1.1

## Status

Accepted

## Date

2026-07-28

## Related ADRs and DDRs

- ADR-002 UEFI First
- ADR-003 Package Sources
- ADR-008 Documentation First
- ADR-010 Licensing Policy
- ADR-012 ISO Build Architecture
- ADR-014 Live Boot Experience Architecture
- ADR-017 Live ISO Loopback Boot Compatibility
- DDR-001 Boot Experience

## Context

SchweisOS uses systemd-boot as its default installed-system bootloader design
and Archiso's upstream `uefi.systemd-boot` path for the KDE live medium.
systemd-boot is intentionally a small, text-oriented UEFI boot manager. It can
provide a clean and professional menu through concise titles, ordering, and
console behavior, but it is not a graphical theme engine.

ADR-002 also accepts GRUB as an installed-system alternative. GRUB's upstream
graphical menu supports a plain-text theme format, images, fonts, styled boxes,
and timeout indicators. This makes it appropriate for users or hardware paths
that select GRUB and want a visual experience consistent with SchweisOS
Plymouth branding.

The repository now has a Faz 1 Calamares configuration source for the default
UEFI systemd-boot path, but it still has no implemented GRUB installer path.
Theme availability must not be misrepresented as GRUB installation,
configuration, BIOS support, or a validated installed-system GRUB boot path.
The theme must also avoid copying the canonical SchweisOS logo into another
source owner.

## Decision

SchweisOS will maintain a reusable `schweisos-grub-theme` package as groundwork
for the future installed-system GRUB alternative.

The package:

- depends on upstream Arch `grub` and `schweisos-branding`;
- owns `/usr/share/grub/themes/schweisos/`;
- provides a restrained dark theme, centered branding, balanced spacing,
  high-contrast selection state, and a minimal timeout indicator;
- uses upstream GRUB's documented graphical theme format;
- links its runtime `schweisos.png` to the single logo payload owned by
  `schweisos-branding`;
- does not edit `/etc/default/grub`;
- does not run `grub-install` or `grub-mkconfig`;
- does not create menu entries or choose a default bootloader;
- is not added to the current KDE live ISO package list.

Installing the package is deliberately inert. A future installer owns
bootloader selection and activation. When GRUB is selected, that installer
must ensure the complete resolved theme is readable by GRUB, including systems
with a separate `/boot`, set `GRUB_THEME`, generate configuration through the
normal upstream Arch workflow, and validate the result.

If activation requires a materialized copy under a bootloader-readable
filesystem, the installer must dereference the package's logo symlink. That
installed-system output is generated state. It does not create a second
repository source or change `branding/assets/logo/schweisos.png` as the
canonical artwork.

The current live medium remains `uefi.systemd-boot`. ADR-017 permits only a
minimal profile-owned `grub/loopback.cfg` for Ventoy-style loopback boot
compatibility. No full `grub.cfg`, GRUB Archiso boot mode, BIOS path, graphical
GRUB theme, or GRUB package is added to the live image by this decision.

## Ownership

- `branding/assets/logo/schweisos.png` owns the canonical logo source.
- `schweisos-branding` owns the single runtime logo payload.
- `schweisos-grub-theme` owns only reusable GRUB theme behavior and
  non-logo theme decoration.
- The future installer owns bootloader choice, deployment to boot-readable
  storage, configuration generation, and installed-system validation.
- `iso/profiles/kde/` continues to own the native live-medium systemd-boot
  path plus the narrowly scoped ADR-017 loopback compatibility file.

## Security and Maintenance

The package contains no executable install hook and performs no automatic boot
configuration. A package update therefore cannot silently replace a user's
bootloader or regenerate its configuration.

Activation requires explicit installer behavior because boot filesystem
layouts vary. The installer must fail closed if the theme, logo, fonts, or
generated configuration are not readable on the selected boot path. Theme
failure must never remove GRUB's text console or recovery capabilities.

The maintenance surface is one architecture-independent package, one theme
file, and nine small selection-box slices. It uses GRUB's built-in Unifont
instead of introducing a separately generated font artifact. The source logo
is not duplicated. Visual changes are independently packageable and removable.

## Alternatives Considered

### Force a Graphical Experience into systemd-boot

Rejected. systemd-boot does not provide a comparable graphical theme engine.
Unsupported workarounds would add fragility and conflict with the project's
upstream-first policy.

### Store GRUB Theme Files in the ISO Profile

Rejected. The accepted GRUB path is installed-system behavior, not current
live-medium composition. Profile ownership would prevent clean package updates
and blur the installer boundary. The ADR-017 loopback file is not theme
content; it is a small Archiso boot handoff contract for outer GRUB launchers.

### Put the Theme in `schweisos-branding`

Rejected. `schweisos-branding` owns assets, not bootloader behavior. Combining
them would make a minimal identity package configure a specific bootloader.

### Automatically Enable the Theme from a Package Install Hook

Rejected. Package installation lacks the firmware, disk layout, boot
filesystem, and user-choice context required to safely change bootloader
configuration.

### Copy the Logo into the Theme Package

Rejected. A second source or package payload could drift from the official
logo and violate the canonical ownership rule.

## Consequences

Positive consequences:

- SchweisOS has a coherent graphical GRUB theme ready for future installer
  integration.
- systemd-boot remains honest, minimal, and upstream-compatible.
- GRUB-specific behavior is separately versioned and removable.
- The official logo keeps one repository source and one runtime package owner.
- Bootloader activation remains explicit and context-aware.

Negative consequences:

- Theme availability is not yet an installed-system GRUB implementation.
- A future installer must handle separate-`/boot` materialization and
  configuration generation.
- Visual validation still requires a real GRUB boot path; static checks cannot
  prove firmware rendering.

## Validation

Repository validation must fail closed if:

- the package copies or embeds a logo payload;
- its runtime logo link does not resolve to the `schweisos-branding` path;
- it adds install hooks or automatic GRUB configuration commands;
- its theme omits the documented menu, selection, timeout, and canonical logo
  references;
- any required nine-slice image is missing or malformed;
- the live ISO profile starts consuming the theme package or a full GRUB
  configuration without a separate architecture decision.

Runtime GRUB, installer, VM, and hardware validation remain unexecuted until an
installer path is implemented and explicitly tested.
