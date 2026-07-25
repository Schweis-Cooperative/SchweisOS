# Local Bootstrap Repository

SPDX-License-Identifier: CC-BY-SA-4.0

This directory is generated for SchweisOS developer testing only.

It is not a production repository, publication source, artifact archive,
canonical endpoint, or mirror source. Its contents are mutable, unsigned, and
must never be exposed as official SchweisOS infrastructure.

Directory ownership:

- `packages/` contains local `makepkg` outputs.
- `schweisos/os/x86_64/` contains the local `repo-add` database and the package
  copies referenced by that database.

The fixed repository database name is `schweisos` because pacman expects the
database basename to match the configured repository section. This layout is
still local development infrastructure and must not be promoted as a production
channel, canonical endpoint, or mirror source.

This layout is separate from the local development endpoint installed by
`schweisos-mirrorlist` under `/var/lib/schweisos/local-repo/$repo/os/$arch`.
The directory shape intentionally matches that endpoint, so selecting
`/var/lib/schweisos/local-repo` as the repository root makes this local
repository directly visible to pacman. This does not make the repository
official, signed, or publishable.
