#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

repository='schweisos'
repository_dir=''
public_bundle=''

usage() {
  cat <<'EOF'
Usage: validate-signed-repository-client.sh OPTIONS

Required:
  --repository-dir PATH
  --public-bundle PATH

Optional:
  --repository schweisos|schweisos-testing|schweisos-staging
  -h, --help

Creates a disposable pacman root and local pacman trust root, synchronizes only
from the supplied file repository, and verifies every downloaded package. It
never reads or changes host pacman configuration or host keyrings.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --repository-dir) (( $# >= 2 )) || fail 'missing value for --repository-dir'; repository_dir="$2"; shift 2 ;;
    --public-bundle) (( $# >= 2 )) || fail 'missing value for --public-bundle'; public_bundle="$2"; shift 2 ;;
    --repository) (( $# >= 2 )) || fail 'missing value for --repository'; repository="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
case "$repository" in schweisos|schweisos-testing|schweisos-staging) ;; *) fail 'unsupported repository name' ;; esac
[[ -n "$repository_dir" && -n "$public_bundle" ]] || fail 'repository directory and public bundle are required'

for tool in awk find git grep mkdir mktemp pacman pacman-conf pacman-key readlink rm sort; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
release_tools="${project_root}/tools/release"
signing_tools="${project_root}/tools/signing"
"${release_tools}/validate-release-repository.sh" \
  --repository-dir "$repository_dir" \
  --repository "$repository" \
  --state complete \
  --public-bundle "$public_bundle"
repository_dir="$(readlink -f -- "$repository_dir")"
public_bundle="$(readlink -f -- "$public_bundle")"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
root_dir="${tmp_dir}/root"
db_dir="${tmp_dir}/db"
cache_dir="${tmp_dir}/cache"
gpg_dir="${tmp_dir}/gnupg"
hook_dir="${tmp_dir}/hooks"
mkdir -p "$root_dir" "$db_dir" "$cache_dir" "$gpg_dir" "$hook_dir"
chmod 0700 "$gpg_dir"

config="${tmp_dir}/pacman.conf"
cat >"$config" <<EOF
[options]
Architecture = x86_64
DBPath = ${db_dir}
CacheDir = ${cache_dir}
GPGDir = ${gpg_dir}
HookDir = ${hook_dir}
LogFile = ${tmp_dir}/pacman.log
SigLevel = Required TrustedOnly
LocalFileSigLevel = Required TrustedOnly

[${repository}]
SigLevel = Required TrustedOnly
Server = file://${repository_dir}
EOF
chmod 0600 "$config"
pacman-conf --config "$config" >/dev/null

# This creates only the disposable client's local trust root. It is not a
# SchweisOS release key and never enters the host pacman keyring.
pacman-key --gpgdir "$gpg_dir" --init
pacman-key \
  --gpgdir "$gpg_dir" \
  --populate-from "$public_bundle" \
  --populate schweisos

if (( EUID == 0 )); then
  pacman_runner=(pacman)
else
  command -v fakeroot >/dev/null 2>&1 || fail 'required tool not found: fakeroot'
  pacman_runner=(fakeroot pacman)
fi

"${pacman_runner[@]}" --config "$config" --root "$root_dir" --sync --refresh --noconfirm
mapfile -t package_names < <(
  pacman --config "$config" --root "$root_dir" --sync --list "$repository" |
    awk '{ print $2 }' | sort -u
)
(( ${#package_names[@]} > 0 )) || fail 'signed repository exposed no packages to pacman'
"${pacman_runner[@]}" --config "$config" --root "$root_dir" \
  --sync --downloadonly --nodeps --noconfirm "${package_names[@]}"

for package_name in "${package_names[@]}"; do
  mapfile -t downloaded < <(
    find "$cache_dir" -maxdepth 1 -type f -name "${package_name}-*.pkg.tar.*" ! -name '*.sig' -print | sort
  )
  (( ${#downloaded[@]} == 1 )) || fail "expected one downloaded artifact for $package_name"
  "${signing_tools}/verify-artifact-signature.sh" package "$public_bundle" \
    "${downloaded[0]}" "${downloaded[0]}.sig"
done

printf 'Disposable signed-repository pacman validation passed.\n'
printf '  repository: %s\n' "$repository"
printf '  packages: %s\n' "${#package_names[@]}"
printf '  host pacman state: untouched\n'
