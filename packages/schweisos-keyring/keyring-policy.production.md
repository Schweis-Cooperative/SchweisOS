# SchweisOS Keyring Policy

SPDX-License-Identifier: CC-BY-SA-4.0

`schweisos-keyring` owns only approved SchweisOS public certificates and their
pacman trust and revocation metadata. It never owns repository configuration,
mirrors, package selection, or private signing operations.

It must not:

- modify or replace `archlinux-keyring`;
- change pacman `SigLevel`;
- use `TrustAll` or `SigLevel = Never`;
- trust third-party package sources;
- contain private keys, revocation certificates, or operational exports;
- initialize pacman's local keyring or fetch network keys;
- sign packages or create repository databases.

Arch Linux trust remains provided by `archlinux-keyring`. SchweisOS repository
enablement belongs to `schweisos-pacman-config`; mirror discovery belongs to
`schweisos-mirrorlist`. Mirrors are distribution channels, never trust anchors.

The install hook may invoke only `pacman-key --populate schweisos`, and only
when pacman's local keyring is already initialized. Every trust change requires
the reviewed admission, rotation, or revocation process.
