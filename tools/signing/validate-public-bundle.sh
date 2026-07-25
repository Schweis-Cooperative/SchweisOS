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

(( $# == 1 )) || fail 'usage: validate-public-bundle.sh PUBLIC_BUNDLE_DIR'
bundle_dir="$1"

for tool in awk find gpg grep mktemp readlink sha256sum sort stat; do
  require_tool "$tool"
done

[[ -d "$bundle_dir" && ! -L "$bundle_dir" ]] || \
  fail 'public bundle must be a real directory'
bundle_dir="$(readlink -f -- "$bundle_dir")"

expected_files=(
  SHA256SUMS
  release-key-metadata.tsv
  schweisos-release.asc
  schweisos-revoked
  schweisos-trusted
  schweisos.gpg
)

for filename in "${expected_files[@]}"; do
  path="${bundle_dir}/${filename}"
  [[ -f "$path" && ! -L "$path" ]] || fail "missing or unsafe public bundle file: $filename"
done

unexpected_entry="$({
  find "$bundle_dir" -mindepth 1 -maxdepth 1 \
    ! -name SHA256SUMS \
    ! -name release-key-metadata.tsv \
    ! -name schweisos-release.asc \
    ! -name schweisos-revoked \
    ! -name schweisos-trusted \
    ! -name schweisos.gpg -print -quit
})"
[[ -z "$unexpected_entry" ]] || fail "unexpected public bundle entry: $unexpected_entry"

world_writable="$(find "$bundle_dir" -perm /022 -print -quit)"
[[ -z "$world_writable" ]] || fail "writable-by-group-or-other bundle entry: $world_writable"
broken_link="$(find "$bundle_dir" -xtype l -print -quit)"
[[ -z "$broken_link" ]] || fail "symlink is not allowed in public bundle: $broken_link"

[[ -s "${bundle_dir}/schweisos.gpg" ]] || fail 'binary public keyring is empty'
[[ -s "${bundle_dir}/schweisos-release.asc" ]] || fail 'armored public certificate is empty'
[[ -s "${bundle_dir}/schweisos-trusted" ]] || fail 'trusted owner record is empty'
[[ ! -s "${bundle_dir}/schweisos-revoked" ]] || \
  fail 'initial production bundle must not contain a revoked key'

if gpg --batch --list-packets "${bundle_dir}/schweisos.gpg" 2>&1 |
    grep -Eqi 'secret (sub)?key packet'; then
  fail 'public keyring contains secret key packets'
fi

metadata_value() {
  local key="$1"
  local metadata="${bundle_dir}/release-key-metadata.tsv"
  local count value
  count="$(awk -F '\t' -v key="$key" '$1 == key { count++ } END { print count + 0 }' "$metadata")"
  [[ "$count" == 1 ]] || fail "metadata key must appear exactly once: $key"
  value="$(awk -F '\t' -v key="$key" '$1 == key { sub(/^[^\t]*\t/, ""); print }' "$metadata")"
  [[ -n "$value" ]] || fail "metadata value is empty: $key"
  printf '%s\n' "$value"
}

[[ "$(metadata_value schema_version)" == 1 ]] || fail 'unsupported public bundle schema'
expected_uid='SchweisOS Release Authority <release@schweisos.org>'
[[ "$(metadata_value uid)" == "$expected_uid" ]] || fail 'unexpected release key UID'
[[ "$(metadata_value primary_validity)" == 10y ]] || fail 'unexpected primary validity policy'
[[ "$(metadata_value operational_validity)" == 1y ]] || fail 'unexpected operational validity policy'

metadata_keys="$({ awk -F '\t' '{ print $1 }' "${bundle_dir}/release-key-metadata.tsv"; } | sort)"
expected_metadata_keys="$({
  printf '%s\n' \
    created_utc \
    database_signing_fingerprint \
    operational_validity \
    package_signing_fingerprint \
    primary_fingerprint \
    primary_validity \
    schema_version \
    uid
} | sort)"
[[ "$metadata_keys" == "$expected_metadata_keys" ]] || \
  fail 'public key metadata contains missing, duplicate, or unexpected fields'

created_utc="$(metadata_value created_utc)"
[[ "$created_utc" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || \
  fail 'public key creation timestamp is not canonical UTC'

primary_fingerprint="$(metadata_value primary_fingerprint)"
package_fingerprint="$(metadata_value package_signing_fingerprint)"
database_fingerprint="$(metadata_value database_signing_fingerprint)"
for fingerprint in "$primary_fingerprint" "$package_fingerprint" "$database_fingerprint"; do
  [[ "$fingerprint" =~ ^[A-F0-9]{40}$ ]] || fail "invalid fingerprint: $fingerprint"
done
[[ "$primary_fingerprint" != "$package_fingerprint" \
  && "$primary_fingerprint" != "$database_fingerprint" \
  && "$package_fingerprint" != "$database_fingerprint" ]] || \
  fail 'key roles must use three distinct fingerprints'

mapfile -t key_records < <(
  gpg --batch --with-colons --show-keys "${bundle_dir}/schweisos.gpg" |
    awk -F: '
      $1 == "pub" || $1 == "sub" {
        kind = $1; algorithm = $4; created = $6; expires = $7; capabilities = $12; want = 1; next
      }
      want && $1 == "fpr" {
        print kind "|" $10 "|" algorithm "|" created "|" expires "|" capabilities
        want = 0
      }
    '
)
(( ${#key_records[@]} == 3 )) || \
  fail "expected one primary and two subkeys, found ${#key_records[@]} key records"

IFS='|' read -r primary_kind actual_primary primary_algorithm primary_created primary_expires primary_caps \
  <<<"${key_records[0]}"
IFS='|' read -r package_kind actual_package package_algorithm package_created package_expires package_caps \
  <<<"${key_records[1]}"
IFS='|' read -r database_kind actual_database database_algorithm database_created database_expires database_caps \
  <<<"${key_records[2]}"

[[ "$primary_kind" == pub && "$actual_primary" == "$primary_fingerprint" ]] || \
  fail 'primary fingerprint does not match public certificate'
[[ "$package_kind" == sub && "$actual_package" == "$package_fingerprint" ]] || \
  fail 'package-signing fingerprint does not match the first operational subkey'
[[ "$database_kind" == sub && "$actual_database" == "$database_fingerprint" ]] || \
  fail 'database-signing fingerprint does not match the second operational subkey'
[[ "$primary_algorithm" == 22 && "$package_algorithm" == 22 && "$database_algorithm" == 22 ]] || \
  fail 'all release keys must use Ed25519'
[[ "$primary_caps" == *[cC]* && "$primary_caps" != *[sS]* ]] || \
  fail 'offline primary must be certification-only'
[[ "$package_caps" == *[sS]* && "$package_caps" != *[cC]* ]] || \
  fail 'package operational subkey must be signing-only'
[[ "$database_caps" == *[sS]* && "$database_caps" != *[cC]* ]] || \
  fail 'database operational subkey must be signing-only'

primary_lifetime=$((primary_expires - primary_created))
package_lifetime=$((package_expires - package_created))
database_lifetime=$((database_expires - database_created))
(( primary_lifetime >= 283824000 && primary_lifetime <= 347155200 )) || \
  fail 'primary lifetime is outside the approved ten-year window'
for lifetime in "$package_lifetime" "$database_lifetime"; do
  (( lifetime >= 28512000 && lifetime <= 34560000 )) || \
    fail 'operational subkey lifetime is outside the approved one-year window'
done

mapfile -t public_uids < <(
  gpg --batch --with-colons --show-keys "${bundle_dir}/schweisos.gpg" |
    awk -F: '$1 == "uid" { print $10 }'
)
(( ${#public_uids[@]} == 1 )) || fail 'public certificate must contain exactly one UID'
decoded_uid="$(printf '%s' "${public_uids[0]}" | sed 's/\\x3a/:/g')"
[[ "$decoded_uid" == "$expected_uid" ]] || fail 'public certificate UID does not match policy'

armored_primary="$({
  gpg --batch --with-colons --show-keys "${bundle_dir}/schweisos-release.asc"
} | awk -F: '$1 == "pub" { want = 1; next } want && $1 == "fpr" { print $10; exit }')"
[[ "$armored_primary" == "$primary_fingerprint" ]] || \
  fail 'armored and binary public certificates differ'

[[ "$(<"${bundle_dir}/schweisos-trusted")" == "${primary_fingerprint}:4:" ]] || \
  fail 'trusted owner record does not contain exactly the primary fingerprint'

checksum_entries="$({ awk '{ print $2 }' "${bundle_dir}/SHA256SUMS"; } | sort)"
expected_checksum_entries="$({
  printf '%s\n' \
    release-key-metadata.tsv \
    schweisos-release.asc \
    schweisos-revoked \
    schweisos-trusted \
    schweisos.gpg
} | sort)"
[[ "$checksum_entries" == "$expected_checksum_entries" ]] || \
  fail 'public bundle checksum inventory is incomplete or unexpected'

(
  cd -- "$bundle_dir"
  sha256sum --check --strict --status SHA256SUMS
) || fail 'public bundle checksum verification failed'

temporary_home="$(mktemp -d)"
trap 'rm -rf -- "$temporary_home"' EXIT
chmod 0700 -- "$temporary_home"
gpg --batch --homedir "$temporary_home" --quiet --import "${bundle_dir}/schweisos.gpg"
if gpg --batch --homedir "$temporary_home" --with-colons --list-secret-keys |
    grep -Eq '^(sec|ssb):'; then
  fail 'public bundle imports secret key material'
fi

printf 'SchweisOS public signing bundle validation passed.\n'
printf '  primary:          %s\n' "$primary_fingerprint"
printf '  package signing:  %s\n' "$package_fingerprint"
printf '  database signing: %s\n' "$database_fingerprint"
