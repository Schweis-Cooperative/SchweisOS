#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

public_bundle=''
gnupg_home=''
package_export=''
database_export=''
restricted_host_acknowledged=false

usage() {
  cat <<'EOF'
Usage: import-operational-subkeys.sh OPTIONS

Required options:
  --public-bundle PATH
  --gnupg-home PATH
  --package-export PATH
  --database-export PATH
  --acknowledge-restricted-host
  -h, --help

Run only on the dedicated restricted signing host. The GnuPG home must be new
or empty and outside the source repository. The command imports only the two
ceremony-exported operational subkeys and validates the unusable primary stub.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --public-bundle) (( $# >= 2 )) || fail 'missing value for --public-bundle'; public_bundle="$2"; shift 2 ;;
    --gnupg-home) (( $# >= 2 )) || fail 'missing value for --gnupg-home'; gnupg_home="$2"; shift 2 ;;
    --package-export) (( $# >= 2 )) || fail 'missing value for --package-export'; package_export="$2"; shift 2 ;;
    --database-export) (( $# >= 2 )) || fail 'missing value for --database-export'; database_export="$2"; shift 2 ;;
    --acknowledge-restricted-host) restricted_host_acknowledged=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ -n "$public_bundle" && -n "$gnupg_home" && -n "$package_export" && -n "$database_export" ]] || \
  fail 'all path options are required'
[[ "$restricted_host_acknowledged" == true ]] || fail '--acknowledge-restricted-host is required'
(( EUID != 0 )) || fail 'operational subkeys must not be imported as root'
umask 077

for tool in awk chmod dirname find git gpg gpgconf mkdir mktemp mv readlink realpath rm rmdir stat; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
"${script_dir}/validate-admitted-public-bundle.sh" "$public_bundle"
public_bundle="$(readlink -f -- "$public_bundle")"

for exported_subkey in "$package_export" "$database_export"; do
  [[ -f "$exported_subkey" && ! -L "$exported_subkey" && -s "$exported_subkey" ]] || \
    fail 'operational subkey export is missing, empty, or unsafe'
done
package_export="$(readlink -f -- "$package_export")"
database_export="$(readlink -f -- "$database_export")"
[[ "$package_export" != "$database_export" ]] || fail 'operational role exports must be separate files'

validate_export_custody() {
  local exported_subkey="$1"
  local export_parent mode parent_mode

  [[ "$exported_subkey" != "$project_root" && "$exported_subkey" != "$project_root"/* ]] || \
    fail 'operational secret export must remain outside the source repository'
  [[ "$(stat -c '%u' "$exported_subkey")" == "$EUID" ]] || \
    fail 'operational secret export must be owned by the invoking signing user'
  mode="$(stat -c '%a' "$exported_subkey")"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || fail 'operational secret export mode is unreadable'
  (( (8#$mode & 8#077) == 0 )) || \
    fail 'operational secret export must not grant group or other permissions'
  export_parent="$(dirname -- "$exported_subkey")"
  [[ -d "$export_parent" && ! -L "$export_parent" ]] || fail 'unsafe operational export parent'
  [[ "$(stat -c '%u' "$export_parent")" == "$EUID" ]] || \
    fail 'operational export parent must be owned by the invoking signing user'
  parent_mode="$(stat -c '%a' "$export_parent")"
  [[ "$parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'operational export parent mode is unreadable'
  (( (8#$parent_mode & 8#077) == 0 )) || \
    fail 'operational export parent must not grant group or other permissions'
}
validate_export_custody "$package_export"
validate_export_custody "$database_export"

gnupg_home="$(realpath -m -- "$gnupg_home")"
[[ "$gnupg_home" != "$project_root" && "$gnupg_home" != "$project_root"/* ]] || \
  fail 'signing GnuPG home must remain outside the source repository'
gnupg_parent="$(dirname -- "$gnupg_home")"
mkdir -p -- "$gnupg_parent"
[[ -d "$gnupg_parent" && ! -L "$gnupg_parent" ]] || fail 'unsafe signing GnuPG parent directory'
[[ "$(stat -c '%u' "$gnupg_parent")" == "$EUID" ]] || \
  fail 'signing GnuPG parent must be owned by the invoking signing user'
gnupg_parent_mode="$(stat -c '%a' "$gnupg_parent")"
[[ "$gnupg_parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'signing GnuPG parent mode is unreadable'
(( (8#$gnupg_parent_mode & 8#077) == 0 )) || \
  fail 'signing GnuPG parent must not grant group or other permissions'
original_empty_home=false
if [[ -e "$gnupg_home" ]]; then
  [[ -d "$gnupg_home" && ! -L "$gnupg_home" ]] || fail 'unsafe signing GnuPG home type'
  [[ -z "$(find "$gnupg_home" -mindepth 1 -print -quit)" ]] || fail 'signing GnuPG home must be empty'
  rmdir -- "$gnupg_home"
  original_empty_home=true
fi

staged_home="$(mktemp -d --tmpdir="$gnupg_parent" .schweisos-signing-home.XXXXXX)"
chmod 0700 -- "$staged_home"
import_complete=false
home_published=false
cleanup() {
  local status=$?
  if [[ "$import_complete" == false ]]; then
    if [[ "$home_published" == true ]]; then
      gpgconf --homedir "$gnupg_home" --kill all >/dev/null 2>&1 || true
      rm -rf -- "$gnupg_home"
    else
      gpgconf --homedir "$staged_home" --kill all >/dev/null 2>&1 || true
      rm -rf -- "$staged_home"
    fi
    if [[ "$original_empty_home" == true && ! -e "$gnupg_home" ]]; then
      mkdir -m 0700 -- "$gnupg_home"
    fi
  fi
  exit "$status"
}
trap cleanup EXIT

metadata="${public_bundle}/release-key-metadata.tsv"
primary_fingerprint="$(awk -F '\t' '$1 == "primary_fingerprint" { print $2 }' "$metadata")"
package_fingerprint="$(awk -F '\t' '$1 == "package_signing_fingerprint" { print $2 }' "$metadata")"
database_fingerprint="$(awk -F '\t' '$1 == "database_signing_fingerprint" { print $2 }' "$metadata")"

gpg --batch --homedir "$staged_home" --import "$package_export"
gpg --batch --homedir "$staged_home" --import "$database_export"
"${script_dir}/validate-signing-home.sh" "$public_bundle" "$staged_home"
gpgconf --homedir "$staged_home" --kill all >/dev/null 2>&1 || true
active_socket="$(find "$staged_home" -type s -print -quit)"
[[ -z "$active_socket" ]] || fail "staged signing home contains an active GnuPG socket: $active_socket"
mv -T -- "$staged_home" "$gnupg_home"
home_published=true
"${script_dir}/validate-signing-home.sh" "$public_bundle" "$gnupg_home"
import_complete=true
trap - EXIT

printf 'Operational signing material imported and validated.\n'
printf '  primary:          unusable offline stub (%s)\n' "$primary_fingerprint"
printf '  package signing:  %s\n' "$package_fingerprint"
printf '  database signing: %s\n' "$database_fingerprint"
printf 'After an independent smoke-signing test, unmount and return the encrypted transfer medium to offline custody.\n'
