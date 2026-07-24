# Future Key Material

SPDX-License-Identifier: CC-BY-SA-4.0

No real SchweisOS signing keys are included in this package yet.

When real keys are approved, the expected installed pacman keyring files are:

```text
/usr/share/pacman/keyrings/schweisos.gpg
/usr/share/pacman/keyrings/schweisos-trusted
/usr/share/pacman/keyrings/schweisos-revoked
```

The future process for adding a maintainer key should include:

1. Collect the maintainer public key.
2. Verify the fingerprint through an authenticated channel.
3. Record maintainer approval.
4. Add the key to the reviewed keyring source material.
5. Update trusted or revoked metadata.
6. Build and validate `schweisos-keyring`.
7. Publish a signed package update.
8. Announce trust changes when user impact exists.

Fake fingerprints, dummy public keys, and generated test keys must not be shipped in the official keyring package.
