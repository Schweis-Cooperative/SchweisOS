# SchweisOS Signing Tools

SPDX-License-Identifier: CC-BY-SA-4.0

This directory owns fail-closed tooling for the SchweisOS production signing
boundary. It does not contain keys, fingerprints, signatures, private paths, or
passphrases.

`release-policy.tsv` is the single machine-readable source for the canonical
release UID, algorithms, capabilities, and validity periods. It is data, not
shell code; both key creation and public-bundle validation read it without
sourcing it.

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
  --acknowledge-airgapped \
  --acknowledge-clock-verified
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

`validate-admitted-public-bundle.sh` is the online production boundary. It
requires the canonical six trust files to be tracked at the current reviewed
commit with a clean keyring-package worktree, then byte-compares the supplied
bundle. Pacman bootstrap, operational signing, signature verification, and
production repository tooling use this stricter gate; they cannot select a
parallel policy-conformant certificate.

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
recorded role fingerprints are available, and perform an independent signing
test. Then unmount and return the encrypted transfer medium to offline custody;
portable file deletion is not represented as secure flash-media erasure. Never
import the offline primary secret key into the signing host.

The canonical import is automated and refuses an existing/non-empty home, a
repository-local path, root execution, a usable primary secret, missing role
subkeys, or any extra key:

```bash
tools/signing/import-operational-subkeys.sh \
  --public-bundle /path/to/schweisos-public \
  --gnupg-home /path/to/restricted-signing-home \
  --package-export /encrypted/media/package-role.secret-subkeys.asc \
  --database-export /encrypted/media/database-role.secret-subkeys.asc \
  --acknowledge-restricted-host
```

`validate-signing-home.sh` can repeat the exact inventory and filesystem-
custody check independently. Before returning the encrypted transfer medium,
run the independent two-role signing test:

```bash
tools/signing/smoke-test-signing-home.sh \
  /path/to/schweisos-public \
  /path/to/restricted-signing-home
```

Only a successful package-role and database-role result completes the import
handoff.

After the ceremony record has been accepted, admit the public-only bundle into
the keyring package with:

```bash
tools/signing/admit-public-bundle.sh \
  --public-bundle /path/to/schweisos-public \
  --ceremony-record /path/to/accepted-ceremony-record.md \
  --acknowledge-fingerprint-review
```

Admission validates two recorded fingerprint readings, renders every source
checksum, and fails if the package is not in its exact bootstrap state. The
result remains an uncommitted package-only change until reviewed.

`sign-artifact.sh` is used only on the restricted signing host after operational
subkeys have been imported. It requires the role, public bundle, private GnuPG
home, artifact, and output signature path:

```bash
tools/signing/sign-artifact.sh \
  --role package \
  --public-bundle /path/to/schweisos-public \
  --gnupg-home /path/to/restricted-signing-home \
  --artifact schweisos-release.pkg.tar.zst \
  --signature schweisos-release.pkg.tar.zst.sig \
  --expected-sha256 APPROVED_64_CHARACTER_LOWERCASE_SHA256
```

Use `--role database` for a finalized `repo-add` database. The command selects
the exact recorded subkey, snapshots the artifact inside a signer-owned
directory, binds it to the pre-approved digest, refuses to overwrite output,
and verifies the signature against `schweisos.gpg` before atomic publication.

`verify-artifact-signature.sh` provides the corresponding public-only role
gate. `bootstrap-pacman-trust.sh` performs the one-time initial client trust
transition only after independent fingerprint verification; it requires an
already initialized pacman keyring and never invokes `pacman-key --init`.

The complete dependency graph and post-ceremony order are documented in
[Production Trust Bootstrap](../../docs/release/production-trust-bootstrap.md).
Only the actions in the
[Physical Offline Ceremony Checklist](../../docs/release/offline-ceremony-checklist.md)
require the air-gapped computer.

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
