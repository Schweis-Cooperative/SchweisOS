# Local Bootstrap Repository

SPDX-License-Identifier: CC-BY-SA-4.0

This directory is generated for SchweisOS developer testing only.

It is not a production repository, publication source, artifact archive,
canonical endpoint, or mirror source. Its contents are mutable, unsigned, and
must never be exposed as official SchweisOS infrastructure.

Directory ownership:

- `packages/` contains local `makepkg` outputs.
- `database/` contains the local `repo-add` database and the package copies
  referenced by that database.

The fixed repository database name is `local-bootstrap`. No production channel
name or network endpoint belongs in this layout.

This layout is separate from the local development endpoint installed by
`schweisos-mirrorlist` under `/var/lib/schweisos/local-repo/$repo/os/$arch`.
That endpoint is reserved for signed repository-integration testing and is not
populated by this local package-file workflow.
