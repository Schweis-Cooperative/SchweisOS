# Tests Directory

Version: 1.6
Status: Active
Date: 2026-07-30

This directory owns repository-level validation that crosses package boundaries.

`validate-distribution-identity.sh` builds and inspects `schweisos-release`,
validates the standard `os-release` fields and project URLs, verifies the
relative `/etc/os-release` ownership link, and checks the JSON metadata.
SchweisOS-owned packages use the project URL; the separately packaged
third-party Calamares source retains its canonical upstream URL. It does not
install the package on the host:

```bash
tests/validate-distribution-identity.sh
```

`validate-build-dependencies.sh` is the read-only dependency-policy and host
toolchain validator:

```bash
tests/validate-build-dependencies.sh
```

It verifies the sorted, unique, package-name-only manifest; the approved direct
package set; availability in existing official Arch synchronization databases;
exact installed packages; required commands; and command package ownership. It
does not refresh databases, install packages, resolve providers as substitutes,
or modify the host. It has no mode that skips host checks.

The current direct set is `archiso`, `bash`, `desktop-file-utils`, `diffutils`,
`git`, `jq`, `mkinitcpio`, `pacman`, `sudo`, and `util-linux`. In particular,
`desktop-file-utils` owns the directly used `desktop-file-validate` interface
for installer launcher validation, `diffutils` owns the directly used `cmp`
interface, `jq` owns exact JSON-schema validation and structured manifest
reads, and `mkinitcpio` owns the directly used `lsinitcpio` interface.

`validate-build-environment.sh` is the network-free, non-destructive ISO build
host gate:

```bash
tests/validate-build-environment.sh
```

It invokes the dependency validator in full mode, then aggregates a concise
PASS/FAIL report for canonical Arch x86_64 identity, known upgrade state,
ADR-013 dependencies and command provenance, pacman
trust policy, at least 20 GiB free space, generated path safety, repository
layout and permissions, prohibited `--force` use, symlinks, secrets, private
signing material, and SchweisOS repository readiness. For local `file://`
SchweisOS endpoints, it also checks that every database entry has a present
package file and detached `.sig` sidecar before Archiso is invoked. Every
`schweisos-*` package and the reviewed Calamares binary package listed in the
ISO profile must have a matching repository package version in every mode. The
selected branding package must also contain the single canonical regular
runtime logo, omit the stale runtime path, and match the source logo SHA256. It
neither mutates host package state nor runs the profile validator or
`mkarchiso`. `scripts/build-iso.sh` runs this gate before every other
substantive build step.

`validate-iso-profile.sh` performs profile-only static validation of the KDE
Archiso profile without requiring Archiso itself or network access:

```bash
tests/validate-iso-profile.sh
```

It validates the profile contract, package manifest, build-time pacman syntax,
UEFI normal/debug templates and exact titles, loader entry suppression, GRUB
loopback compatibility for outer launchers that consume Archiso's contract,
canonical-logo
Plymouth animation primitives, dual unexpected-exit detectors, propagated
client failures, bounded quit waiting, guarded automatic diagnostic fallback,
noninteractive first-boot defaults, mkinitcpio inputs, live-overlay allowlist,
passwordless local live-session administration policy, package-owned installer
launcher boundary, permissions, symlinks, and absence of signing material. It
also proves that the branding package source resolves to
`branding/assets/logo/schweisos.png` and that the theme has no second image
dependency. Pacman parsing uses a disposable sysroot populated from the real
bootstrap configuration files; it does not modify `/etc`, contact repositories,
or invent endpoints. Repository availability remains a separate build-host
preflight.

`validate-installer-config.sh` performs static validation of the Faz 1
Calamares installer configuration:

```bash
tests/validate-installer-config.sh
```

It verifies the `schweisos-calamares-config` package source, exact dependency
contract, package source checksums, Calamares sequence, UEFI systemd-boot MVP
policy, ext4 default with optional Btrfs support, pacstrap target installation,
target pacman include behavior, live ISO package composition, absence of GRUB
activation in the MVP path, one package-owned visible launcher, once-only XDG
autostart, exact-path Polkit/XWayland bridging, private launch logs, visible KDE
failure handling, Calamares branding/slideshow source completeness,
non-executable repository helper sources, and absence of secrets or private-key
material. It does not partition disks, start Calamares, build an ISO, or prove
a graphical installation.

`test-installer-experience.sh` sources the production launcher and autostart
helpers while replacing only their live-environment and GUI/process boundaries:

```bash
tests/test-installer-experience.sh
```

It proves manual reopen, single-instance locking, visible preflight and
privileged-process failure, private failure logging, one-time autostart, and
suppression when a manual launch wins the startup race. It also exercises the
real shared live-session predicate, including a valid Archiso copy-to-RAM
session with no `/run/archiso/bootmnt`, and rejects wrong users, missing
`airootfs`, wrong kernel tokens, and invalid profile markers.

`validate-installer-runtime-payload.sh` inspects the staged Archiso live root
after package installation and before SquashFS compression:

```bash
tests/validate-installer-runtime-payload.sh work/iso/kde/x86_64/airootfs
```

It proves that the actual runtime root contains `/usr/bin/calamares`, exactly
one visible `Install SchweisOS` launcher, the hidden once-only autostart entry,
the exact-path Polkit/XWayland bridge, package-owned Calamares branding,
`show.qml`, the canonical runtime logo path, and pacman local ownership records
for the installer payload. It also rejects Calamares' generic `Install System`
launcher and any desktop entry that bypasses the SchweisOS wrapper.

`test-plymouth-watchdog.sh` performs disposable behavioral validation of the
real watchdog control flow:

```bash
tests/test-plymouth-watchdog.sh
```

It rewrites only the helper's absolute command and marker paths to point at
temporary stubs. Eight scenarios cover completed normal handoff, an activating
handoff that later succeeds, failed handoff, inactive failed handoff, an absent
daemon, a live daemon that later stops, health-helper error propagation, and
systemd state-query error propagation. It requires fallback exactly once in
failure scenarios and rejects false fallback or false success. It does not
build or boot an ISO.

`validate-grub-theme.sh` validates the separately packaged, inert
installed-system GRUB theme groundwork:

```bash
tests/validate-grub-theme.sh
```

It proves that the repository has exactly one regular canonical logo file,
legacy logo paths remain compatibility symlinks, the GRUB package links to the
runtime logo owned by `schweisos-branding`, the theme and nine-slice selection
assets are structurally complete, no package hook installs or configures GRUB,
and the package has not entered the current systemd-boot live ISO. The current
live profile may contain only the ADR-017 `grub/loopback.cfg` compatibility
file; a full live GRUB configuration remains forbidden.

`validate-iso-loopback-boot.sh` performs a completed-ISO bootloader-layer
inspection for the reviewed Archiso outer-GRUB loopback contract:

```bash
tests/validate-iso-loopback-boot.sh out/iso/schweisos-2026.07.27-x86_64.iso
```

It does not extract SquashFS or boot the image. It proves the ISO-visible root
contains the live kernel, initramfs, EFI image, boot catalog, one Archiso UUID
marker, systemd-boot entries, and `/boot/grub/loopback.cfg`. It reads the real
ISO volume label with `xorriso`, checks that `grubenv` and the native
systemd-boot `archisosearchuuid` command lines agree with the generated UUID
marker, compares the built loopback file to the reviewed profile source after
Archiso token substitution, rejects unresolved template tokens, validates the
`archisobasedir`, `img_dev`, and `img_loop` handoff, and confirms that the live
initramfs contains `archiso_loop_mnt` so the handoff can be consumed after the
kernel starts. It also confirms that the ISO marker is raw-discoverable by the
SchweisOS initramfs fallback used when a multiboot command line supplies native
Archiso search without `img_dev/img_loop`.

Ventoy's mode label does not prove that this loopback file was consumed; the
resulting `/proc/cmdline` distinguishes an `img_dev`/`img_loop` handoff from
the native `archisosearchuuid` path.

`validate-boot-media-copy.sh` performs the final read-only source-to-media
binding after completed-ISO validation and before a file-based multiboot
hardware boot:

```bash
tests/validate-boot-media-copy.sh BUILD_MANIFEST SOURCE_ISO COPIED_ISO
```

It first binds the source bytes and clean build commit to a successful
completed build manifest, requires that commit to be the current clean
checkout, and reruns the current built-ISO identity and boot-composition
validators. It rejects the same path or filesystem object, a destination
without a distinct block-device-backed filesystem, a destination that is not
mounted read-only, a renamed artifact, zero or multiple SchweisOS ISOs, size
or SHA256 drift, and any byte difference. Copy, synchronize, safely unmount,
physically reinsert, and mount read-only before invoking it. It deliberately
does not claim to validate raw whole-device writes.

`test-boot-media-copy.sh` covers manifest binding and representative success
and rejection paths without requiring removable media. Build-environment
validation runs this regression test:

```bash
tests/test-boot-media-copy.sh
```

`validate-repository-bootstrap.sh` checks the Sprint A ownership and trust
contract between `schweisos-mirrorlist` and `schweisos-pacman-config`. It builds
both packages in a disposable directory and does not contact the network,
publish a repository, alter host pacman configuration, or install packages.
It passes `--nodeps` to `makepkg` because the bootstrap SchweisOS dependencies
need not be installed on the development host; source checksums, package
creation, metadata, and payload ownership are still validated.

Run it from any directory inside the repository:

```bash
tests/validate-repository-bootstrap.sh
```

`install-local-bootstrap-packages.sh` validates that the five live/repository
foundation packages published by the bootstrap tool can coexist in one
isolated pacman database and filesystem root. Installer packages may also be
present in that local repository for ISO consumption, but they are intentionally
outside this bootstrap co-installation test. The optional GRUB theme is
intentionally outside the live bootstrap set. The test requires a previously
created local `schweisos` repository:

```bash
tools/repo/publish-local-packages.sh
tests/install-local-bootstrap-packages.sh
```

The test installs the SchweisOS-owned repository snippet and local development
endpoint into the disposable root, then verifies that pacman can parse them. It
still installs package artifacts through direct package files from the local
database directory and confines pacman root, database, cache, hooks, log, and
GPG paths to a temporary directory. Unsigned developer artifacts are accepted
only through the disposable config's `LocalFileSigLevel`; official repository
policy remains `Required TrustedOnly`.

The test uses pacman's `--assume-installed` facility for the external Arch
`filesystem` and `pacman` dependencies. It is a SchweisOS package-set test, not
an Arch base-system installation test.

Strategy reference: [docs/testing/testing-strategy.md](../docs/testing/testing-strategy.md).

`validate-signing-tooling.sh` checks the production signing policy and its
repository-side enforcement without generating a key:

```bash
tests/validate-signing-tooling.sh
```

It validates script syntax and permissions, offline ceremony guards, absence
of unattended passphrase handling, LUKS-backed primary and operational-subkey
custody, exact signing-subkey selection, restricted signing-home inventory,
public-bundle admission, initial pacman trust bootstrap, immediate signature
verification, private-material exclusion, signed repository boundaries, and
required rotation policy. It treats bootstrap, complete production, and
partial keyring states separately; a partial state is fatal.

`validate-keyring-package.sh` builds and inspects the keyring package in either
its exact bootstrap state or its complete admitted production state:

```bash
tests/validate-keyring-package.sh
```

`validate-signed-repository-client.sh` validates a completed signed repository.
It creates a disposable pacman trust root, uses the supplied `file://`
SchweisOS repository and read-only official Arch repositories only for
dependency resolution, requires trusted package and database signatures,
downloads every SchweisOS repository package, tests role rejection, and leaves
host pacman state untouched.

`validate-built-iso-identity.sh` performs post-build SquashFS forensics without
booting a VM. It proves the installed `schweisos-release` version, package
ownership, portable `/etc/os-release` link, and effective SchweisOS fields:

```bash
tests/validate-built-iso-identity.sh out/iso/schweisos-2026.07.27-x86_64.iso
```

The validator extracts the ISO SquashFS and can need several GiB of temporary
space. By default it uses the ignored repository work area
`work/validators/built-iso-identity/` instead of a possibly small `/tmp` tmpfs.
Set `TMPDIR=/path/to/disk-backed-temp` only when the build host needs a
different disposable extraction location. The script removes only its own
per-run temporary directory. It extracts without restoring SquashFS xattrs
because this validator inspects package metadata, file ownership records, and
identity files as an unprivileged post-build gate; xattr policy belongs to a
separate explicit validator if SchweisOS adopts one.

`validate-built-iso-boot.sh` performs the complementary post-build composition
check without booting a VM:

```bash
tests/validate-built-iso-boot.sh out/iso/schweisos-2026.07.27-x86_64.iso
```

It verifies the bootloader-visible GRUB loopback handoff, the two resolved
systemd-boot entries, disabled interactive firstboot, the exact installed
`schweisos-branding` version and canonical logo hash, C.UTF-8/UTC live
defaults, SDDM/Plasma handoff inputs, live fallback unit payloads including the
boot-bounded watchdog, live sudo/polkit administration policy, hidden upstream
Calamares launcher override, merged systemd unit validity, and the Plymouth
configuration, script plugin, theme, canonical logo, and SchweisOS ISO-file
fallback runtime hook inside the actual initramfs. A stale signed
branding package therefore fails before the wrapper publishes checksums even
if source-only profile validation passes.

The validator uses `work/validators/built-iso-boot/` by default and, like the
identity validator, can require several GiB of disk-backed temporary space.
`scripts/build-iso.sh` invokes the loopback check through the built-boot gate
after `mkarchiso` and before checksum publication.

`validate-iso-build-manifest.sh` owns the completed successful build-manifest
contract:

```bash
tests/validate-iso-build-manifest.sh logs/iso/build-manifest.json
tests/validate-iso-build-manifest.sh \
  logs/iso/build-manifest.json \
  out/iso/schweisos-2026.07.27-x86_64.iso
```

The build manifest uses `schweisos.iso-build-manifest.v2` and records both
post-build validators explicitly. The validator requires canonical JSON that
byte-matches `jq --indent 2`, exact top-level and nested key sets, correct
types, a clean completed build, one artifact candidate, all six build gates as
`pass`, and internally consistent artifact and sidecar names. Missing, extra,
duplicate, ambiguous, legacy, failed, dirty, or partially completed manifests
are rejected. In `--release` mode it additionally requires
`build_mode=release`, `epoch_origin=environment`, canonical Arch x86_64 host
provenance, and a non-null BLAKE2b-512 value.

With the optional ISO argument, the validator recomputes and binds the exact
artifact basename, byte size, SHA256, and BLAKE2b-512 when the manifest
records it. Release staging always uses `--release` mode, so BLAKE2b-512 is
mandatory and bound to the ISO bytes. It additionally requires the requested
release identifier to reproduce the ISO filename exactly and derives the
profile from the build manifest; an optional caller profile is only an
equality assertion.

There is no current successful ISO evidence for the newly changed first-boot
payload, Plymouth watchdog, built-boot validator, or exact v2 manifest
contract. These commands document the required production-host gates for a
fresh future build; an older local ISO is not evidence for them.

`validate-release-artifacts.sh` validates one prepared release artifact
directory without building, signing, publishing, or touching host configuration:

```bash
tests/validate-release-artifacts.sh release/YYYY.MM.DD
```

It checks the canonical release layout, exactly one date-bound ISO, mandatory
SHA256 verification, mandatory BLAKE2b-512 verification, canonical exact-schema
build and release manifests, copied-manifest-to-ISO binding, profile and
cross-manifest provenance, exact regenerated release notes and artifact log,
unexpected files, permissions, symlink attacks, path traversal, and
private-information patterns.

`test-release-artifacts.sh` runs disposable release artifact scenarios using
temporary fixture files:

```bash
tests/test-release-artifacts.sh
```

It covers successful validation, missing or invalid checksums, empty and
duplicate ISO fixtures, corrupt manifests, unexpected files, symlink attacks,
path traversal, permission violations, symlink input rejection, development,
legacy, duplicate-key, and extra-field manifest rejection, explicit post-build
gate failures, basename/size/SHA/BLAKE2b binding, release-identifier and
profile mismatch, cross-manifest tampering, release notes/log tampering,
validator-version mismatch, and atomic duplicate-output rejection. It never
invokes `mkarchiso`.
