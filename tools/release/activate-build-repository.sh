#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

repository='schweisos'
arch='x86_64'
candidate_dir=''
target_root=''
public_bundle=''

usage() {
  cat <<'EOF'
Usage: activate-build-repository.sh OPTIONS

Required:
  --candidate-dir PATH  Complete repository leaf (contains schweisos.db)
  --target-root PATH    Root expanded by $repo/os/$arch on the build host
  --public-bundle PATH

Optional:
  --repository schweisos|schweisos-testing|schweisos-staging
  --arch x86_64
  -h, --help

Stages and revalidates one complete signed repository generation, then uses a
same-filesystem directory exchange when replacing an existing generation. The
previous generation is retained under TARGET_ROOT.history. A nonblocking
activation lock prevents concurrent publishers from racing the exchange.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

while (( $# > 0 )); do
  case "$1" in
    --candidate-dir) (( $# >= 2 )) || fail 'missing value for --candidate-dir'; candidate_dir="$2"; shift 2 ;;
    --target-root) (( $# >= 2 )) || fail 'missing value for --target-root'; target_root="$2"; shift 2 ;;
    --public-bundle) (( $# >= 2 )) || fail 'missing value for --public-bundle'; public_bundle="$2"; shift 2 ;;
    --repository) (( $# >= 2 )) || fail 'missing value for --repository'; repository="$2"; shift 2 ;;
    --arch) (( $# >= 2 )) || fail 'missing value for --arch'; arch="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done
case "$repository" in schweisos|schweisos-testing|schweisos-staging) ;; *) fail 'unsupported repository name' ;; esac
[[ "$arch" == x86_64 ]] || fail 'only x86_64 is currently supported'
[[ -n "$candidate_dir" && -n "$target_root" && -n "$public_bundle" ]] || fail 'all path options are required'

for tool in awk bsdtar chmod cp date dirname flock mkdir mktemp mv readlink realpath rm rmdir sed sort stat vercmp; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
"${script_dir}/validate-release-repository.sh" \
  --repository-dir "$candidate_dir" \
  --repository "$repository" \
  --state complete \
  --public-bundle "$public_bundle"
candidate_dir="$(readlink -f -- "$candidate_dir")"
public_bundle="$(readlink -f -- "$public_bundle")"
target_root_lexical="$(realpath -ms -- "$target_root")"
target_root="$(realpath -m -- "$target_root")"
[[ "$target_root" == "$target_root_lexical" ]] || \
  fail 'target root contains a symlinked ancestor'
[[ "$target_root" != / ]] || fail 'unsafe target root'
target_root_parent="$(dirname -- "$target_root")"
[[ -d "$target_root_parent" && ! -L "$target_root_parent" ]] || \
  fail 'target root parent must already be a real directory'
parent_mode="$(stat -c '%a' "$target_root_parent")"
[[ "$parent_mode" =~ ^[0-7]{3,4}$ ]] || fail 'target root parent mode is unreadable'
(( (8#$parent_mode & 8#022) == 0 )) || fail 'target root parent is group- or world-writable'

activation_lock="${target_root}.activation.lock"
if [[ -e "$activation_lock" || -L "$activation_lock" ]]; then
  [[ -f "$activation_lock" && ! -L "$activation_lock" ]] || \
    fail 'activation lock path is not a regular file'
fi
exec {activation_lock_fd}>"$activation_lock"
chmod 0600 -- "$activation_lock"
[[ "$(stat -c '%u' "$activation_lock")" == "$EUID" ]] || \
  fail 'activation lock is not owned by the invoking user'
flock -n "$activation_lock_fd" || fail 'another repository activation is already in progress'

ensure_private_directory() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    [[ -d "$path" && ! -L "$path" ]] || fail "unsafe activation directory: $path"
  else
    mkdir -m 0755 -- "$path"
  fi
  local mode
  mode="$(stat -c '%a' "$path")"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || fail "activation directory mode is unreadable: $path"
  (( (8#$mode & 8#022) == 0 )) || fail "activation directory is group- or world-writable: $path"
}

ensure_private_directory "$target_root"
repository_root="${target_root}/${repository}"
ensure_private_directory "$repository_root"
repository_os_root="${repository_root}/os"
ensure_private_directory "$repository_os_root"
target_parent="$repository_os_root"
target_dir="${target_parent}/${arch}"

history_base="${target_root}.history"
ensure_private_directory "$history_base"
history_repository_root="${history_base}/${repository}"
ensure_private_directory "$history_repository_root"
history_os_root="${history_repository_root}/os"
ensure_private_directory "$history_os_root"
history_root="${history_os_root}/${arch}"
ensure_private_directory "$history_root"
[[ ! -L "$target_dir" ]] || fail 'target repository generation must not be a symlink'
[[ "$(stat -c '%d' "$target_parent")" == "$(stat -c '%d' "$history_root")" ]] || \
  fail 'active and history repositories must reside on the same filesystem'

compare_repository_generations() {
  local baseline_repository="$1"
  local proposed_repository="$2"
  local baseline_archive="${baseline_repository}/${repository}.db.tar.gz"
  local proposed_archive="${proposed_repository}/${repository}.db.tar.gz"
  local descriptor descriptor_content package_name package_version version_order
  local -a names versions hashes
  declare -A baseline_versions=()
  declare -A proposed_versions=()
  declare -A baseline_hashes=()
  declare -A proposed_hashes=()

  while IFS= read -r descriptor; do
    descriptor_content="$(bsdtar -xOf "$baseline_archive" "$descriptor")"
    mapfile -t names < <(awk '$0 == "%NAME%" { getline; print }' <<<"$descriptor_content")
    mapfile -t versions < <(awk '$0 == "%VERSION%" { getline; print }' <<<"$descriptor_content")
    mapfile -t hashes < <(awk '$0 == "%SHA256SUM%" { getline; print }' <<<"$descriptor_content")
    (( ${#names[@]} == 1 && ${#versions[@]} == 1 && ${#hashes[@]} == 1 )) || \
      fail "active repository descriptor has ambiguous identity: $descriptor"
    package_name="${names[0]}"
    package_version="${versions[0]}"
    [[ -z "${baseline_versions[$package_name]+x}" ]] || \
      fail "active repository has a duplicate package: $package_name"
    baseline_versions["$package_name"]="$package_version"
    baseline_hashes["$package_name"]="${hashes[0]}"
  done < <(bsdtar -tf "$baseline_archive" | sort | sed -n '/\/desc$/p')

  while IFS= read -r descriptor; do
    descriptor_content="$(bsdtar -xOf "$proposed_archive" "$descriptor")"
    mapfile -t names < <(awk '$0 == "%NAME%" { getline; print }' <<<"$descriptor_content")
    mapfile -t versions < <(awk '$0 == "%VERSION%" { getline; print }' <<<"$descriptor_content")
    mapfile -t hashes < <(awk '$0 == "%SHA256SUM%" { getline; print }' <<<"$descriptor_content")
    (( ${#names[@]} == 1 && ${#versions[@]} == 1 && ${#hashes[@]} == 1 )) || \
      fail "proposed repository descriptor has ambiguous identity: $descriptor"
    package_name="${names[0]}"
    package_version="${versions[0]}"
    [[ -z "${proposed_versions[$package_name]+x}" ]] || \
      fail "proposed repository has a duplicate package: $package_name"
    proposed_versions["$package_name"]="$package_version"
    proposed_hashes["$package_name"]="${hashes[0]}"
  done < <(bsdtar -tf "$proposed_archive" | sort | sed -n '/\/desc$/p')

  for package_name in "${!baseline_versions[@]}"; do
    [[ -n "${proposed_versions[$package_name]+x}" ]] || \
      fail "activation would remove active package: $package_name"
    version_order="$(vercmp "${proposed_versions[$package_name]}" "${baseline_versions[$package_name]}")"
    if (( version_order < 0 )); then
      fail "activation would downgrade ${package_name}: ${baseline_versions[$package_name]} -> ${proposed_versions[$package_name]}"
    fi
    if (( version_order == 0 )) \
      && [[ "${proposed_hashes[$package_name]}" != "${baseline_hashes[$package_name]}" ]]; then
      fail "activation would replace ${package_name} without a version increment"
    fi
  done
}

stage="$(mktemp -d --tmpdir="$target_parent" .${arch}.new.XXXXXX)"
old_generation=''
old_location=''
target_was_created=false
exchange_performed=false
activated=false
cleanup() {
  local status=$?
  local rollback_source=''
  if [[ "$activated" == false ]]; then
    if [[ "$exchange_performed" == true && -d "$target_dir" ]]; then
      if [[ -n "$old_location" && -d "$old_location" ]]; then
        rollback_source="$old_location"
      elif [[ -d "$stage" ]]; then
        rollback_source="$stage"
      elif [[ -n "$old_generation" && -d "$old_generation" ]]; then
        rollback_source="$old_generation"
      fi
      if [[ -n "$rollback_source" ]] \
        && mv --exchange --no-copy -- "$rollback_source" "$target_dir"; then
        rm -rf -- "$rollback_source"
      else
        printf 'ERROR: automatic repository activation rollback failed; both generations were retained.\n' >&2
      fi
    elif [[ "$target_was_created" == true ]]; then
      rm -rf -- "$target_dir"
    fi
    rm -rf -- "$stage"
  fi
  exit "$status"
}
trap cleanup EXIT
cp -a -- "$candidate_dir/." "$stage/"
"${script_dir}/validate-release-repository.sh" \
  --repository-dir "$stage" \
  --repository "$repository" \
  --state complete \
  --public-bundle "$public_bundle"

if [[ -e "$target_dir" ]]; then
  [[ -d "$target_dir" && ! -L "$target_dir" ]] || fail 'existing repository target is unsafe'
  "${script_dir}/validate-release-repository.sh" \
    --repository-dir "$target_dir" \
    --repository "$repository" \
    --state complete \
    --public-bundle "$public_bundle"
  compare_repository_generations "$target_dir" "$stage"
  old_generation="$(mktemp -d --tmpdir="$history_root" "$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")"
  rmdir -- "$old_generation"
  old_location="$stage"
  trap '' INT TERM HUP QUIT
  mv --exchange --no-copy -- "$stage" "$target_dir"
  exchange_performed=true
  mv -T -- "$stage" "$old_generation"
  old_location="$old_generation"
  trap - INT TERM HUP QUIT
else
  trap '' INT TERM HUP QUIT
  mv -T -- "$stage" "$target_dir"
  target_was_created=true
  trap - INT TERM HUP QUIT
fi

"${script_dir}/validate-release-repository.sh" \
  --repository-dir "$target_dir" \
  --repository "$repository" \
  --state complete \
  --public-bundle "$public_bundle"
activated=true
trap - EXIT

printf 'Signed build-host repository generation activated.\n'
printf '  target: %s\n' "$target_dir"
if [[ -n "$old_generation" ]]; then
  printf '  previous generation retained: %s\n' "$old_generation"
fi
