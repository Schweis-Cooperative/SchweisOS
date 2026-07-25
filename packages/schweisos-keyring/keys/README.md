# Future SchweisOS Public Keys

SPDX-License-Identifier: CC-BY-SA-4.0

This directory is reserved for future production public keys and reviewed
keyring input files. This README exists so the intentionally empty source layout
can be version-controlled without adding placeholder cryptographic material.

No key may be added here until the official SchweisOS release-signing policy is
finalized and the key has completed its documented ownership and fingerprint
verification process.

Do not add fake keys, sample fingerprints, placeholder private keys, generated test keys, or cryptographic material that could be mistaken for a real SchweisOS trust anchor.

When real keys are approved, this directory may contain:

- armored public keys
- trusted owner metadata
- revoked key metadata

Verified fingerprints should be recorded through the release-signing process;
they must not be invented merely to populate this directory.

Private keys and secret signing material must never be stored in this directory,
the source repository, or the binary package. Installed pacman keyring files
should eventually be generated only from reviewed public material in this
directory.
