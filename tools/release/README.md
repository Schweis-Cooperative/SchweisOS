# SchweisOS Production Repository Tools

SPDX-License-Identifier: CC-BY-SA-4.0

This directory implements the production repository boundary defined by
ADR-011. It is separate from `tools/repo/`, whose unsigned output is strictly a
local development artifact.

The production sequence is deliberately split across trust domains:

```text
validated package artifact
  -> package-role signature on restricted signing host
  -> create-repository-candidate.sh on repository host
  -> database-role signatures via sign-repository-metadata.sh
  -> validate-release-repository.sh --state complete
  -> disposable pacman validation
  -> publication by designated artifact infrastructure
```

`create-repository-candidate.sh` accepts only signed packages whose detached
signatures match the admitted package-signing subkey. It calls upstream
`repo-add --include-sigs --prevent-downgrade` with stably sorted input and
creates a new output tree; it never mutates an existing candidate. Every
noninitial candidate must identify the currently complete signed repository
with `--baseline-dir`. The tool rejects removal or version rollback relative
to that baseline, as well as replacement of same-version package bytes.
Generation zero requires the explicit, one-time
`--initial-repository` acknowledgement; an absent baseline is never inferred.

`sign-repository-metadata.sh` runs only on the restricted signing host. It
requires the exact restricted GnuPG inventory, signs both the database and
files archives with the database-signing subkey, requires both pre-approved
SHA256 digests printed by candidate creation, verifies both results, and rolls
back a partial signature pair. A per-candidate lock and no-clobber publication
prevent concurrent signers from overwriting or deleting another valid pair.

`validate-release-repository.sh` has two explicit states:

- `candidate`: all packages and embedded package signatures are valid, and no
  database signature may yet exist.
- `complete`: both metadata signatures are present, valid, and role-correct.

No command here generates a key, weakens `SigLevel`, publishes a network
endpoint, reads host pacman keys, or promotes output from `out/local-repo/`.
The public endpoint publication mechanism remains infrastructure-owned; it may
consume only a repository that passes the complete validator.

`activate-build-repository.sh` is the build-host-only activation boundary. It
stages and revalidates a complete repository, uses a same-filesystem directory
exchange under a nonblocking publisher lock for updates, and retains the
previous generation under a derived history root on the same filesystem. It
never creates a public endpoint or accepts an unsigned candidate.

After a complete repository exists, run the disposable client gate:

```bash
tests/validate-signed-repository-client.sh \
  --repository-dir /path/to/candidate/schweisos/os/x86_64 \
  --public-bundle packages/schweisos-keyring/keys
```

The test uses a temporary local pacman trust root and a `file://` source. It
never reads or changes the host pacman configuration or host keyring.
