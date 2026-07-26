# SchweisOS Trust Evolution

SPDX-License-Identifier: CC-BY-SA-4.0

The installed trust root contains only public material admitted through the
canonical release-signing process. Private keys never enter this package.

Adding or replacing a maintainer or operational key requires:

1. authenticated collection of the public certificate;
2. independent full-fingerprint verification;
3. recorded role and maintainer authorization;
4. offline-primary certification where the role policy requires it;
5. public-bundle validation and keyring source review;
6. a package build and complete payload inspection;
7. a package update signed by a currently trusted operational key; and
8. an announcement whenever user trust or recovery actions change.

Operational subkeys rotate before expiry with an overlap window. Revoked or
expired public records remain available where historical verification requires
them. Replacing the offline primary is a new trust-root ceremony, not a normal
package update.

Fake fingerprints, dummy public keys, generated test keys, empty keyring
databases, and signatures that could be mistaken for production material must
never be shipped.
