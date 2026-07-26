# Tools Directory

Version: 0.2
Status: Active maintainer tooling
Date: 2026-07-26

This directory contains maintainer-facing tools for SchweisOS development workflows.

Current tool groups:

- [repo](repo/README.md): local package repository bootstrap and validation tools.
- [release](release/README.md): signed production repository candidate,
  metadata-signing, and completeness validation tools.
- [signing](signing/README.md): offline release-key ceremony, public-bundle
  admission, restricted-host import, trust bootstrap, and role-bound artifact
  signing tools.

Signing custody and trust requirements are defined in
[Release Signing Workflow](../docs/release/release-signing-workflow.md). No
private key, passphrase, fingerprint placeholder, or generated signature
belongs in this directory.
