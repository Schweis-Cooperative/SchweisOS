# Future SchweisOS Public Keys

SPDX-License-Identifier: CC-BY-SA-4.0

This directory is reserved for future production public keys and reviewed
keyring input files. This README exists so the intentionally empty source layout
can be version-controlled without adding placeholder cryptographic material.

The release-signing policy is finalized. No key may be added here until the
physical offline ceremony and documented ownership, independent fingerprint,
public-bundle validation, and package-review gates complete.

Do not add fake keys, sample fingerprints, placeholder private keys, generated test keys, or cryptographic material that could be mistaken for a real SchweisOS trust anchor.

When the production bundle is approved, this directory may contain exactly the
reviewed public inputs required by the keyring package, including:

- `schweisos.gpg`
- `schweisos-release.asc`
- `schweisos-trusted`
- `schweisos-revoked`
- `release-key-metadata.tsv`
- `SHA256SUMS`

Verified fingerprints should be recorded through the release-signing process;
they must not be invented merely to populate this directory.

Private keys and secret signing material must never be stored in this directory,
the source repository, or the binary package. Installed pacman keyring files
should eventually be generated only from reviewed public material in this
directory.
