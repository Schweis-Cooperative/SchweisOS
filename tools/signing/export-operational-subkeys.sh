#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

public_bundle=''
offline_home=''
output_dir=''
airgap_acknowledged=false
encrypted_media_acknowledged=false

usage() {
  cat <<'EOF'
Usage: export-operational-subkeys.sh OPTIONS

Export the package and repository-database signing subkeys from the canonical
offline GnuPG home. Run only on the physically offline ceremony host.

Required options:
  --public-bundle PATH
  --offline-gnupg-home PATH
  --output-dir PATH
  --acknowledge-airgapped
  --acknowledge-encrypted-media
  -h, --help

The output directory must be new, outside the source repository, and located
on LUKS-backed removable media. The offline primary is exported only as the
non-secret certificate stub created by GnuPG's --export-secret-subkeys.
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
      airgap_acknowledged=true
      shift
      ;;
    --acknowledge-encrypted-media)
      encrypted_media_acknowledged=true
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
[[ "$airgap_acknowledged" == true ]] || fail '--acknowledge-airgapped is required'
[[ "$encrypted_media_acknowledged" == true ]] || \
  fail '--acknowledge-encrypted-media is required after physical media review'
(( EUID != 0 )) || fail 'operational subkey export must not run as root'
[[ -z "${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-}" ]] || \
  fail 'operational subkey export must not run through SSH'

for tool in awk find findmnt git gpg grep ip lsblk mkdir mktemp networkctl realpath rm sort systemd-detect-virt; do
  require_tool "$tool"
done

os_release=/etc/os-release
[[ -r "$os_release" ]] || os_release=/usr/lib/os-release
[[ -r "$os_release" ]] || fail 'cannot read the ceremony host os-release'
unset ID
# shellcheck disable=SC1090
source "$os_release"
[[ "${ID-}" == arch ]] || fail 'the ceremony host must be canonical Arch Linux'

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

"${script_dir}/validate-public-bundle.sh" "$public_bundle"
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
  --output "${output_dir}/package-signing-subkey.asc" \
  --export-secret-subkeys "${package_fingerprint}!"
gpg --homedir "$offline_home" --armor \
  --output "${output_dir}/database-signing-subkey.asc" \
  --export-secret-subkeys "${database_fingerprint}!"

for exported_subkey in \
  "${output_dir}/package-signing-subkey.asc" \
  "${output_dir}/database-signing-subkey.asc"; do
  [[ -s "$exported_subkey" && ! -L "$exported_subkey" ]] || \
    fail 'GnuPG did not create the expected operational subkey export'
  chmod 0600 -- "$exported_subkey"
done

verify_exported_role() {
  local exported_file="$1"
  local expected_fingerprint="$2"
  local verification_home
  local -a secret_subkeys

  verification_home="$(mktemp -d --tmpdir="$output_dir" .verify-export.XXXXXX)"
  chmod 0700 -- "$verification_home"
  gpg --batch --homedir "$verification_home" --quiet --import "$exported_file"
  mapfile -t secret_subkeys < <(
    gpg --batch --homedir "$verification_home" --with-colons --list-secret-keys |
      awk -F: '$1 == "ssb" { want = 1; next } want && $1 == "fpr" { print $10; want = 0 }'
  )
  rm -rf -- "$verification_home"
  (( ${#secret_subkeys[@]} == 1 )) || \
    fail 'operational export must contain exactly one secret subkey'
  [[ "${secret_subkeys[0]}" == "$expected_fingerprint" ]] || \
    fail 'operational export contains the wrong secret subkey'
}

verify_exported_role \
  "${output_dir}/package-signing-subkey.asc" "$package_fingerprint"
verify_exported_role \
  "${output_dir}/database-signing-subkey.asc" "$database_fingerprint"

printf 'Operational subkey exports created on encrypted transfer media.\n'
printf '  package role:  %s\n' "$package_fingerprint"
printf '  database role: %s\n' "$database_fingerprint"
printf 'Import each file only into the restricted signing home, verify both roles,\n'
printf 'then securely erase the transfer copies. Never transfer the offline primary.\n'
