#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

repository='schweisos'
repository_dir=''
public_bundle=''
gnupg_home=''
database_sha256=''
files_sha256=''

usage() {
  cat <<'EOF'
Usage: sign-repository-metadata.sh OPTIONS

Required:
  --repository-dir PATH
  --public-bundle PATH
  --gnupg-home PATH
  --database-sha256 HEX
  --files-sha256 HEX

Optional:
  --repository schweisos|schweisos-testing|schweisos-staging
  -h, --help

Run this command only on the restricted signing host. It signs both repo-add
metadata archives with the authorized database-signing subkey and exposes the
two signatures only after both validate.
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
    --gnupg-home) (( $# >= 2 )) || fail 'missing value for --gnupg-home'; gnupg_home="$2"; shift 2 ;;
    --database-sha256) (( $# >= 2 )) || fail 'missing value for --database-sha256'; database_sha256="$2"; shift 2 ;;
    --files-sha256) (( $# >= 2 )) || fail 'missing value for --files-sha256'; files_sha256="$2"; shift 2 ;;
    --repository) (( $# >= 2 )) || fail 'missing value for --repository'; repository="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
case "$repository" in schweisos|schweisos-testing|schweisos-staging) ;; *) fail 'unsupported repository name' ;; esac
[[ -n "$repository_dir" && -n "$public_bundle" && -n "$gnupg_home" \
  && -n "$database_sha256" && -n "$files_sha256" ]] || fail 'all path options are required'
[[ "$database_sha256" =~ ^[a-f0-9]{64}$ && "$files_sha256" =~ ^[a-f0-9]{64}$ ]] || \
  fail 'approved metadata digests must be 64 lowercase hex characters'

for tool in chmod dirname flock ln mktemp readlink rm rmdir stat; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
signing_dir="$(cd -- "${script_dir}/../signing" && pwd -P)"
[[ -d "$repository_dir" && ! -L "$repository_dir" ]] || fail 'repository directory is missing or unsafe'
repository_dir="$(readlink -f -- "$repository_dir")"
public_bundle="$(readlink -f -- "$public_bundle")"
repository_parent="$(dirname -- "$repository_dir")"
[[ -d "$repository_parent" && ! -L "$repository_parent" ]] || \
  fail 'repository parent is missing or unsafe'
[[ "$(stat -c '%u' "$repository_parent")" == "$EUID" ]] || \
  fail 'repository parent must be owned by the invoking signing user'
repository_parent_mode="$(stat -c '%a' "$repository_parent")"
[[ "$repository_parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'repository parent mode is unreadable'
(( (8#$repository_parent_mode & 8#022) == 0 )) || \
  fail 'repository parent is group- or world-writable'

signing_lock="${repository_dir}.metadata-signing.lock"
if [[ -e "$signing_lock" || -L "$signing_lock" ]]; then
  [[ -f "$signing_lock" && ! -L "$signing_lock" ]] || \
    fail 'metadata-signing lock path is not a regular file'
fi
exec {signing_lock_fd}>"$signing_lock"
chmod 0600 -- "$signing_lock"
[[ "$(stat -c '%u' "$signing_lock")" == "$EUID" ]] || \
  fail 'metadata-signing lock is not owned by the invoking signing user'
flock -n "$signing_lock_fd" || fail 'repository metadata signing is already in progress'

"${script_dir}/validate-release-repository.sh" \
  --repository-dir "$repository_dir" \
  --repository "$repository" \
  --state candidate \
  --public-bundle "$public_bundle"
"${signing_dir}/validate-signing-home.sh" "$public_bundle" "$gnupg_home"

signature_stage="$(mktemp -d --tmpdir="$repository_dir" .metadata-signatures.XXXXXX)"
database_signature_published=false
files_signature_published=false
signatures_complete=false
cleanup() {
  if [[ "$signatures_complete" == false ]]; then
    [[ "$database_signature_published" == false ]] || \
      rm -f -- "${repository_dir}/${repository}.db.sig"
    [[ "$files_signature_published" == false ]] || \
      rm -f -- "${repository_dir}/${repository}.files.sig"
  fi
  rm -rf -- "$signature_stage"
}
trap cleanup EXIT

"${signing_dir}/sign-artifact.sh" \
  --role database \
  --public-bundle "$public_bundle" \
  --gnupg-home "$gnupg_home" \
  --artifact "${repository_dir}/${repository}.db.tar.gz" \
  --signature "${signature_stage}/${repository}.db.sig" \
  --expected-sha256 "$database_sha256"
"${signing_dir}/sign-artifact.sh" \
  --role database \
  --public-bundle "$public_bundle" \
  --gnupg-home "$gnupg_home" \
  --artifact "${repository_dir}/${repository}.files.tar.gz" \
  --signature "${signature_stage}/${repository}.files.sig" \
  --expected-sha256 "$files_sha256"

"${signing_dir}/verify-artifact-signature.sh" database "$public_bundle" \
  "${repository_dir}/${repository}.db.tar.gz" "${signature_stage}/${repository}.db.sig"
"${signing_dir}/verify-artifact-signature.sh" database "$public_bundle" \
  "${repository_dir}/${repository}.files.tar.gz" "${signature_stage}/${repository}.files.sig"

trap '' INT TERM HUP QUIT
ln -- "${signature_stage}/${repository}.db.sig" "${repository_dir}/${repository}.db.sig" || \
  fail 'repository database signature output appeared concurrently'
database_signature_published=true
ln -- "${signature_stage}/${repository}.files.sig" "${repository_dir}/${repository}.files.sig" || \
  fail 'repository files signature output appeared concurrently'
files_signature_published=true
trap - INT TERM HUP QUIT
rm -f -- \
  "${signature_stage}/${repository}.db.sig" \
  "${signature_stage}/${repository}.files.sig"
rmdir -- "$signature_stage"
"${script_dir}/validate-release-repository.sh" \
  --repository-dir "$repository_dir" \
  --repository "$repository" \
  --state complete \
  --public-bundle "$public_bundle"
signatures_complete=true

printf 'Repository metadata signing completed: %s\n' "$repository"
