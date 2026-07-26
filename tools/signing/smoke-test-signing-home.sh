#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

(( $# == 2 )) || fail 'usage: smoke-test-signing-home.sh PUBLIC_BUNDLE_DIR GNUPG_HOME'
public_bundle="$1"
gnupg_home="$2"

for tool in awk chmod dirname mktemp rm sha256sum; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
"${script_dir}/validate-signing-home.sh" "$public_bundle" "$gnupg_home"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
for role in package database; do
  artifact="${tmp_dir}/${role}-role-smoke-test.txt"
  signature="${artifact}.sig"
  {
    printf 'SchweisOS operational signing smoke test\n'
    printf 'schema=1\n'
    printf 'role=%s\n' "$role"
  } >"$artifact"
  chmod 0644 "$artifact"
  "${script_dir}/sign-artifact.sh" \
    --role "$role" \
    --public-bundle "$public_bundle" \
    --gnupg-home "$gnupg_home" \
    --artifact "$artifact" \
    --signature "$signature" \
    --expected-sha256 "$(sha256sum "$artifact" | awk '{ print $1 }')"
  "${script_dir}/verify-artifact-signature.sh" \
    "$role" "$public_bundle" "$artifact" "$signature"
  case "$role" in
    package) wrong_role=database ;;
    database) wrong_role=package ;;
  esac
  if "${script_dir}/verify-artifact-signature.sh" \
      "$wrong_role" "$public_bundle" "$artifact" "$signature" >/dev/null 2>&1; then
    fail "${role} signature was incorrectly accepted for ${wrong_role}"
  fi
done

printf 'Restricted signing-home smoke test passed for both operational roles.\n'
printf 'Unmount and return the encrypted transfer medium to offline custody; do not reuse it.\n'
