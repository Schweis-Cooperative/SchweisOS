# SchweisOS Physical Offline Ceremony Checklist

SPDX-License-Identifier: CC-BY-SA-4.0

This checklist contains only actions that require physical custody of the
offline computer or encrypted removable media. Online admission, signing-host
configuration, repository creation, pacman validation, and ISO work are
intentionally excluded because project automation owns them.

- [ ] As a physical ceremony precondition, on the pre-prepared dedicated
  bare-metal Arch Linux computer, verify the
  independently authenticated installation and reviewed repository commit; do
  not use a VPS, VM, container, build host, or daily workstation.
- [ ] Physically remove network media or disable every network adapter outside
  the operating system, then verify no route, global address, carrier, or
  online networkctl state exists.
- [ ] Verify the offline computer's UTC clock against an independently trusted
  time source before isolation, record only that the check passed, and use
  `--acknowledge-clock-verified` during key creation.
- [ ] Attach and unlock the primary LUKS2-encrypted offline device, a separate
  LUKS2 backup device, encrypted operational-subkey transfer media, public
  output media, and sealed revocation-recovery media.
- [ ] Confirm that the two private LUKS2 devices use strong, distinct
  passphrases that are not reused for SSH, accounts, Git hosting, or disk
  login; record only that this check passed, never the passphrases.
- [ ] Open the offline-media access record with date, purpose, and public
  operator identity, without device identifiers or private paths. Record the
  outcome only when the media is locked again.
- [ ] As a non-root ceremony account, run
  `tools/signing/create-offline-release-key.sh` from the reviewed commit,
  selecting a new directory on the already mounted public-output medium for
  `--public-output`, and enter a new, unique passphrase only through local
  pinentry. Pass both isolation acknowledgements. Confirm after creation that
  this GnuPG passphrase is distinct from
  both media passphrases and all online credentials; record only that the check
  passed.
- [ ] Read the certification, package-signing, and database-signing
  fingerprints directly from the offline display; repeat the complete reading
  independently and record all three values in both structured reading sets.
  With one operator, perform the second reading at a separate time and record
  that fact.
- [ ] Review the ceremony command's successful six-file public-bundle
  validation, including the five-entry checksum inventory, then separately
  compare all three printed fingerprints with both human readings.
- [ ] Stop the GnuPG agent, copy the complete private GnuPG tree with metadata
  preserved into the separately encrypted backup, then verify its public and
  secret inventory before continuing; do not copy live agent sockets.
- [ ] Verify the automatically generated primary revocation certificate on the
  two encrypted private copies and copy it to the sealed offline recovery
  medium; never place it on public or transfer media.
- [ ] Run `tools/signing/export-operational-subkeys.sh` to create the separate
  package and database role exports directly on the encrypted transfer media;
  confirm the offline primary remains only an unusable stub in each export.
- [ ] Verify that the selected public-output directory contains exactly the
  six generated public-bundle files, and record the offline observations in
  the non-sensitive ceremony record without
  private paths, device identifiers, passphrases, machine usernames,
  hostnames, machine IDs, or network identifiers. Final online admission is
  not part of this checklist.
- [ ] Unmount and lock every encrypted device, seal the recovery medium, place
  the two private copies in separate physical custody locations, and close the
  media-access record with the outcome.
- [ ] While the computer remains offline, either sanitize its writable internal
  disk using the approved media-specific process and then shut it down, or
  shut it down and retain the complete computer permanently as an offline
  asset. Restore no physical network capability before shutdown.
