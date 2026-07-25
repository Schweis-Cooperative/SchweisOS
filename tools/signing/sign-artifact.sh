#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

role=''
public_bundle=''
gnupg_home=''
artifact=''
signature=''

usage() {
  cat <<'EOF'
Usage: sign-artifact.sh OPTIONS

Required options:
  --role package|database
  --public-bundle PATH
  --gnupg-home PATH
  --artifact PATH
  --signature PATH
  -h, --help

The signature path must not exist. GnuPG obtains any passphrase through
pinentry; this command has no passphrase option.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

while (( $# > 0 )); do
  case "$1" in
    --role)
      (( $# >= 2 )) || fail 'missing value for --role'
      role="$2"
      shift 2
      ;;
    --public-bundle)
      (( $# >= 2 )) || fail 'missing value for --public-bundle'
      public_bundle="$2"
      shift 2
      ;;
    --gnupg-home)
      (( $# >= 2 )) || fail 'missing value for --gnupg-home'
      gnupg_home="$2"
      shift 2
      ;;
    --artifact)
      (( $# >= 2 )) || fail 'missing value for --artifact'
      artifact="$2"
      shift 2
      ;;
    --signature)
      (( $# >= 2 )) || fail 'missing value for --signature'
      signature="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
done

case "$role" in
  package|database) ;;
  *) fail '--role must be package or database' ;;
esac
[[ -n "$public_bundle" && -n "$gnupg_home" && -n "$artifact" && -n "$signature" ]] || \
  fail 'all path options are required'

for tool in awk dirname gpg gpgv mktemp mv readlink sha256sum; do
  require_tool "$tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
"${script_dir}/validate-public-bundle.sh" "$public_bundle"

[[ -d "$public_bundle" ]] || fail 'public bundle directory does not exist'
[[ -d "$gnupg_home" ]] || fail 'signing GnuPG home does not exist'
[[ -f "$artifact" ]] || fail 'artifact does not exist or is not a regular file'
public_bundle="$(readlink -f -- "$public_bundle")"
gnupg_home="$(readlink -f -- "$gnupg_home")"
artifact="$(readlink -f -- "$artifact")"
[[ -d "$gnupg_home" && ! -L "$gnupg_home" ]] || fail 'unsafe signing GnuPG home'
[[ -f "$artifact" && ! -L "$artifact" && -s "$artifact" ]] || fail 'unsafe or empty artifact'

signature_parent="$(dirname -- "$signature")"
[[ -d "$signature_parent" && ! -L "$signature_parent" ]] || fail 'unsafe signature parent directory'
signature_parent="$(readlink -f -- "$signature_parent")"
signature="${signature_parent}/$(basename -- "$signature")"
[[ ! -e "$signature" && ! -L "$signature" ]] || fail 'signature output already exists'

metadata="${public_bundle}/release-key-metadata.tsv"
case "$role" in
  package) metadata_key='package_signing_fingerprint' ;;
  database) metadata_key='database_signing_fingerprint' ;;
esac
signing_fingerprint="$({
  awk -F '\t' -v key="$metadata_key" '$1 == key { print $2 }' "$metadata"
})"
[[ "$signing_fingerprint" =~ ^[A-F0-9]{40}$ ]] || fail 'invalid authorized signing fingerprint'

secret_fingerprint_count="$({
  gpg --batch --homedir "$gnupg_home" --with-colons \
    --list-secret-keys "${signing_fingerprint}!" 2>/dev/null |
    awk -F: -v expected="$signing_fingerprint" '$1 == "fpr" && $10 == expected { count++ } END { print count + 0 }'
})"
[[ "$secret_fingerprint_count" == 1 ]] || \
  fail "authorized ${role} secret subkey is not available"

signature_name="$(basename -- "$signature")"
temporary_signature="$(mktemp --tmpdir="$signature_parent" ".${signature_name}.XXXXXX")"
trap 'rm -f -- "$temporary_signature"' EXIT

gpg --homedir "$gnupg_home" \
  --local-user "${signing_fingerprint}!" \
  --detach-sign \
  --output "$temporary_signature" \
  -- "$artifact"

verification_status="$({
  gpgv --status-fd 1 \
    --keyring "${public_bundle}/schweisos.gpg" \
    "$temporary_signature" "$artifact" 2>/dev/null
})" || fail 'detached signature verification failed'
verified_fingerprint="$({
  awk '$1 == "[GNUPG:]" && $2 == "VALIDSIG" { print $3 }' <<<"$verification_status"
})"
[[ "$verified_fingerprint" == "$signing_fingerprint" ]] || \
  fail 'signature was not made by the authorized role subkey'

chmod 0644 -- "$temporary_signature"
mv -T -- "$temporary_signature" "$signature"
trap - EXIT

printf 'SchweisOS artifact signing completed.\n'
printf '  role:        %s\n' "$role"
printf '  fingerprint: %s\n' "$signing_fingerprint"
printf '  artifact:    %s\n' "$(basename -- "$artifact")"
printf '  sha256:      %s\n' "$(sha256sum "$artifact" | awk '{ print $1 }')"
printf '  signature:   %s\n' "$(basename -- "$signature")"
