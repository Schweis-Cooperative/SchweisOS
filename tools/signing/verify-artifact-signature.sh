#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

(( $# == 4 )) || \
  fail 'usage: verify-artifact-signature.sh package|database PUBLIC_BUNDLE ARTIFACT SIGNATURE'
role="$1"
public_bundle="$2"
artifact="$3"
signature="$4"
case "$role" in package|database) ;; *) fail 'role must be package or database' ;; esac

for tool in awk basename date dirname gpg gpgv grep readlink; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
"${script_dir}/validate-admitted-public-bundle.sh" "$public_bundle"

[[ -f "$artifact" && ! -L "$artifact" && -s "$artifact" ]] || fail 'artifact is missing, empty, or unsafe'
[[ -f "$signature" && ! -L "$signature" && -s "$signature" ]] || fail 'signature is missing, empty, or unsafe'
public_bundle="$(readlink -f -- "$public_bundle")"
artifact="$(readlink -f -- "$artifact")"
signature="$(readlink -f -- "$signature")"

case "$role" in
  package) metadata_key=package_signing_fingerprint ;;
  database) metadata_key=database_signing_fingerprint ;;
esac
expected_fingerprint="$(
  awk -F '\t' -v key="$metadata_key" '$1 == key { print $2 }' \
    "${public_bundle}/release-key-metadata.tsv"
)"
[[ "$expected_fingerprint" =~ ^[A-F0-9]{40}$ ]] || fail 'authorized role fingerprint is invalid'

verification_status="$(
  gpgv --status-fd 1 \
    --keyring "${public_bundle}/schweisos.gpg" \
    "$signature" "$artifact" 2>/dev/null
)" || fail 'detached signature verification failed'
if grep -Eq '^\[GNUPG:\] (BADSIG|ERRSIG|NO_PUBKEY|EXPSIG|EXPKEYSIG|REVKEYSIG|KEYEXPIRED|SIGEXPIRED)( |$)' \
    <<<"$verification_status"; then
  fail 'signature status reports an invalid, expired, or revoked signing state'
fi
mapfile -t valid_signatures < <(
  awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" {
    print $3 "|" $5 "|" $6 "|" $12
  }' <<<"$verification_status"
)
(( ${#valid_signatures[@]} == 1 )) || fail 'signature produced an unexpected validation record count'
IFS='|' read -r valid_fingerprint signature_timestamp signature_expiry signature_primary \
  <<<"${valid_signatures[0]}"
[[ "$valid_fingerprint" == "$expected_fingerprint" ]] || \
  fail "signature is not authorized for the ${role} role"
primary_fingerprint="$(
  awk -F '\t' '$1 == "primary_fingerprint" { print $2 }' \
    "${public_bundle}/release-key-metadata.tsv"
)"
[[ "$signature_primary" == "$primary_fingerprint" ]] || \
  fail 'signature is not bound to the admitted primary certificate'

mapfile -t role_key_times < <(
  gpg --batch --with-colons --show-keys "${public_bundle}/schweisos.gpg" |
    awk -F: -v expected="$expected_fingerprint" '
      $1 == "sub" { created = $6; expires = $7; want = 1; next }
      want && $1 == "fpr" {
        if ($10 == expected) print created "|" expires
        want = 0
      }
    '
)
(( ${#role_key_times[@]} == 1 )) || fail 'authorized role validity window is ambiguous'
IFS='|' read -r role_created role_expires <<<"${role_key_times[0]}"
[[ "$signature_timestamp" =~ ^[0-9]+$ && "$signature_expiry" =~ ^[0-9]+$ \
  && "$role_created" =~ ^[0-9]+$ && "$role_expires" =~ ^[0-9]+$ ]] || \
  fail 'signature or role validity timestamp is invalid'
(( signature_timestamp >= role_created && signature_timestamp <= role_expires )) || \
  fail 'signature was created outside the authorized role validity window'
current_epoch="$(date -u +%s)"
(( signature_timestamp <= current_epoch + 300 )) || fail 'signature creation time is unacceptably in the future'
if (( signature_expiry != 0 && signature_expiry <= current_epoch )); then
  fail 'detached signature is expired'
fi

printf 'SchweisOS %s signature validation passed: %s\n' \
  "$role" "$(basename -- "$artifact")"
