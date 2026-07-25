# SchweisOS Keyring Policy

SPDX-License-Identifier: CC-BY-SA-4.0

`schweisos-keyring` is responsible only for approved SchweisOS-owned package
signing public keys and their trust or revocation metadata.

The bootstrap package contains no key material and establishes no production
trust. Production public keys may be introduced only after the official
SchweisOS release-signing policy is finalized.

It must not:

- modify Arch Linux keyrings
- replace `archlinux-keyring`
- disable pacman signature verification
- use `TrustAll`
- set `SigLevel = Never`
- trust third-party package sources
- configure SchweisOS repositories
- contain private signing keys
- invoke `pacman-key` from package installation hooks
- sign packages
- create repository databases

Arch Linux trust remains provided by `archlinux-keyring`.

SchweisOS repository enablement belongs to `schweisos-pacman-config`. SchweisOS mirror discovery belongs to `schweisos-mirrorlist`.

Mirrors and repository locations are distribution channels, not trust anchors.
Possession of this package without approved public keys does not make a
repository or package trusted.

This package is intentionally non-operational until the release-signing policy
and production public keys exist.
