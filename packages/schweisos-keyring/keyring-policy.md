# SchweisOS Keyring Policy

SPDX-License-Identifier: CC-BY-SA-4.0

`schweisos-keyring` is responsible only for approved SchweisOS-owned package
signing public keys and their trust or revocation metadata.

The bootstrap package contains no key material and establishes no production
trust. The production policy is finalized, but public keys may be introduced
only after its offline ceremony and admission gates complete.

It must not:

- modify Arch Linux keyrings
- replace `archlinux-keyring`
- disable pacman signature verification
- use `TrustAll`
- set `SigLevel = Never`
- trust third-party package sources
- configure SchweisOS repositories
- contain private signing keys
- initialize pacman's keyring or fetch keys from installation hooks
- sign packages
- create repository databases

Arch Linux trust remains provided by `archlinux-keyring`.

SchweisOS repository enablement belongs to `schweisos-pacman-config`. SchweisOS mirror discovery belongs to `schweisos-mirrorlist`.

Mirrors and repository locations are distribution channels, not trust anchors.
Possession of this package without approved public keys does not make a
repository or package trusted.

This package is intentionally non-operational until the reviewed production
public bundle exists. Once admitted, its install script may use only the
upstream `pacman-key --populate schweisos` pattern against an already initialized
pacman keyring.
