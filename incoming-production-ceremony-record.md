# SchweisOS Release Key Ceremony Record

SPDX-License-Identifier: CC-BY-SA-4.0

Status: Accepted

This record documents the public, reviewable outcome of the SchweisOS
production release key ceremony. It intentionally records only public
verification facts. It does not contain passphrases, private key material,
private filesystem paths, hostnames, machine usernames, machine IDs, network
identifiers, or other secret custody details.

## Authorization

- Ceremony date (UTC): 2026-07-26
- Policy version: tools/signing/release-policy.tsv reviewed for this ceremony
- Repository commit reviewed: c646093e9c27dd7da755dd70af87db5df78d5ab9
- Operator public project name or role (not a machine username): SchweisOS release operator
- Witness or second-reading public project name or role: SchweisOS release operator, second reading at separate time
- Authorization reference: SchweisOS production release-key bootstrap ceremony for SchweisOS Release Authority

## Isolation Evidence

- Canonical Arch Linux installation verified: confirmed for the ceremony target environment
- Physical network adapters removed or disabled: confirmed; no Internet access used during key creation
- No default route, global address, or active non-loopback interface: confirmed before key generation
- UTC clock independently verified before key creation: confirmed before key generation
- No virtualization or container: confirmed for the intended offline ceremony model
- Dedicated offline media custody reviewed: confirmed; private material kept on encrypted offline primary media
- Distinct, non-reused private-media and GnuPG passphrases confirmed: confirmed
- Media access audit entry recorded (date, purpose, public role, outcome): 2026-07-26, production release authority creation, SchweisOS release operator, accepted

## Public Key Inventory

- Primary UID: SchweisOS Release Authority <release@schweisos.org>
- Certification-only primary fingerprint: 456E01F0160DB97F555D706A80E3E6F0A974E24D
- Package-signing subkey fingerprint: 477EF722D34A59EDF052AC7804B92FCAE55C06AB
- Repository-database-signing subkey fingerprint: 503D53AA965764F8DD98E11BA2FF72294187D894
- Primary creation and expiry (UTC): created 2026-07-26T13:56:12Z, validity 10y
- Operational subkey creation and expiry (UTC): created 2026-07-26T13:56:12Z, validity 1y

## Independent Verification - First Reading

- First reading certification-only primary fingerprint: 456E01F0160DB97F555D706A80E3E6F0A974E24D
- First reading package-signing subkey fingerprint: 477EF722D34A59EDF052AC7804B92FCAE55C06AB
- First reading repository-database-signing subkey fingerprint: 503D53AA965764F8DD98E11BA2FF72294187D894

## Independent Verification - Second Reading

- Second reading certification-only primary fingerprint: 456E01F0160DB97F555D706A80E3E6F0A974E24D
- Second reading package-signing subkey fingerprint: 477EF722D34A59EDF052AC7804B92FCAE55C06AB
- Second reading repository-database-signing subkey fingerprint: 503D53AA965764F8DD98E11BA2FF72294187D894
- If one operator performed both readings, separate reading time (UTC): 2026-07-26T14:39:16Z

## Public Bundle Verification

- Public bundle validator result: PASS; SchweisOS public signing bundle validation passed
- Public bundle `SHA256SUMS` digest: verified with `sha256sum --check --strict SHA256SUMS`
- Differences or exceptions: none

## Private Custody

- Two LUKS2-encrypted offline copies created and verified before admission: confirmed by operator attestation; private paths and device identifiers intentionally omitted
- Copies held in separate physical custody locations before admission: confirmed by operator attestation; location details intentionally omitted
- Primary revocation certificate recovery copy verified: confirmed by operator attestation; revocation material is not admitted to Git
- Operational subkeys exported to encrypted transfer media: confirmed; only operational subkeys were exported for signing host use and the exports remain outside Git

## Completion

- Offline host shut down before network restoration: confirmed for ceremony procedure
- Ceremony result: accepted
- Reviewer decision and date (UTC): accepted 2026-07-26T15:03:21Z after public bundle validation, checksum verification, release policy comparison, and two recorded fingerprint readings
- Non-sensitive notes: The public bundle contains `schweisos.gpg`, `schweisos-release.asc`, `release-key-metadata.tsv`, `schweisos-trusted`, `schweisos-revoked`, and `SHA256SUMS`. Operational transfer material remains on encrypted removable media outside Git. Offline private key material and the revocation certificate remain outside Git and must not be published.
