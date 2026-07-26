#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

role=''
public_bundle=''
gnupg_home=''
artifact=''
signature=''
expected_sha256=''

usage() {
  cat <<'EOF'
Usage: sign-artifact.sh OPTIONS

Required options:
  --role package|database
  --public-bundle PATH
  --gnupg-home PATH
  --artifact PATH
  --signature PATH
  --expected-sha256 HEX
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
    --expected-sha256)
      (( $# >= 2 )) || fail 'missing value for --expected-sha256'
      expected_sha256="$2"
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
[[ -n "$public_bundle" && -n "$gnupg_home" && -n "$artifact" && -n "$signature" \
  && -n "$expected_sha256" ]] || \
  fail 'all path options are required'
[[ "$expected_sha256" =~ ^[a-f0-9]{64}$ ]] || fail 'expected SHA256 must be 64 lowercase hex characters'

for tool in awk basename chmod cmp cp dirname gpg ln mktemp readlink rm sha256sum stat; do
  require_tool "$tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
"${script_dir}/validate-admitted-public-bundle.sh" "$public_bundle"

[[ -d "$public_bundle" ]] || fail 'public bundle directory does not exist'
[[ -d "$gnupg_home" ]] || fail 'signing GnuPG home does not exist'
[[ -f "$artifact" && ! -L "$artifact" ]] || fail 'artifact does not exist or is not a regular file'
public_bundle="$(readlink -f -- "$public_bundle")"
gnupg_home="$(readlink -f -- "$gnupg_home")"
artifact="$(readlink -f -- "$artifact")"
[[ -d "$gnupg_home" && ! -L "$gnupg_home" ]] || fail 'unsafe signing GnuPG home'
[[ "$(stat -c '%a' "$gnupg_home")" == 700 ]] || fail 'signing GnuPG home mode must be 0700'
[[ -f "$artifact" && ! -L "$artifact" && -s "$artifact" ]] || fail 'unsafe or empty artifact'
[[ "$(stat -c '%u' "$artifact")" == "$EUID" ]] || \
  fail 'artifact must be owned by the invoking signing user'
artifact_mode="$(stat -c '%a' "$artifact")"
[[ "$artifact_mode" =~ ^[0-7]{3,4}$ ]] || fail 'artifact mode is unreadable'
(( (8#$artifact_mode & 8#022) == 0 )) || fail 'artifact is group- or world-writable'
artifact_parent="$(dirname -- "$artifact")"
[[ "$(stat -c '%u' "$artifact_parent")" == "$EUID" ]] || \
  fail 'artifact parent must be owned by the invoking signing user'
artifact_parent_mode="$(stat -c '%a' "$artifact_parent")"
[[ "$artifact_parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'artifact parent mode is unreadable'
(( (8#$artifact_parent_mode & 8#022) == 0 )) || \
  fail 'artifact parent is group- or world-writable'
[[ "$(sha256sum "$artifact" | awk '{ print $1 }')" == "$expected_sha256" ]] || \
  fail 'artifact does not match the approved SHA256 digest'
"${script_dir}/validate-signing-home.sh" "$public_bundle" "$gnupg_home"

signature_parent="$(dirname -- "$signature")"
[[ -d "$signature_parent" && ! -L "$signature_parent" ]] || fail 'unsafe signature parent directory'
signature_parent="$(readlink -f -- "$signature_parent")"
[[ "$(stat -c '%u' "$signature_parent")" == "$EUID" ]] || \
  fail 'signature parent must be owned by the invoking signing user'
signature_parent_mode="$(stat -c '%a' "$signature_parent")"
[[ "$signature_parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'signature parent mode is unreadable'
(( (8#$signature_parent_mode & 8#022) == 0 )) || \
  fail 'signature parent is group- or world-writable'
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
signing_workspace="$(mktemp -d --tmpdir="$signature_parent" ".${signature_name}.signing.XXXXXX")"
chmod 0700 -- "$signing_workspace"
snapshot="${signing_workspace}/artifact.snapshot"
temporary_signature="${signing_workspace}/signature"
trap 'rm -rf -- "$signing_workspace"' EXIT
cp --reflink=auto -- "$artifact" "$snapshot"
chmod 0400 -- "$snapshot"
[[ "$(sha256sum "$snapshot" | awk '{ print $1 }')" == "$expected_sha256" ]] || \
  fail 'private signing snapshot does not match the approved SHA256 digest'
cmp -s "$artifact" "$snapshot" || fail 'artifact changed while the signing snapshot was created'

gpg --homedir "$gnupg_home" \
  --local-user "${signing_fingerprint}!" \
  --detach-sign \
  --output "$temporary_signature" \
  -- "$snapshot"

"${script_dir}/verify-artifact-signature.sh" \
  "$role" "$public_bundle" "$snapshot" "$temporary_signature"
[[ "$(sha256sum "$artifact" | awk '{ print $1 }')" == "$expected_sha256" ]] || \
  fail 'artifact changed after signing'
cmp -s "$artifact" "$snapshot" || fail 'artifact bytes changed after signing'

chmod 0644 -- "$temporary_signature"
ln -- "$temporary_signature" "$signature" || fail 'signature output appeared concurrently'
rm -f -- "$temporary_signature"
trap - EXIT
rm -rf -- "$signing_workspace"

printf 'SchweisOS artifact signing completed.\n'
printf '  role:        %s\n' "$role"
printf '  fingerprint: %s\n' "$signing_fingerprint"
printf '  artifact:    %s\n' "$(basename -- "$artifact")"
printf '  sha256:      %s\n' "$expected_sha256"
printf '  signature:   %s\n' "$(basename -- "$signature")"
