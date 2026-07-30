# SchweisOS Production Trust Bootstrap

Version: 1.2
Status: Public trust admitted; operational pipeline implemented
Date: 2026-07-28

## Purpose

This runbook joins the accepted signing policy, keyring admission,
the restricted signing host, the signed repository, pacman trust, and ISO
validation. It adds no alternate trust path.

The initial physical ceremony and public-bundle admission are complete. The
repository tracks the production public certificate and metadata, while
private primary material and revocation material remain outside the repository.
Operational package and database roles have been exercised through the signed
repository pipeline. Future rotations must repeat the same fail-closed gates;
ceremony completion is not permission to bypass them.

## Dependency Graph

```text
accepted policy + reviewed repository commit
  -> physical offline ceremony
       -> reviewed public bundle -> public-bundle validation
       |    -> schweisos-keyring admission -> review and commit
       |         -> initial pacman trust bootstrap
       |         -> committed-bundle production gate
       |              + encrypted package/database subkey exports
       |              -> restricted signing-host import and inventory validation
                 -> independent two-role smoke test
                      -> encrypted transfer-media return to offline custody
                           -> package-role signatures
                                -> repo-add candidate with embedded package signatures
                                     -> database-role signatures
                                          -> complete repository validation
                                               -> disposable pacman validation
                                                    -> release-mode mkarchiso
                                                         -> built-ISO identity validation
                                                              -> built-ISO boot validation
```

The two ceremony outputs meet only through fingerprints recorded in
`release-key-metadata.tsv`. The offline primary private key never reaches any
online node.

## Automated Gates

The repository provides these complete, fail-closed transitions:

| Transition | Canonical command |
| --- | --- |
| Ceremony output to reviewed public bundle | `tools/signing/validate-public-bundle.sh` |
| Reviewed bundle to package source | `tools/signing/admit-public-bundle.sh` |
| Operational exports to restricted GnuPG home | `tools/signing/import-operational-subkeys.sh` |
| Restricted signing-home inventory check | `tools/signing/validate-signing-home.sh` |
| Independent operational signing test | `tools/signing/smoke-test-signing-home.sh` |
| Artifact to exact role signature | `tools/signing/sign-artifact.sh` |
| Signature to exact role verification | `tools/signing/verify-artifact-signature.sh` |
| Public bundle to initialized pacman trust | `tools/signing/bootstrap-pacman-trust.sh` |
| Signed packages to repo-add candidate | `tools/release/create-repository-candidate.sh` |
| Candidate metadata to signed repository | `tools/release/sign-repository-metadata.sh` |
| Repository completeness gate | `tools/release/validate-release-repository.sh` |
| Signed repository to disposable pacman client | `tests/validate-signed-repository-client.sh` |
| Complete repository to build-host source | `tools/release/activate-build-repository.sh` |
| Built ISO to effective identity proof | `tests/validate-built-iso-identity.sh` |
| Built ISO to live boot-payload proof | `tests/validate-built-iso-boot.sh` |

The admission command renders the operational keyring PKGBUILD and removes all
bootstrap sentinels. No checksum, source link, install hook, or package-layout
edit remains for the operator to perform manually.

## Trust-Domain Handoff

The build host produces immutable package artifacts and digests without
private keys. The restricted signing host imports only the two encrypted
operational subkey exports and returns detached signatures. Repository tooling
accepts only those role-correct signatures. The build host and restricted
signing host must remain separate systems even when one maintainer operates
both.

The import command creates and validates a new `0700` GnuPG home outside the
source checkout. Its parent and both encrypted export files must be owned by
the signing user and inaccessible to group/other. It kills the staged GnuPG
agent before the atomic rename and revalidates the final path. Therefore no
signing-host directory may be pre-populated with placeholder material. A
general build VPS must never be converted into the restricted signing host
merely to avoid this boundary.

All online production commands use the committed-bundle gate. A merely
policy-conformant external certificate is insufficient: the supplied public
bundle must be byte-identical to the clean six-file trust root tracked in the
current `schweisos-keyring` commit.

## Initial Client Trust

The first keyring package cannot authenticate its own trust root. After two
independent fingerprint comparisons, the admitted public bundle may be loaded
into an already initialized pacman keyring with
`bootstrap-pacman-trust.sh`. The tool does not run `pacman-key --init`, does not
contact a keyserver, and proves that Arch keyring source files and fingerprints
remain present. It accepts Arch trust only from the root-owned canonical
`/usr/share/pacman/keyrings` files owned by `archlinux-keyring`, requires one
canonical pacman local master, and rejects every other primary certificate.

Once that one-time trust bridge is complete, pacman requires trusted package
and database signatures. Every later keyring package must be authenticated by
a currently trusted SchweisOS package-signing subkey.

## Release Execution

The initial operational handoff imports both encrypted role exports into the
restricted signing home, runs `smoke-test-signing-home.sh`, and returns the
still-encrypted transfer medium to offline custody. Portable software deletion
is not represented as secure flash-media erasure. This handoff is repeated only
for a new signing host or an approved key rotation, not for every repository
generation.

For each signed repository generation:

1. validate the admitted public bundle and restricted signing-home inventory;
2. build the current packages in the canonical clean Arch build environment;
3. transfer immutable package artifacts and approved digests to the restricted
   signing host;
4. sign each package with `sign-artifact.sh --role package`;
5. create a new repository candidate from the signed artifacts;
6. transfer the complete immutable candidate to the signing host because the
   metadata signer revalidates every package and embedded package signature
   before signing the two repo-add archives; transfer the separately recorded
   database and files SHA256 digests through the approved evidence channel;
7. run `tools/release/sign-repository-metadata.sh` on the restricted signing
   host with both approved digests, then return the complete candidate and both
   detached metadata signatures to the repository host;
8. validate the complete repository and run the disposable pacman client gate;
9. confirm the build host has the admitted trust; use the one-time bootstrap
   command only for a new trust root;
10. activate the complete signed generation at the build host's configured
   local source with `activate-build-repository.sh`;
11. run the existing build validators and `SCHWEISOS_ISO_BUILD_MODE=release`
   build entry point;
12. require `validate-built-iso-identity.sh`, `validate-built-iso-boot.sh`, and
    `scripts/schweisos-doctor` before any boot test or release. The build
    wrapper runs them before checksum publication. The identity and boot gates
    extract the ISO into their own disposable directories under the ignored
    repository `work/` tree by default; set `TMPDIR` only when the build host
    requires another disk-backed extraction location. The identity gate extracts
    without restoring SquashFS xattrs because it checks identity ownership, not
    Linux capability policy. The doctor separately verifies the embedded
    SquashFS SHA512 and parses SquashFS xattr metadata. The boot gate verifies
    the selected branding and installer configuration packages, live defaults,
    merged systemd units, Plasma handoff inputs, and actual Plymouth/initramfs
    payload.

Failures stop at their current trust boundary. No failed candidate is published
and no validator has a permissive production mode.

The repository proves the tooling and admitted public inventory, but it cannot
prove the continuing physical custody of offline media or operational host
separation. Those are operator-controlled security obligations and must be
audited before a public release.
