# Security Policy

SPDX-License-Identifier: CC-BY-SA-4.0

SchweisOS is in the bootstrap engineering phase. It does not yet publish stable
release artifacts.

## Reporting Security Issues

Do not report suspected vulnerabilities in public issues if disclosure could
put users at risk.

Until a dedicated private disclosure channel exists, use GitHub private
vulnerability reporting if it is enabled for `Schweis-Cooperative/SchweisOS`.
If it is not enabled, contact the project maintainers through the least-public
available project channel and avoid posting exploit details publicly.

## Supported Versions

No stable SchweisOS version is currently supported.

| Version | Supported |
| --- | --- |
| Bootstrap documentation and prototypes | No stable support |

## Security Principles

- No telemetry by default.
- No forced account system.
- Package and release trust must be explicit.
- AUR, Flatpak, and Distrobox must be documented as separate trust domains.
- Security claims must match implemented protections.

See [docs/security/security-model.md](docs/security/security-model.md).
