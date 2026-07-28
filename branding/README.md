# Branding Directory

Version: 0.4
Status: Active
Date: 2026-07-28

This directory owns canonical SchweisOS source artwork and brand guidance.
Branding must not substitute for technical value.

Runtime-ready assets should be delivered by a package instead of copied into an
ISO profile. The initial runtime branding package is `schweisos-branding`.

## Layout

```text
assets/
  logo/
    schweisos.png
```

`assets/logo/schweisos.png` is the single canonical SchweisOS logo source.
Packages and boot/desktop consumers may install or reference runtime paths, but
they must not maintain independent source copies or alternate logo artwork.

The legacy source path `assets/logo/schweisos-logo.png` is a compatibility
symlink to `schweisos.png`; it is not a second logo file. Package-source
compatibility links follow the same rule. `schweisos-branding` installs one
runtime payload, and Plymouth or bootloader theme packages must reference that
payload rather than embed another logo.

The SchweisOS logo and project marks are official brand identifiers. Until a
complete trademark and brand-use policy is published, use them in a way that
does not imply unofficial builds, mirrors, remixes, or derivatives are official
SchweisOS releases.
