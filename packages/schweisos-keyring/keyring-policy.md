# SchweisOS Keyring Policy

SPDX-License-Identifier: CC-BY-SA-4.0

`schweisos-keyring` is responsible only for SchweisOS-owned package signing public keys and related trust metadata.

It must not:

- modify Arch Linux keyrings
- replace `archlinux-keyring`
- disable pacman signature verification
- use `TrustAll`
- trust third-party package sources
- configure SchweisOS repositories
- sign packages
- create repository databases

Arch Linux trust remains provided by `archlinux-keyring`.

SchweisOS repository enablement belongs to `schweisos-pacman-config`. SchweisOS mirror discovery belongs to `schweisos-mirrorlist`.

This package is intentionally incomplete until real signing keys exist.
