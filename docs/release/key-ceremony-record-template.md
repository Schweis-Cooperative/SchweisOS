# SchweisOS Release Key Ceremony Record

SPDX-License-Identifier: CC-BY-SA-4.0

Status: Template

This record documents the public, reviewable outcome of one production release
key ceremony. Copy it for the ceremony; do not edit this template with real
values. Never record passphrases, private paths, device identifiers, hostnames,
machine usernames, machine IDs, network identifiers, or secret-key material.

## Authorization

- Ceremony date (UTC):
- Policy version:
- Repository commit reviewed:
- Operator public project name or role (not a machine username):
- Witness or second-reading public project name or role:
- Authorization reference:

## Isolation Evidence

- Canonical Arch Linux installation verified:
- Physical network adapters removed or disabled:
- No default route, global address, or active non-loopback interface:
- UTC clock independently verified before key creation:
- No virtualization or container:
- Dedicated offline media custody reviewed:
- Distinct, non-reused private-media and GnuPG passphrases confirmed:
- Media access audit entry recorded (date, purpose, public role, outcome):

## Public Key Inventory

- Primary UID:
- Certification-only primary fingerprint:
- Package-signing subkey fingerprint:
- Repository-database-signing subkey fingerprint:
- Primary creation and expiry (UTC):
- Operational subkey creation and expiry (UTC):

## Independent Verification — First Reading

- First reading certification-only primary fingerprint:
- First reading package-signing subkey fingerprint:
- First reading repository-database-signing subkey fingerprint:

## Independent Verification — Second Reading

- Second reading certification-only primary fingerprint:
- Second reading package-signing subkey fingerprint:
- Second reading repository-database-signing subkey fingerprint:
- If one operator performed both readings, separate reading time (UTC):

## Public Bundle Verification

- Public bundle validator result:
- Public bundle `SHA256SUMS` digest:
- Differences or exceptions: none / documented below

## Private Custody

- Two LUKS2-encrypted offline copies created and verified:
- Copies held in separate physical locations:
- Primary revocation certificate recovery copy verified:
- Operational subkeys exported to encrypted transfer media:

## Completion

- Offline host shut down before network restoration:
- Ceremony result: accepted / rejected
- Reviewer decision and date (UTC):
- Non-sensitive notes:
