# SchweisOS Signing Tools

SPDX-License-Identifier: CC-BY-SA-4.0

This directory owns fail-closed tooling for the SchweisOS production signing
boundary. It does not contain keys, fingerprints, signatures, private paths, or
passphrases.

The canonical policy is
[Release Signing Workflow](../../docs/release/release-signing-workflow.md).

## Commands

`create-offline-release-key.sh` performs the reviewed key ceremony. It must run
on a dedicated, physically offline Arch Linux host from a verified repository
checkout. Both its GnuPG home and public output directory must be outside the
checkout:

```bash
tools/signing/create-offline-release-key.sh \
  --gnupg-home /path/on/encrypted/offline-media/gnupg \
  --public-output /path/on/separate/media/schweisos-public \
  --acknowledge-airgapped
```

The paths above are examples selected by the ceremony operator. They are not
defaults and are never embedded in project files. The script refuses SSH,
root, virtualization, active network paths, repository-local private state, and
pre-existing key homes. The private GnuPG home must resolve to a LUKS-backed
block-device chain. GnuPG obtains a new passphrase through pinentry; no
passphrase option exists. Record the public outcome using
[`key-ceremony-record-template.md`](../../docs/release/key-ceremony-record-template.md).

`validate-public-bundle.sh` validates a ceremony's public output without
requiring or reading private material:

```bash
tools/signing/validate-public-bundle.sh /path/to/schweisos-public
```

`export-operational-subkeys.sh` creates separate secret-subkey exports for the
package and repository-database roles. It runs only on the same offline host,
requires a LUKS-backed transfer destination, and uses GnuPG's
`--export-secret-subkeys` operation so the certification primary is represented
only by a non-secret stub:

```bash
tools/signing/export-operational-subkeys.sh \
  --public-bundle /path/to/schweisos-public \
  --offline-gnupg-home /path/on/encrypted/offline-media/gnupg \
  --output-dir /path/on/encrypted/transfer-media/subkeys \
  --acknowledge-airgapped \
  --acknowledge-encrypted-media
```

Import the two exports into the restricted signing GnuPG home, verify that the
recorded role fingerprints are available, perform an independent signing test,
and then securely erase the transfer copies. Never import the offline primary
secret key into the signing host.

`sign-artifact.sh` is used only on the restricted signing host after operational
subkeys have been imported. It requires the role, public bundle, private GnuPG
home, artifact, and output signature path:

```bash
tools/signing/sign-artifact.sh \
  --role package \
  --public-bundle /path/to/schweisos-public \
  --gnupg-home /path/to/restricted-signing-home \
  --artifact schweisos-release.pkg.tar.zst \
  --signature schweisos-release.pkg.tar.zst.sig
```

Use `--role database` for a finalized `repo-add` database. The command selects
the exact recorded subkey, refuses to overwrite output, and verifies the
signature against `schweisos.gpg` before the atomic rename.

## Boundaries

- The offline primary never enters this repository or a signing host.
- Operational subkey transfer files never enter this repository.
- These tools never generate development keys.
- The key ceremony never runs on a VPS, CI worker, VM, or general build host.
- Package building and repository mutation are separate from signing.
- Public-bundle admission into `schweisos-keyring` requires human fingerprint
  verification and package review.
- Existing local bootstrap tooling remains unsigned development tooling and is
  not a release publication path.
