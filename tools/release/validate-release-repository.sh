#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

repository='schweisos'
state='complete'
repository_dir=''
public_bundle=''

usage() {
  cat <<'EOF'
Usage: validate-release-repository.sh OPTIONS

Required:
  --repository-dir PATH
  --public-bundle PATH

Optional:
  --repository schweisos|schweisos-testing|schweisos-staging
  --state candidate|complete  Default: complete
  -h, --help
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
    --state) (( $# >= 2 )) || fail 'missing value for --state'; state="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

case "$repository" in schweisos|schweisos-testing|schweisos-staging) ;; *) fail 'unsupported repository name' ;; esac
case "$state" in candidate|complete) ;; *) fail 'state must be candidate or complete' ;; esac
[[ -n "$repository_dir" && -n "$public_bundle" ]] || fail 'repository directory and public bundle are required'

for tool in awk base64 basename bsdtar cmp dirname find git grep mkdir mktemp readlink repo-add rm sed sha256sum sort stat; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
signing_dir="$(cd -- "${script_dir}/../signing" && pwd -P)"
"${signing_dir}/validate-admitted-public-bundle.sh" "$public_bundle"

[[ -d "$repository_dir" && ! -L "$repository_dir" ]] || fail 'repository directory is missing or unsafe'
repository_dir="$(readlink -f -- "$repository_dir")"
public_bundle="$(readlink -f -- "$public_bundle")"
repository_mode="$(stat -c '%a' "$repository_dir")"
[[ "$repository_mode" =~ ^[0-7]{3,4}$ ]] || fail 'repository directory mode is unreadable'
(( (8#$repository_mode & 8#022) == 0 )) || fail 'repository directory is writable by other users'

database_archive="${repository_dir}/${repository}.db.tar.gz"
files_archive="${repository_dir}/${repository}.files.tar.gz"
database_link="${repository_dir}/${repository}.db"
files_link="${repository_dir}/${repository}.files"
database_signature="${repository_dir}/${repository}.db.sig"
files_signature="${repository_dir}/${repository}.files.sig"

for archive in "$database_archive" "$files_archive"; do
  [[ -f "$archive" && ! -L "$archive" && -s "$archive" ]] || \
    fail "repository metadata archive is missing, empty, or unsafe: $archive"
done
[[ -L "$database_link" && "$(readlink -- "$database_link")" == "${repository}.db.tar.gz" ]] || \
  fail 'repository database link is missing or noncanonical'
[[ -L "$files_link" && "$(readlink -- "$files_link")" == "${repository}.files.tar.gz" ]] || \
  fail 'repository files link is missing or noncanonical'

case "$state" in
  candidate)
    [[ ! -e "$database_signature" && ! -L "$database_signature" \
      && ! -e "$files_signature" && ! -L "$files_signature" ]] || \
      fail 'unsigned candidate contains a partial or unexpected metadata signature'
    ;;
  complete)
    "${signing_dir}/verify-artifact-signature.sh" database "$public_bundle" \
      "$database_archive" "$database_signature"
    "${signing_dir}/verify-artifact-signature.sh" database "$public_bundle" \
      "$files_archive" "$files_signature"
    ;;
esac

mapfile -t packages < <(
  find "$repository_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print | sort
)
(( ${#packages[@]} > 0 )) || fail 'repository contains no package artifacts'

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
: >"${tmp_dir}/expected-names"
: >"${tmp_dir}/expected-filenames"
: >"${tmp_dir}/seen-names"
declare -A package_paths_by_filename=()
declare -A package_names_by_filename=()
declare -A package_versions_by_filename=()
declare -A package_arches_by_filename=()

for package in "${packages[@]}"; do
  [[ ! -L "$package" && -s "$package" ]] || fail "unsafe package artifact: $package"
  package_signature="${package}.sig"
  "${signing_dir}/verify-artifact-signature.sh" package "$public_bundle" "$package" "$package_signature"
  package_name="$(bsdtar -xOf "$package" .PKGINFO | awk -F ' = ' '$1 == "pkgname" { print $2 }')"
  package_version="$(bsdtar -xOf "$package" .PKGINFO | awk -F ' = ' '$1 == "pkgver" { print $2 }')"
  package_arch="$(bsdtar -xOf "$package" .PKGINFO | awk -F ' = ' '$1 == "arch" { print $2 }')"
  [[ "$package_name" =~ ^[a-z0-9@._+-]+$ && -n "$package_version" ]] || \
    fail "invalid package metadata: $package"
  [[ "$package_arch" == any || "$package_arch" == x86_64 ]] || \
    fail "unsupported package architecture: $package_arch"
  if grep -Fxq -- "$package_name" "${tmp_dir}/seen-names"; then
    fail "duplicate package name in repository candidate: $package_name"
  fi
  printf '%s\n' "$package_name" >>"${tmp_dir}/seen-names"
  printf '%s\n' "$package_name" >>"${tmp_dir}/expected-names"
  package_filename="$(basename -- "$package")"
  printf '%s\n' "$package_filename" >>"${tmp_dir}/expected-filenames"
  package_paths_by_filename["$package_filename"]="$package"
  package_names_by_filename["$package_filename"]="$package_name"
  package_versions_by_filename["$package_filename"]="$package_version"
  package_arches_by_filename["$package_filename"]="$package_arch"
done

descriptor_field() {
  local content="$1"
  local field="$2"
  local descriptor="$3"
  local -a values
  mapfile -t values < <(
    awk -v marker="%${field}%" '$0 == marker { getline; print }' <<<"$content"
  )
  (( ${#values[@]} == 1 )) || {
    printf 'ERROR: descriptor field %s must appear exactly once: %s\n' "$field" "$descriptor" >&2
    return 1
  }
  [[ -n "${values[0]}" ]] || {
    printf 'ERROR: descriptor field %s is empty: %s\n' "$field" "$descriptor" >&2
    return 1
  }
  printf '%s\n' "${values[0]}"
}

validate_descriptor_archive() {
  local archive="$1"
  local label="$2"
  local descriptor descriptor_content descriptor_name descriptor_filename
  local descriptor_version descriptor_arch descriptor_sha256 descriptor_size
  local descriptor_signature package_path
  local descriptor_count=0

  : >"${tmp_dir}/${label}-names"
  : >"${tmp_dir}/${label}-filenames"
  while IFS= read -r descriptor; do
    (( descriptor_count += 1 ))
    descriptor_content="$(bsdtar -xOf "$archive" "$descriptor")"
    descriptor_name="$(descriptor_field "$descriptor_content" NAME "$descriptor")"
    descriptor_filename="$(descriptor_field "$descriptor_content" FILENAME "$descriptor")"
    descriptor_version="$(descriptor_field "$descriptor_content" VERSION "$descriptor")"
    descriptor_arch="$(descriptor_field "$descriptor_content" ARCH "$descriptor")"
    descriptor_sha256="$(descriptor_field "$descriptor_content" SHA256SUM "$descriptor")"
    descriptor_size="$(descriptor_field "$descriptor_content" CSIZE "$descriptor")"
    descriptor_signature="$(descriptor_field "$descriptor_content" PGPSIG "$descriptor")"

    [[ -n "${package_paths_by_filename[$descriptor_filename]+x}" ]] || \
      fail "$label references an unknown package artifact: $descriptor_filename"
    package_path="${package_paths_by_filename[$descriptor_filename]}"
    [[ "$descriptor_name" == "${package_names_by_filename[$descriptor_filename]}" ]] || \
      fail "$label package name does not match artifact metadata: $descriptor"
    [[ "$descriptor_version" == "${package_versions_by_filename[$descriptor_filename]}" ]] || \
      fail "$label package version does not match artifact metadata: $descriptor"
    [[ "$descriptor_arch" == "${package_arches_by_filename[$descriptor_filename]}" ]] || \
      fail "$label package architecture does not match artifact metadata: $descriptor"
    [[ "$descriptor_sha256" == "$(sha256sum "$package_path" | awk '{ print $1 }')" ]] || \
      fail "$label SHA256SUM does not match package artifact: $descriptor_filename"
    [[ "$descriptor_size" == "$(stat -c '%s' "$package_path")" ]] || \
      fail "$label CSIZE does not match package artifact: $descriptor_filename"
    [[ "$descriptor_signature" == "$(base64 -w0 -- "${package_path}.sig")" ]] || \
      fail "$label PGPSIG does not match detached package signature: $descriptor_filename"

    printf '%s\n' "$descriptor_name" >>"${tmp_dir}/${label}-names"
    printf '%s\n' "$descriptor_filename" >>"${tmp_dir}/${label}-filenames"
  done < <(bsdtar -tf "$archive" | sort | sed -n '/\/desc$/p')

  (( descriptor_count == ${#packages[@]} )) || \
    fail "$label descriptor count differs from signed artifact count"
  for comparison in names filenames; do
    sort -u "${tmp_dir}/expected-${comparison}" >"${tmp_dir}/expected-${comparison}.sorted"
    sort -u "${tmp_dir}/${label}-${comparison}" >"${tmp_dir}/${label}-${comparison}.sorted"
    cmp -s "${tmp_dir}/expected-${comparison}.sorted" "${tmp_dir}/${label}-${comparison}.sorted" || \
      fail "$label ${comparison} inventory differs from signed artifacts"
  done
}

validate_descriptor_archive "$database_archive" database
validate_descriptor_archive "$files_archive" files

canonical_dir="${tmp_dir}/canonical"
mkdir -m 0700 -- "$canonical_dir"
repo-add --include-sigs \
  "${canonical_dir}/${repository}.db.tar.gz" \
  "${packages[@]}" >/dev/null

compare_repo_add_archive() {
  local actual_archive="$1"
  local canonical_archive="$2"
  local label="$3"
  local entry

  bsdtar -tf "$actual_archive" | sort >"${tmp_dir}/${label}-actual.entries"
  bsdtar -tf "$canonical_archive" | sort >"${tmp_dir}/${label}-canonical.entries"
  cmp -s "${tmp_dir}/${label}-actual.entries" "${tmp_dir}/${label}-canonical.entries" || \
    fail "$label structure differs from metadata regenerated from signed packages"
  while IFS= read -r entry; do
    [[ "$entry" == */ ]] && continue
    cmp -s \
      <(bsdtar -xOf "$actual_archive" "$entry") \
      <(bsdtar -xOf "$canonical_archive" "$entry") || \
      fail "$label entry differs from metadata regenerated from signed packages: $entry"
  done <"${tmp_dir}/${label}-actual.entries"
}

compare_repo_add_archive \
  "$database_archive" "${canonical_dir}/${repository}.db.tar.gz" database
compare_repo_add_archive \
  "$files_archive" "${canonical_dir}/${repository}.files.tar.gz" files

declare -A allowed_entries=(
  ["${repository}.db"]=1
  ["${repository}.db.tar.gz"]=1
  ["${repository}.files"]=1
  ["${repository}.files.tar.gz"]=1
)
if [[ "$state" == complete ]]; then
  allowed_entries["${repository}.db.sig"]=1
  allowed_entries["${repository}.files.sig"]=1
fi
for package in "${packages[@]}"; do
  package_filename="$(basename -- "$package")"
  allowed_entries["$package_filename"]=1
  allowed_entries["${package_filename}.sig"]=1
done
while IFS= read -r repository_entry; do
  entry_name="$(basename -- "$repository_entry")"
  [[ -n "${allowed_entries[$entry_name]-}" ]] || \
    fail "unexpected repository entry: $repository_entry"
done < <(find "$repository_dir" -mindepth 1 -maxdepth 1 -print | sort)
if find "$repository_dir" -type f -perm /022 -print -quit | grep -q .; then
  fail 'repository contains a group- or world-writable file'
fi
if find "$repository_dir" -type d -perm /022 -print -quit | grep -q .; then
  fail 'repository contains a group- or world-writable directory'
fi
broken_link="$(find "$repository_dir" -xtype l -print -quit)"
[[ -z "$broken_link" ]] || fail "repository contains a broken symlink: $broken_link"

printf 'SchweisOS release repository validation passed.\n'
printf '  repository: %s\n' "$repository"
printf '  state: %s\n' "$state"
printf '  packages: %s\n' "${#packages[@]}"
