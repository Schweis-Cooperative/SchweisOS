#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

(( $# == 2 )) || fail 'usage: validate-signing-home.sh PUBLIC_BUNDLE_DIR GNUPG_HOME'
public_bundle="$1"
gnupg_home="$2"

for tool in awk dirname find git gpg readlink stat; do
  require_tool "$tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
"${script_dir}/validate-admitted-public-bundle.sh" "$public_bundle"

[[ -d "$gnupg_home" && ! -L "$gnupg_home" ]] || fail 'signing GnuPG home is missing or unsafe'
gnupg_home="$(readlink -f -- "$gnupg_home")"
[[ "$gnupg_home" != "$project_root" && "$gnupg_home" != "$project_root"/* ]] || \
  fail 'signing GnuPG home must remain outside the source repository'
[[ "$(stat -c '%a' "$gnupg_home")" == 700 ]] || fail 'signing GnuPG home mode must be 0700'
[[ "$(stat -c '%u' "$gnupg_home")" == "$EUID" ]] || \
  fail 'signing GnuPG home must be owned by the invoking signing user'
unsafe_custody_entry="$(
  find "$gnupg_home" -mindepth 1 \( ! -uid "$EUID" -o -perm /022 \) -print -quit
)"
[[ -z "$unsafe_custody_entry" ]] || \
  fail "signing GnuPG home contains unsafe ownership or permissions: $unsafe_custody_entry"
unexpected_link="$(find "$gnupg_home" -mindepth 1 -type l -print -quit)"
[[ -z "$unexpected_link" ]] || fail "signing GnuPG home contains a symlink: $unexpected_link"
revocation_material="$(
  find "$gnupg_home" -mindepth 1 -type f \
    \( -path '*/openpgp-revocs.d/*' -o -name '*.rev' -o -name secring.gpg \) \
    -size +0c -print -quit
)"
[[ -z "$revocation_material" ]] || \
  fail "signing home contains forbidden offline-primary recovery material: $revocation_material"
while IFS= read -r secret_storage_file; do
  secret_storage_mode="$(stat -c '%a' "$secret_storage_file")"
  [[ "$secret_storage_mode" =~ ^[0-7]{3,4}$ ]] || \
    fail "secret-key storage mode is unreadable: $secret_storage_file"
  (( (8#$secret_storage_mode & 8#077) == 0 )) || \
    fail "secret-key storage grants group or other access: $secret_storage_file"
done < <(find "$gnupg_home" -path '*/private-keys-v1.d/*' -type f -print)

public_bundle="$(readlink -f -- "$public_bundle")"
metadata="${public_bundle}/release-key-metadata.tsv"
metadata_value() {
  local key="$1"
  local count value
  count="$(awk -F '\t' -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$metadata")"
  [[ "$count" == 1 ]] || fail "metadata key must appear exactly once: $key"
  value="$(awk -F '\t' -v key="$key" '$1 == key { print $2 }' "$metadata")"
  [[ "$value" =~ ^[A-F0-9]{40}$ ]] || fail "invalid role fingerprint: $key"
  printf '%s\n' "$value"
}

primary_fingerprint="$(metadata_value primary_fingerprint)"
package_fingerprint="$(metadata_value package_signing_fingerprint)"
database_fingerprint="$(metadata_value database_signing_fingerprint)"

mapfile -t secret_records < <(
  gpg --batch --homedir "$gnupg_home" --with-colons --list-secret-keys 2>/dev/null |
    awk -F: '
      $1 == "sec" || $1 == "ssb" {
        kind = $1
        storage = $15
        want = 1
        next
      }
      want && $1 == "fpr" {
        print kind "|" $10 "|" storage
        want = 0
      }
    '
)
(( ${#secret_records[@]} == 3 )) || \
  fail "signing home must contain one primary stub and two operational subkeys; found ${#secret_records[@]}"

declare -A secret_kind=()
declare -A key_storage=()
for secret_record in "${secret_records[@]}"; do
  IFS='|' read -r kind fingerprint storage <<<"$secret_record"
  [[ "$fingerprint" =~ ^[A-F0-9]{40}$ && -z "${secret_kind[$fingerprint]+set}" ]] || \
    fail 'signing home contains an invalid or duplicate secret-key record'
  secret_kind[$fingerprint]="$kind"
  key_storage[$fingerprint]="$storage"
done

[[ "${secret_kind[$primary_fingerprint]-}" == sec \
  && "${key_storage[$primary_fingerprint]-}" == '#' ]] || \
  fail 'offline primary secret material is not represented by an unusable stub'
[[ "${secret_kind[$package_fingerprint]-}" == ssb \
  && -n "${key_storage[$package_fingerprint]-}" \
  && "${key_storage[$package_fingerprint]-}" != '#' ]] || \
  fail 'authorized package-signing secret subkey is unavailable'
[[ "${secret_kind[$database_fingerprint]-}" == ssb \
  && -n "${key_storage[$database_fingerprint]-}" \
  && "${key_storage[$database_fingerprint]-}" != '#' ]] || \
  fail 'authorized database-signing secret subkey is unavailable'

mapfile -t public_fingerprints < <(
  gpg --batch --homedir "$gnupg_home" --with-colons --list-keys 2>/dev/null |
    awk -F: '$1 == "fpr" { print $10 }'
)
(( ${#public_fingerprints[@]} == 3 )) || \
  fail 'signing home contains an unexpected or incomplete public key inventory'
declare -A expected_public=(
  ["$primary_fingerprint"]=1
  ["$package_fingerprint"]=1
  ["$database_fingerprint"]=1
)
declare -A seen_public=()
for fingerprint in "${public_fingerprints[@]}"; do
  [[ -n "${expected_public[$fingerprint]-}" ]] || \
    fail "signing home contains an unauthorized public key: $fingerprint"
  [[ -z "${seen_public[$fingerprint]+set}" ]] || \
    fail "signing home contains a duplicate public fingerprint: $fingerprint"
  seen_public[$fingerprint]=1
done
for fingerprint in "${!expected_public[@]}"; do
  [[ -n "${seen_public[$fingerprint]-}" ]] || \
    fail "signing home is missing an authorized public key: $fingerprint"
done

printf 'SchweisOS restricted signing home validation passed.\n'
printf '  primary:          offline stub (%s)\n' "$primary_fingerprint"
printf '  package signing:  available (%s)\n' "$package_fingerprint"
printf '  database signing: available (%s)\n' "$database_fingerprint"
