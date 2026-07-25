#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

release_uid='SchweisOS Release Authority <release@schweisos.org>'
primary_validity='10y'
operational_validity='1y'
gnupg_home=''
public_output=''
airgap_acknowledged=false

usage() {
  cat <<'EOF'
Usage: create-offline-release-key.sh OPTIONS

Create the canonical SchweisOS offline release primary and operational signing
subkeys. Run only during the reviewed ceremony on a physically offline Arch
Linux host.

Required options:
  --gnupg-home PATH          New private GnuPG home on encrypted offline media
  --public-output PATH       New directory for public-only ceremony output
  --acknowledge-airgapped    Confirm physical network isolation was reviewed
  -h, --help                 Show this help

The command intentionally has no passphrase option. GnuPG uses pinentry.
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
    --gnupg-home)
      (( $# >= 2 )) || fail 'missing value for --gnupg-home'
      gnupg_home="$2"
      shift 2
      ;;
    --public-output)
      (( $# >= 2 )) || fail 'missing value for --public-output'
      public_output="$2"
      shift 2
      ;;
    --acknowledge-airgapped)
      airgap_acknowledged=true
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

[[ -n "$gnupg_home" ]] || fail '--gnupg-home is required'
[[ -n "$public_output" ]] || fail '--public-output is required'
[[ "$airgap_acknowledged" == true ]] || \
  fail '--acknowledge-airgapped is required after physical isolation review'
(( EUID != 0 )) || fail 'the offline key ceremony must not run as root'
[[ -z "${SSH_CONNECTION-}${SSH_CLIENT-}${SSH_TTY-}" ]] || \
  fail 'the offline key ceremony must not run through SSH'

for tool in awk date find findmnt git gpg grep ip lsblk mkdir mktemp realpath sha256sum sort stat systemd-detect-virt; do
  require_tool "$tool"
done

os_release=/etc/os-release
[[ -r "$os_release" ]] || os_release=/usr/lib/os-release
[[ -r "$os_release" ]] || fail 'cannot read the build host os-release'
unset ID
# shellcheck disable=SC1090
source "$os_release"
[[ "${ID-}" == arch ]] || fail 'the ceremony host must be canonical Arch Linux'

if systemd-detect-virt --quiet; then
  fail 'the offline key ceremony must not run inside virtualization or a container'
fi

if [[ -n "$(ip -o -4 route show default; ip -o -6 route show default)" ]]; then
  fail 'a default network route is active'
fi
if [[ -n "$(ip -o address show scope global)" ]]; then
  fail 'a global network address is configured'
fi
mapfile -t active_interfaces < <(
  ip -o link show up | awk -F': ' '$2 != "lo" {sub(/@.*/, "", $2); print $2}' | sort -u
)
(( ${#active_interfaces[@]} == 0 )) || \
  fail "non-loopback interface is active: ${active_interfaces[*]}"

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
gnupg_home="$(realpath -m -- "$gnupg_home")"
public_output="$(realpath -m -- "$public_output")"

for protected_path in "$gnupg_home" "$public_output"; do
  [[ "$protected_path" != "$project_root" && "$protected_path" != "$project_root"/* ]] || \
    fail 'ceremony private state and initial public output must remain outside the repository'
done
[[ "$gnupg_home" != "$public_output" ]] || \
  fail 'private GnuPG home and public output must be separate directories'

if [[ -e "$gnupg_home" ]]; then
  [[ -d "$gnupg_home" && ! -L "$gnupg_home" ]] || \
    fail 'existing GnuPG home has an unsafe file type'
  [[ -z "$(find "$gnupg_home" -mindepth 1 -print -quit)" ]] || \
    fail 'GnuPG home must be new or empty'
else
  mkdir -m 0700 -- "$gnupg_home"
fi

if [[ -e "$public_output" ]]; then
  [[ -d "$public_output" && ! -L "$public_output" ]] || \
    fail 'existing public output has an unsafe file type'
  [[ -z "$(find "$public_output" -mindepth 1 -print -quit)" ]] || \
    fail 'public output must be new or empty'
else
  mkdir -m 0755 -- "$public_output"
fi

chmod 0700 -- "$gnupg_home"
umask 077

private_mount_source="$(findmnt -n -o SOURCE -T "$gnupg_home")"
private_mount_source="${private_mount_source%%\[*}"
[[ -b "$private_mount_source" ]] || \
  fail 'private GnuPG home must be on a block-backed encrypted filesystem'
if ! lsblk -snro TYPE -- "$private_mount_source" | grep -Fxq crypt; then
  fail 'private GnuPG home must be stored on a LUKS-backed filesystem'
fi

printf 'Creating certification-only offline primary. Pinentry will request a new passphrase.\n'
gpg --homedir "$gnupg_home" \
  --quick-generate-key "$release_uid" ed25519 cert "$primary_validity"

primary_fingerprint="$({
  gpg --homedir "$gnupg_home" --batch --with-colons --list-keys "$release_uid"
} | awk -F: '$1 == "pub" { want = 1; next } want && $1 == "fpr" { print $10; exit }')"
[[ "$primary_fingerprint" =~ ^[A-F0-9]{40}$ ]] || \
  fail 'could not determine the primary fingerprint'

printf 'Creating package-signing operational subkey.\n'
gpg --homedir "$gnupg_home" \
  --quick-add-key "$primary_fingerprint" ed25519 sign "$operational_validity"
printf 'Creating repository-database-signing operational subkey.\n'
gpg --homedir "$gnupg_home" \
  --quick-add-key "$primary_fingerprint" ed25519 sign "$operational_validity"

mapfile -t subkey_fingerprints < <(
  gpg --homedir "$gnupg_home" --batch --with-colons --list-keys "$primary_fingerprint" |
    awk -F: '$1 == "sub" { want = 1; next } want && $1 == "fpr" { print $10; want = 0 }'
)
(( ${#subkey_fingerprints[@]} == 2 )) || \
  fail "expected exactly two operational signing subkeys, found ${#subkey_fingerprints[@]}"
package_fingerprint="${subkey_fingerprints[0]}"
database_fingerprint="${subkey_fingerprints[1]}"

revocation_certificate="${gnupg_home}/openpgp-revocs.d/${primary_fingerprint}.rev"
[[ -f "$revocation_certificate" && ! -L "$revocation_certificate" ]] || \
  fail 'GnuPG did not create the primary revocation certificate'

gpg --homedir "$gnupg_home" --batch --yes \
  --export-options export-minimal \
  --output "${public_output}/schweisos.gpg" \
  --export "$primary_fingerprint"
gpg --homedir "$gnupg_home" --batch --yes --armor \
  --export-options export-minimal \
  --output "${public_output}/schweisos-release.asc" \
  --export "$primary_fingerprint"

printf '%s:4:\n' "$primary_fingerprint" >"${public_output}/schweisos-trusted"
: >"${public_output}/schweisos-revoked"
{
  printf 'schema_version\t1\n'
  printf 'uid\t%s\n' "$release_uid"
  printf 'primary_fingerprint\t%s\n' "$primary_fingerprint"
  printf 'package_signing_fingerprint\t%s\n' "$package_fingerprint"
  printf 'database_signing_fingerprint\t%s\n' "$database_fingerprint"
  printf 'primary_validity\t%s\n' "$primary_validity"
  printf 'operational_validity\t%s\n' "$operational_validity"
  printf 'created_utc\t%s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
} >"${public_output}/release-key-metadata.tsv"

chmod 0644 -- "${public_output}"/*
(
  cd -- "$public_output"
  sha256sum \
    release-key-metadata.tsv \
    schweisos-release.asc \
    schweisos-revoked \
    schweisos-trusted \
    schweisos.gpg >SHA256SUMS
)
chmod 0644 -- "${public_output}/SHA256SUMS"

"${script_dir}/validate-public-bundle.sh" "$public_output"

printf '\nOffline key ceremony public output created.\n'
printf '  primary:            %s\n' "$primary_fingerprint"
printf '  package signing:    %s\n' "$package_fingerprint"
printf '  database signing:   %s\n' "$database_fingerprint"
printf '  public output:      %s\n' "$public_output"
printf '  private state:      retained only in the operator-selected offline GnuPG home\n'
printf '\nDo not reconnect this host while the offline GnuPG home is mounted.\n'
