# Future Key Material

SPDX-License-Identifier: CC-BY-SA-4.0

No SchweisOS signing keys or other cryptographic material are included in this
bootstrap package.

Production public keys must not be added until the official SchweisOS
release-signing policy is finalized. That policy must define key ownership,
admission, authenticated fingerprint verification, signing authority, rotation,
revocation, compromise recovery, and how a keyring update is delivered safely.

After that policy is finalized and the production public keys are approved, the
expected installed pacman keyring files are:

```text
/usr/share/pacman/keyrings/schweisos.gpg
/usr/share/pacman/keyrings/schweisos-trusted
/usr/share/pacman/keyrings/schweisos-revoked
```

The future process for adding a maintainer key must include at least:

1. Collect the maintainer public key.
2. Verify the fingerprint through an authenticated channel.
3. Record maintainer approval.
4. Add the key to the reviewed keyring source material.
5. Update trusted or revoked metadata.
6. Build and validate `schweisos-keyring`.
7. Publish a signed package update.
8. Announce trust changes when user impact exists.

Private keys must never enter this repository or package. Fake fingerprints,
dummy public keys, generated test keys, empty keyring databases, and signatures
that could be mistaken for production material must not be shipped.
