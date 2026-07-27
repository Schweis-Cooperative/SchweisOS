#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

public_bundle=''
offline_home=''
output_dir=''
physical_airgap_acknowledged=false
encrypted_output_acknowledged=false
package_export=''
database_export=''

usage() {
  cat <<'EOF'
Usage: export-operational-subkeys.sh OPTIONS

Export the package and repository-database signing subkeys from the canonical
offline GnuPG home. Run only during a reviewed local ceremony with no visible
non-loopback network connectivity and physically removed or disabled network
capability.

Required options:
  --public-bundle PATH
  --offline-gnupg-home PATH
  --output-dir PATH
  --acknowledge-airgapped
  --acknowledge-encrypted-output
  --acknowledge-encrypted-media
  -h, --help

The output directory must be new, outside the source repository, and located
on LUKS-backed storage. Separate removable media is strongly recommended. The
offline primary is exported only as the non-secret certificate stub created by
GnuPG's --export-secret-subkeys.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

require_luks_backing() {
  local path="$1"
  local label="$2"
  local source

  source="$(findmnt -n -o SOURCE -T "$path")"
  source="${source%%\[*}"
  [[ -b "$source" ]] || fail "$label must be on a block-backed encrypted filesystem"
  lsblk -snro TYPE -- "$source" | grep -Fxq crypt || \
    fail "$label must be stored on a LUKS-backed filesystem"
}

while (( $# > 0 )); do
  case "$1" in
    --public-bundle)
      (( $# >= 2 )) || fail 'missing value for --public-bundle'
      public_bundle="$2"
      shift 2
      ;;
    --offline-gnupg-home)
      (( $# >= 2 )) || fail 'missing value for --offline-gnupg-home'
      offline_home="$2"
      shift 2
      ;;
    --output-dir)
      (( $# >= 2 )) || fail 'missing value for --output-dir'
      output_dir="$2"
      shift 2
      ;;
    --acknowledge-airgapped)
      physical_airgap_acknowledged=true
      shift
      ;;
    --acknowledge-encrypted-output)
      encrypted_output_acknowledged=true
      shift
      ;;
    --acknowledge-encrypted-media)
      encrypted_output_acknowledged=true
      shift
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

[[ -n "$public_bundle" && -n "$offline_home" && -n "$output_dir" ]] || \
  fail 'all path options are required'
[[ "$physical_airgap_acknowledged" == true ]] || \
  fail '--acknowledge-airgapped is required after physical air-gap review'
[[ "$encrypted_output_acknowledged" == true ]] || \
  fail '--acknowledge-encrypted-output or --acknowledge-encrypted-media is required'
(( EUID != 0 )) || fail 'operational subkey export must not run as root'
[[ -z "${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-}" ]] || \
  fail 'operational subkey export must not run through SSH'

for tool in awk chmod find findmnt git gpg grep ip lsblk mkdir mktemp networkctl realpath rm sort systemd-detect-virt; do
  require_tool "$tool"
done

systemd-detect-virt --quiet && \
  fail 'operational subkey export must not run inside virtualization or a container'
[[ -z "$(ip -o -4 route show default; ip -o -6 route show default)" ]] || \
  fail 'a default network route is active'
[[ -z "$(ip -o address show scope global)" ]] || \
  fail 'a global network address is configured'
networkctl_state="$(networkctl --no-pager --no-legend list 2>/dev/null)" || \
  fail 'networkctl could not verify the host network state'
mapfile -t networkctl_online_links < <(
  awk '$2 != "lo" && $4 ~ /^(carrier|degraded|degraded-carrier|enslaved|routable)$/ { print $2 ":" $4 }' \
    <<<"$networkctl_state" | sort -u
)
(( ${#networkctl_online_links[@]} == 0 )) || \
  fail "networkctl reports an online non-loopback link: ${networkctl_online_links[*]}"
mapfile -t active_interfaces < <(
  ip -o link show up | awk -F': ' '$2 != "lo" {sub(/@.*/, "", $2); print $2}' | sort -u
)
(( ${#active_interfaces[@]} == 0 )) || \
  fail "non-loopback interface is active: ${active_interfaces[*]}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
public_bundle="$(realpath -e -- "$public_bundle")"
offline_home="$(realpath -e -- "$offline_home")"
output_dir="$(realpath -m -- "$output_dir")"

[[ -d "$offline_home" && ! -L "$offline_home" ]] || fail 'unsafe offline GnuPG home'
for private_path in "$offline_home" "$output_dir"; do
  [[ "$private_path" != "$project_root" && "$private_path" != "$project_root"/* ]] || \
    fail 'private signing material must remain outside the source repository'
done
[[ "$offline_home" != "$output_dir" ]] || fail 'offline home and transfer output must differ'

if [[ -e "$output_dir" ]]; then
  [[ -d "$output_dir" && ! -L "$output_dir" ]] || fail 'unsafe output directory type'
  [[ -z "$(find "$output_dir" -mindepth 1 -print -quit)" ]] || \
    fail 'output directory must be new or empty'
else
  mkdir -m 0700 -- "$output_dir"
fi
chmod 0700 -- "$output_dir"
require_luks_backing "$offline_home" 'offline GnuPG home'
require_luks_backing "$output_dir" 'operational subkey transfer output'
package_export="${output_dir}/package-role.secret-subkeys.asc"
database_export="${output_dir}/database-role.secret-subkeys.asc"

/usr/bin/bash "${script_dir}/validate-public-bundle.sh" "$public_bundle"
metadata="${public_bundle}/release-key-metadata.tsv"
metadata_value() {
  local key="$1"
  awk -F '\t' -v key="$key" '$1 == key { print $2 }' "$metadata"
}
primary_fingerprint="$(metadata_value primary_fingerprint)"
package_fingerprint="$(metadata_value package_signing_fingerprint)"
database_fingerprint="$(metadata_value database_signing_fingerprint)"

for fingerprint in "$primary_fingerprint" "$package_fingerprint" "$database_fingerprint"; do
  [[ "$fingerprint" =~ ^[A-F0-9]{40}$ ]] || fail 'invalid authorized fingerprint'
done

for signing_fingerprint in "$package_fingerprint" "$database_fingerprint"; do
  gpg --batch --homedir "$offline_home" --list-secret-keys \
    "${signing_fingerprint}!" >/dev/null 2>&1 || \
    fail "authorized operational secret subkey is unavailable: $signing_fingerprint"
done
gpg --batch --homedir "$offline_home" --list-secret-keys \
  "${primary_fingerprint}!" >/dev/null 2>&1 || fail 'offline primary secret key is unavailable'

umask 077
gpg --homedir "$offline_home" --armor \
  --output "$package_export" \
  --export-secret-subkeys "${package_fingerprint}!"
gpg --homedir "$offline_home" --armor \
  --output "$database_export" \
  --export-secret-subkeys "${database_fingerprint}!"

for exported_subkey in \
  "$package_export" \
  "$database_export"; do
  [[ -s "$exported_subkey" && ! -L "$exported_subkey" ]] || \
    fail 'GnuPG did not create the expected operational subkey export'
  chmod 0600 -- "$exported_subkey"
done

verify_exported_role() {
  local exported_file="$1"
  local expected_fingerprint="$2"
  (
    local verification_home
    local -a secret_records
    local primary_kind exported_primary primary_storage
    local subkey_kind exported_subkey subkey_storage

    verification_home="$(mktemp -d --tmpdir="$output_dir" .verify-export.XXXXXX)"
    trap 'rm -rf -- "$verification_home"' EXIT
    chmod 0700 -- "$verification_home"
    gpg --batch --homedir "$verification_home" --quiet --import "$exported_file"
    mapfile -t secret_records < <(
      gpg --batch --homedir "$verification_home" --with-colons --list-secret-keys |
        awk -F: '
          $1 == "sec" || $1 == "ssb" {
            kind = $1; storage = $15; want = 1; next
          }
          want && $1 == "fpr" {
            print kind "|" $10 "|" storage
            want = 0
          }
        '
    )
    (( ${#secret_records[@]} == 2 )) || \
      fail 'operational export must contain one primary stub and one secret subkey'
    IFS='|' read -r primary_kind exported_primary primary_storage <<<"${secret_records[0]}"
    IFS='|' read -r subkey_kind exported_subkey subkey_storage <<<"${secret_records[1]}"
    [[ "$primary_kind" == sec && "$exported_primary" == "$primary_fingerprint" \
      && "$primary_storage" == '#' ]] || \
      fail 'operational export contains usable offline primary material'
    [[ "$subkey_kind" == ssb && "$exported_subkey" == "$expected_fingerprint" \
      && -n "$subkey_storage" && "$subkey_storage" != '#' ]] || \
      fail 'operational export contains the wrong or unavailable secret subkey'
  )
}

verify_exported_role \
  "$package_export" "$package_fingerprint"
verify_exported_role \
  "$database_export" "$database_fingerprint"

printf 'Operational subkey exports created on encrypted transfer storage.\n'
printf '  package role:  %s\n' "$package_fingerprint"
printf '  database role: %s\n' "$database_fingerprint"
printf 'Import each file only into the restricted signing home, verify both roles,\n'
printf 'then unmount and return the encrypted medium to offline custody without reuse.\n'
printf 'Never transfer the offline primary.\n'
