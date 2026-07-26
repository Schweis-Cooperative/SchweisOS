#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

repository='schweisos'
arch='x86_64'
signed_packages=''
public_bundle=''
output=''
baseline_dir=''
initial_repository=false

usage() {
  cat <<'EOF'
Usage: create-repository-candidate.sh OPTIONS

Required:
  --signed-packages PATH  Flat directory containing packages and .sig files
  --public-bundle PATH
  --output PATH           New candidate root; it must not already exist

Exactly one repository-history option:
  --baseline-dir PATH     Complete currently published repository leaf
  --initial-repository    Explicitly acknowledge creation of generation zero

Optional:
  --repository schweisos|schweisos-testing|schweisos-staging
  --arch x86_64
  -h, --help

The output layout is OUTPUT/REPOSITORY/os/ARCH. Package signatures are
verified before repo-add. Repository metadata remains unsigned until the
separate signing-host step.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --signed-packages) (( $# >= 2 )) || fail 'missing value for --signed-packages'; signed_packages="$2"; shift 2 ;;
    --public-bundle) (( $# >= 2 )) || fail 'missing value for --public-bundle'; public_bundle="$2"; shift 2 ;;
    --output) (( $# >= 2 )) || fail 'missing value for --output'; output="$2"; shift 2 ;;
    --baseline-dir) (( $# >= 2 )) || fail 'missing value for --baseline-dir'; baseline_dir="$2"; shift 2 ;;
    --initial-repository) initial_repository=true; shift ;;
    --repository) (( $# >= 2 )) || fail 'missing value for --repository'; repository="$2"; shift 2 ;;
    --arch) (( $# >= 2 )) || fail 'missing value for --arch'; arch="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

case "$repository" in schweisos|schweisos-testing|schweisos-staging) ;; *) fail 'unsupported repository name' ;; esac
[[ "$arch" == x86_64 ]] || fail 'only x86_64 is currently supported'
[[ -n "$signed_packages" && -n "$public_bundle" && -n "$output" ]] || fail 'all path options are required'
if [[ -n "$baseline_dir" && "$initial_repository" == true ]]; then
  fail '--baseline-dir and --initial-repository are mutually exclusive'
fi
if [[ -z "$baseline_dir" && "$initial_repository" == false ]]; then
  fail 'one of --baseline-dir or --initial-repository is required'
fi

for tool in awk basename bsdtar chmod cp dirname find git grep mkdir mktemp mv readlink realpath repo-add rm sed sha256sum sort stat vercmp; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
signing_dir="$(cd -- "${script_dir}/../signing" && pwd -P)"
"${signing_dir}/validate-admitted-public-bundle.sh" "$public_bundle"

[[ -d "$signed_packages" && ! -L "$signed_packages" ]] || fail 'signed package directory is missing or unsafe'
signed_packages="$(readlink -f -- "$signed_packages")"
public_bundle="$(readlink -f -- "$public_bundle")"
if [[ -n "$baseline_dir" ]]; then
  [[ -d "$baseline_dir" && ! -L "$baseline_dir" ]] || fail 'baseline repository is missing or unsafe'
  baseline_dir="$(readlink -f -- "$baseline_dir")"
  "${script_dir}/validate-release-repository.sh" \
    --repository-dir "$baseline_dir" \
    --repository "$repository" \
    --state complete \
    --public-bundle "$public_bundle"
fi
case "$output" in /*) ;; *) output="${project_root}/${output}" ;; esac
output="$(realpath -m -- "$output")"
[[ "$output" != / && "$output" != "$project_root" ]] || fail 'unsafe repository candidate output path'
[[ ! -e "$output" && ! -L "$output" ]] || fail 'repository candidate output already exists'
output_parent="$(dirname -- "$output")"
mkdir -p -- "$output_parent"
[[ -d "$output_parent" && ! -L "$output_parent" ]] || fail 'repository candidate parent is unsafe'
[[ "$(stat -c '%u' "$output_parent")" == "$EUID" ]] || \
  fail 'repository candidate parent must be owned by the invoking user'
output_parent_mode="$(stat -c '%a' "$output_parent")"
[[ "$output_parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'repository candidate parent mode is unreadable'
(( (8#$output_parent_mode & 8#022) == 0 )) || \
  fail 'repository candidate parent is group- or world-writable'

if find "$signed_packages" -mindepth 1 -maxdepth 1 -type f -perm /022 -print -quit | grep -q .; then
  fail 'signed package input contains a group- or world-writable file'
fi
mapfile -t packages < <(
  find "$signed_packages" -mindepth 1 -maxdepth 1 -type f \
    -name '*.pkg.tar.*' ! -name '*.sig' -print | sort
)
(( ${#packages[@]} > 0 )) || fail 'no signed package artifacts were found'
unexpected_input="$(
  find "$signed_packages" -mindepth 1 -maxdepth 1 \
    ! -type f -print -quit
)"
[[ -z "$unexpected_input" ]] || fail "unexpected signed-package input entry: $unexpected_input"
while IFS= read -r -d '' input_file; do
  input_name="$(basename -- "$input_file")"
  case "$input_name" in
    *.pkg.tar.*.sig)
      [[ -f "${input_file%.sig}" ]] || fail "orphan package signature: $input_name"
      ;;
    *.pkg.tar.*) ;;
    *) fail "unexpected signed-package input file: $input_name" ;;
  esac
done < <(find "$signed_packages" -mindepth 1 -maxdepth 1 -type f -print0 | sort -z)

stage="$(mktemp -d --tmpdir="$output_parent" .schweisos-repository-candidate.XXXXXX)"
published=false
cleanup() {
  local status=$?
  [[ "$published" == true ]] || rm -rf -- "$stage"
  exit "$status"
}
trap cleanup EXIT
repository_dir="${stage}/${repository}/os/${arch}"
mkdir -p -- "$repository_dir"

if [[ -n "$baseline_dir" ]]; then
  baseline_snapshot="${stage}/.validated-baseline"
  mkdir -m 0700 -- "$baseline_snapshot"
  cp -a -- "$baseline_dir/." "$baseline_snapshot/"
  "${script_dir}/validate-release-repository.sh" \
    --repository-dir "$baseline_snapshot" \
    --repository "$repository" \
    --state complete \
    --public-bundle "$public_bundle"
  baseline_dir="$baseline_snapshot"
fi

for package in "${packages[@]}"; do
  signature="${package}.sig"
  cp --preserve=mode,timestamps -- "$package" "$signature" "$repository_dir/"
done

mapfile -t staged_packages < <(
  find "$repository_dir" -maxdepth 1 -type f -name '*.pkg.tar.*' ! -name '*.sig' -print | sort
)
(( ${#staged_packages[@]} == ${#packages[@]} )) || fail 'staged package count differs from signed input'

declare -A candidate_versions=()
declare -A candidate_hashes=()
for package in "${staged_packages[@]}"; do
  signature="${package}.sig"
  "${signing_dir}/verify-artifact-signature.sh" package "$public_bundle" "$package" "$signature"
  mapfile -t package_names < <(
    bsdtar -xOf "$package" .PKGINFO | awk -F ' = ' '$1 == "pkgname" { print $2 }'
  )
  mapfile -t package_versions < <(
    bsdtar -xOf "$package" .PKGINFO | awk -F ' = ' '$1 == "pkgver" { print $2 }'
  )
  (( ${#package_names[@]} == 1 && ${#package_versions[@]} == 1 )) || \
    fail "staged package has ambiguous name or version metadata: $package"
  package_name="${package_names[0]}"
  package_version="${package_versions[0]}"
  [[ "$package_name" =~ ^[a-z0-9@._+-]+$ && -n "$package_version" ]] || \
    fail "staged package has invalid name or version metadata: $package"
  [[ -z "${candidate_versions[$package_name]+x}" ]] || \
    fail "staged input contains duplicate package name: $package_name"
  candidate_versions["$package_name"]="$package_version"
  candidate_hashes["$package_name"]="$(sha256sum "$package" | awk '{ print $1 }')"
done

if [[ -n "$baseline_dir" ]]; then
  baseline_archive="${baseline_dir}/${repository}.db.tar.gz"
  mapfile -t baseline_descriptors < <(bsdtar -tf "$baseline_archive" | sort | sed -n '/\/desc$/p')
  (( ${#baseline_descriptors[@]} > 0 )) || fail 'baseline repository contains no package descriptors'
  for descriptor in "${baseline_descriptors[@]}"; do
    descriptor_content="$(bsdtar -xOf "$baseline_archive" "$descriptor")"
    mapfile -t baseline_names < <(
      awk '$0 == "%NAME%" { getline; print }' <<<"$descriptor_content"
    )
    mapfile -t baseline_versions < <(
      awk '$0 == "%VERSION%" { getline; print }' <<<"$descriptor_content"
    )
    mapfile -t baseline_hashes < <(
      awk '$0 == "%SHA256SUM%" { getline; print }' <<<"$descriptor_content"
    )
    (( ${#baseline_names[@]} == 1 && ${#baseline_versions[@]} == 1 \
      && ${#baseline_hashes[@]} == 1 )) || \
      fail "baseline descriptor has ambiguous identity or digest: $descriptor"
    baseline_name="${baseline_names[0]}"
    baseline_version="${baseline_versions[0]}"
    [[ -n "${candidate_versions[$baseline_name]+x}" ]] || \
      fail "candidate would remove baseline package: $baseline_name"
    version_order="$(vercmp "${candidate_versions[$baseline_name]}" "$baseline_version")"
    if (( version_order < 0 )); then
      fail "candidate would downgrade ${baseline_name}: ${baseline_version} -> ${candidate_versions[$baseline_name]}"
    fi
    if (( version_order == 0 )) \
      && [[ "${candidate_hashes[$baseline_name]}" != "${baseline_hashes[0]}" ]]; then
      fail "candidate would replace ${baseline_name} without a version increment"
    fi
  done
fi

if [[ -n "${baseline_snapshot-}" ]]; then
  rm -rf -- "$baseline_snapshot"
fi

repo-add --include-sigs --prevent-downgrade \
  "${repository_dir}/${repository}.db.tar.gz" \
  "${staged_packages[@]}"
find "$stage" -type d -exec chmod 0755 {} +
find "$stage" -type f -exec chmod 0644 {} +

"${script_dir}/validate-release-repository.sh" \
  --repository-dir "$repository_dir" \
  --repository "$repository" \
  --state candidate \
  --public-bundle "$public_bundle"

mv -T -- "$stage" "$output"
published=true
trap - EXIT

printf 'Unsigned repository-metadata candidate created.\n'
printf '  root: %s\n' "$output"
printf '  metadata awaiting database-role signatures: %s.db and %s.files\n' \
  "$repository" "$repository"
printf '  database SHA256: %s\n' \
  "$(sha256sum "${output}/${repository}/os/${arch}/${repository}.db.tar.gz" | awk '{ print $1 }')"
printf '  files SHA256: %s\n' \
  "$(sha256sum "${output}/${repository}/os/${arch}/${repository}.files.tar.gz" | awk '{ print $1 }')"
