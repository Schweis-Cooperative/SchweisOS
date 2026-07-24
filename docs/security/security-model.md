# SchweisOS Security Model

Version: 0.1
Status: Draft
Date: 2026-07-24

## Security Position

SchweisOS security starts with honest boundaries. The project must not claim protections that are not implemented.

## Defaults

- No telemetry by default.
- No forced account system.
- No silent data submission.
- Bug reports only with explicit user approval.
- AUR clearly labeled as unofficial.
- Distrobox clearly labeled as compatibility integration, not a strong sandbox.

## Package Trust

SchweisOS packages must be signed and installed through pacman trust mechanisms. A dedicated keyring package will be required before a public binary repository is treated as official.

Pacman uses OpenPGP-based package signing and repository trust configuration. SchweisOS must not use `TrustAll` for official user-facing repositories.

Reference: [pacman package signing - ArchWiki](https://wiki.archlinux.org/title/Pacman/Package_signing).

## ISO Trust

Release ISOs must eventually provide:

- SHA256 checksum.
- Detached signature.
- Signing key fingerprint.
- Verification instructions.

No ISO should be announced as a release without documented verification steps.

## Flatpak

Flatpak applications run with sandbox permissions, but permissions vary by application. SchweisOS must expose or document permission review instead of describing Flatpak as automatically safe.

Reference: [Flatpak sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html).

## Distrobox

Distrobox containers are tightly integrated with the host and can access user files depending on configuration. SchweisOS must prefer rootless Podman and must not use rootful containers in normal GUI workflows.

Reference: [Distrobox README](https://github.com/89luca89/distrobox).

## Deferred Security Features

The first release does not target Secure Boot or full disk encryption. These features require separate design, testing, and ADRs before being advertised.
