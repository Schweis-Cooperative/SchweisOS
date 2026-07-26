#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

public_bundle=''
gpg_dir='/etc/pacman.d/gnupg'
keyring_source_dir='/usr/share/pacman/keyrings'
initial_trust_acknowledged=false

usage() {
  cat <<'EOF'
Usage: bootstrap-pacman-trust.sh OPTIONS

Required:
  --public-bundle PATH
  --acknowledge-initial-trust

Optional:
  --gpg-dir PATH             Default: /etc/pacman.d/gnupg
  -h, --help

Import the repository-admitted SchweisOS public bundle into an already
initialized pacman keyring. The command performs a disposable-copy preflight,
mutates no Arch source keyring, and restores the complete pacman keyring if a
post-mutation check fails. It never initializes a keyring or uses a network.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --public-bundle) (( $# >= 2 )) || fail 'missing value for --public-bundle'; public_bundle="$2"; shift 2 ;;
    --gpg-dir) (( $# >= 2 )) || fail 'missing value for --gpg-dir'; gpg_dir="$2"; shift 2 ;;
    --acknowledge-initial-trust) initial_trust_acknowledged=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ -n "$public_bundle" ]] || fail '--public-bundle is required'
[[ "$initial_trust_acknowledged" == true ]] || fail '--acknowledge-initial-trust is required'
(( EUID == 0 )) || fail 'pacman trust bootstrap must run as root'

for tool in awk chmod cmp cp dirname find flock git gpg gpgconf grep mkdir mktemp pacman pacman-key readlink rm sha256sum sort stat; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
canonical_bundle="${project_root}/packages/schweisos-keyring/keys"
"${script_dir}/validate-admitted-public-bundle.sh" "$public_bundle"
canonical_bundle="$(readlink -f -- "$canonical_bundle")"
public_bundle="$(readlink -f -- "$public_bundle")"

[[ -d "$gpg_dir" && ! -L "$gpg_dir" ]] || fail 'pacman GnuPG directory is missing or unsafe'
gpg_dir="$(readlink -f -- "$gpg_dir")"
[[ "$gpg_dir" != / ]] || fail 'unsafe pacman GnuPG directory'
gpg_dir_mode="$(stat -c '%a' "$gpg_dir")"
[[ "$gpg_dir_mode" =~ ^[0-7]{3,4}$ ]] || fail 'pacman GnuPG directory mode is unreadable'
(( (8#$gpg_dir_mode & 8#022) == 0 )) || fail 'pacman GnuPG directory is group- or world-writable'
[[ "$(stat -c '%u' "$gpg_dir")" == 0 ]] || fail 'pacman GnuPG directory must be owned by root'
gpg_dir_parent="$(dirname -- "$gpg_dir")"
[[ -d "$gpg_dir_parent" && ! -L "$gpg_dir_parent" ]] || \
  fail 'pacman GnuPG parent directory is missing or unsafe'
[[ "$(stat -c '%u' "$gpg_dir_parent")" == 0 ]] || \
  fail 'pacman GnuPG parent directory must be owned by root'
gpg_dir_parent_mode="$(stat -c '%a' "$gpg_dir_parent")"
[[ "$gpg_dir_parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'pacman GnuPG parent mode is unreadable'
(( (8#$gpg_dir_parent_mode & 8#022) == 0 )) || \
  fail 'pacman GnuPG parent directory is group- or world-writable'

bootstrap_lock="${gpg_dir}.schweisos-bootstrap.lock"
[[ ! -L "$bootstrap_lock" ]] || fail 'pacman trust bootstrap lock is an unsafe symlink'
exec {bootstrap_lock_fd}>"$bootstrap_lock"
chmod 0600 -- "$bootstrap_lock"
flock -n "$bootstrap_lock_fd" || fail 'another pacman trust bootstrap is already in progress'

unsafe_pacman_entry="$(find "$gpg_dir" -mindepth 1 \( ! -user root -o -perm /022 \) -print -quit)"
[[ -z "$unsafe_pacman_entry" ]] || fail "unsafe pacman keyring ownership or mode: $unsafe_pacman_entry"

[[ -d "$keyring_source_dir" && ! -L "$keyring_source_dir" ]] || \
  fail 'pacman keyring source directory is missing or unsafe'
keyring_source_dir="$(readlink -f -- "$keyring_source_dir")"
[[ "$keyring_source_dir" == /usr/share/pacman/keyrings ]] || \
  fail 'Arch keyring source must use the canonical package-owned directory'
[[ "$(stat -c '%u' "$keyring_source_dir")" == 0 ]] || \
  fail 'Arch keyring source directory must be owned by root'
keyring_source_mode="$(stat -c '%a' "$keyring_source_dir")"
[[ "$keyring_source_mode" =~ ^[0-7]{3,4}$ ]] || fail 'Arch keyring source directory mode is unreadable'
(( (8#$keyring_source_mode & 8#022) == 0 )) || \
  fail 'Arch keyring source directory is group- or world-writable'
[[ -f "${gpg_dir}/pubring.gpg" || -f "${gpg_dir}/pubring.kbx" ]] || \
  fail 'pacman keyring is not initialized; this command will not run pacman-key --init'

metadata="${canonical_bundle}/release-key-metadata.tsv"
primary_fingerprint="$(awk -F '\t' '$1 == "primary_fingerprint" { print $2 }' "$metadata")"
[[ "$primary_fingerprint" =~ ^[A-F0-9]{40}$ ]] || fail 'admitted primary fingerprint is invalid'

mapfile -t arch_source_files < <(
  find "$keyring_source_dir" -maxdepth 1 -type f -name 'archlinux*' -print | sort
)
(( ${#arch_source_files[@]} > 0 )) || fail 'Arch keyring source files are unavailable'
for arch_source_file in "${arch_source_files[@]}"; do
  [[ -f "$arch_source_file" && ! -L "$arch_source_file" ]] || \
    fail "Arch keyring source is not a regular file: $arch_source_file"
  [[ "$(stat -c '%u' "$arch_source_file")" == 0 ]] || \
    fail "Arch keyring source is not owned by root: $arch_source_file"
  arch_source_mode="$(stat -c '%a' "$arch_source_file")"
  [[ "$arch_source_mode" =~ ^[0-7]{3,4}$ ]] || fail 'Arch keyring source mode is unreadable'
  (( (8#$arch_source_mode & 8#022) == 0 )) || \
    fail "Arch keyring source is group- or world-writable: $arch_source_file"
  [[ "$(pacman -Qqo -- "$arch_source_file" 2>/dev/null)" == archlinux-keyring ]] || \
    fail "Arch keyring source is not owned by archlinux-keyring: $arch_source_file"
done
mapfile -t arch_fingerprints < <(
  gpg --batch --with-colons --show-keys "${keyring_source_dir}/archlinux.gpg" 2>/dev/null |
    awk -F: '
      $1 == "pub" { want = 1; next }
      want && $1 == "fpr" { print $10; want = 0 }
    ' | sort -u
)
(( ${#arch_fingerprints[@]} > 0 )) || fail 'Arch public fingerprint inventory is empty'

validate_pacman_home() {
  local home="$1"
  local require_release_trust="$2"
  local local_master_count local_master_uid release_validity fingerprint
  local -a schweisos_fingerprints local_master_fingerprints installed_primary_fingerprints
  local -A allowed_primary_fingerprints=()

  mapfile -t local_master_fingerprints < <(
    gpg --batch --homedir "$home" --with-colons --list-secret-keys 2>/dev/null |
      awk -F: '
        $1 == "sec" { want = 1; next }
        want && $1 == "fpr" { print $10; want = 0 }
      ' | sort -u
  )
  local_master_count="${#local_master_fingerprints[@]}"
  (( local_master_count == 1 )) || \
    fail 'canonical pacman keyring must contain exactly one local trust root'
  local_master_uid="$(
    gpg --batch --homedir "$home" --with-colons \
      --list-keys "${local_master_fingerprints[0]}" 2>/dev/null |
      awk -F: '$1 == "uid" { print $10 }'
  )"
  [[ "$local_master_uid" == 'Pacman Keyring Master Key <pacman@localhost>' ]] || \
    fail 'pacman local trust root has a noncanonical identity'

  if gpg --batch --homedir "$home" --with-colons --list-secret-keys "$primary_fingerprint" 2>/dev/null |
      awk -F: '$1 == "sec" || $1 == "ssb" { found = 1 } END { exit !found }'; then
    fail 'SchweisOS release secret material is present in the pacman keyring'
  fi

  mapfile -t schweisos_fingerprints < <(
    gpg --batch --homedir "$home" --with-colons --list-keys 2>/dev/null |
      awk -F: '
        $1 == "pub" { primary = ""; want = 1; next }
        want && $1 == "fpr" { primary = $10; want = 0; next }
        $1 == "uid" && tolower($10) ~ /schweisos/ && primary != "" { print primary }
      ' | sort -u
  )
  for fingerprint in "${schweisos_fingerprints[@]}"; do
    [[ "$fingerprint" == "$primary_fingerprint" ]] || \
      fail "non-production SchweisOS trust is present in pacman: $fingerprint"
  done

  for fingerprint in "${arch_fingerprints[@]}"; do
    gpg --batch --homedir "$home" --list-keys "$fingerprint" >/dev/null 2>&1 || \
      fail "Arch trust entry is missing: $fingerprint"
    allowed_primary_fingerprints["$fingerprint"]=1
  done
  for fingerprint in "${local_master_fingerprints[@]}"; do
    allowed_primary_fingerprints["$fingerprint"]=1
  done
  allowed_primary_fingerprints["$primary_fingerprint"]=1

  mapfile -t installed_primary_fingerprints < <(
    gpg --batch --homedir "$home" --with-colons --list-keys 2>/dev/null |
      awk -F: '
        $1 == "pub" { want = 1; next }
        want && $1 == "fpr" { print $10; want = 0 }
      ' | sort -u
  )
  for fingerprint in "${installed_primary_fingerprints[@]}"; do
    [[ -n "${allowed_primary_fingerprints[$fingerprint]-}" ]] || \
      fail "pacman keyring contains an unauthorized primary certificate: $fingerprint"
  done

  if [[ "$require_release_trust" == true ]]; then
    release_validity="$(
      gpg --batch --homedir "$home" --with-colons --list-keys "$primary_fingerprint" 2>/dev/null |
        awk -F: -v fpr="$primary_fingerprint" '
          $1 == "pub" { validity = $2; want = 1; next }
          want && $1 == "fpr" && $10 == fpr { print validity; exit }
        '
    )"
    [[ "$release_validity" == f || "$release_validity" == u ]] || \
      fail 'SchweisOS primary certificate did not receive trusted pacman validity'
  fi
}

validate_pacman_home "$gpg_dir" false
gpgconf --homedir "$gpg_dir" --kill all >/dev/null 2>&1 || true
active_socket="$(find "$gpg_dir" -type s -print -quit)"
[[ -z "$active_socket" ]] || fail "pacman keyring contains an active GnuPG socket: $active_socket"

state_parent="$(dirname -- "$gpg_dir")"
state_workspace="$(mktemp -d --tmpdir="$state_parent" .schweisos-trust-bootstrap.XXXXXX)"
chmod 0700 "$state_workspace"
backup_home="${state_workspace}/backup"
preflight_home="${state_workspace}/preflight"
mkdir -m 0700 "$backup_home" "$preflight_home"
cp -a -- "$gpg_dir/." "$backup_home/"
cp -a -- "$gpg_dir/." "$preflight_home/"
source_snapshot="${state_workspace}/archlinux-source.SHA256SUMS"
sha256sum "${arch_source_files[@]}" >"$source_snapshot"

mutation_started=false
bootstrap_complete=false
cleanup() {
  local status=$?
  local rollback_complete=true
  if [[ "$mutation_started" == true && "$bootstrap_complete" == false ]]; then
    gpgconf --homedir "$gpg_dir" --kill all >/dev/null 2>&1 || true
    if ! find "$gpg_dir" -mindepth 1 -delete \
      || ! cp -a -- "$backup_home/." "$gpg_dir/"; then
      rollback_complete=false
      printf 'ERROR: pacman trust rollback failed; protected backup retained at %s\n' "$backup_home" >&2
    fi
  fi
  if [[ "$rollback_complete" == true ]]; then
    rm -rf -- "$state_workspace"
  fi
  exit "$status"
}
trap cleanup EXIT

pacman-key \
  --gpgdir "$preflight_home" \
  --populate-from "$canonical_bundle" \
  --populate schweisos
validate_pacman_home "$preflight_home" true

mutation_started=true
pacman-key \
  --gpgdir "$gpg_dir" \
  --populate-from "$canonical_bundle" \
  --populate schweisos
sha256sum --check --strict --status "$source_snapshot" || \
  fail 'Arch keyring source files changed during SchweisOS trust bootstrap'
validate_pacman_home "$gpg_dir" true
bootstrap_complete=true

printf 'SchweisOS pacman trust bootstrap passed.\n'
printf '  primary fingerprint: %s\n' "$primary_fingerprint"
printf '  trust validity: fully trusted\n'
printf '  Arch keyring sources: unchanged\n'
printf '  rollback preflight: passed\n'
