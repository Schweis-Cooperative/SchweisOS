# Build Policy Inputs

This directory contains machine-readable policy inputs for SchweisOS build
validation. It does not contain generated artifacts, package caches, Archiso
work state, or release signing material.

`build-dependencies.txt` is the canonical list of packages that SchweisOS
requires directly on an ISO build host. Dependencies pulled by Arch's
`archiso` package remain owned by upstream package metadata; the dependency
validator checks the resulting commands and their package owners separately.

The manifest intentionally contains one package name per line, with no blank
lines, comments, version pins, groups, providers, or installation commands. It
must remain sorted and unique. Changes require review against ADR-013 and
`tests/validate-build-dependencies.sh`.
