# schweisos-keyring

SPDX-License-Identifier: CC-BY-SA-4.0

Status: Production trust package

`schweisos-keyring` distributes only the reviewed public SchweisOS release
certificate, pacman owner-trust metadata, revocation metadata, and public audit
records. It never contains private keys or operational signing exports.

The package is deliberately separate from `schweisos-release`: distribution
identity does not grant repository trust. Arch Linux trust continues to be
provided exclusively by `archlinux-keyring`; this package neither replaces nor
modifies Arch keyring source files.

The operational package depends explicitly on `archlinux-keyring`, ensuring
that Arch's trust payload is present before the SchweisOS post-install hook is
considered. The hook still performs a safe no-op when the target pacman
keyring has not been initialized; it never initializes or replaces that
keyring.

Installed pacman keyring files:

```text
/usr/share/pacman/keyrings/schweisos.gpg
/usr/share/pacman/keyrings/schweisos-trusted
/usr/share/pacman/keyrings/schweisos-revoked
```

The install script follows pacman's keyring-package contract. It runs
`pacman-key --populate schweisos` only when the local pacman keyring is already
initialized. It does not run `pacman-key --init`, fetch network keys, edit
`pacman.conf`, change `SigLevel`, or modify Arch-owned keyring files.

Public material enters `keys/` only through the reviewed admission command:

```bash
tools/signing/admit-public-bundle.sh \
  --public-bundle /path/to/reviewed-public-bundle \
  --ceremony-record /path/to/accepted-ceremony-record.md \
  --acknowledge-fingerprint-review
```

The command validates the complete bundle, renders the checksum-pinned
operational PKGBUILD, removes bootstrap sentinels, and leaves a focused Git
change for review. It reads no secret material.

The admitted six-file bundle remains canonical under `keys/`. Reviewed
repository-relative source links expose those exact files to makepkg without
duplicating bytes, embedding host paths, or introducing a network source.

Validation from the repository root:

```bash
tests/validate-keyring-package.sh
tests/validate-signing-tooling.sh
```

Key rotation and revocation remain governed by the canonical Release Signing
Workflow and require a separately reviewed public-bundle update.
