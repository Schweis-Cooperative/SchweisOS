#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

(( $# == 1 )) || fail 'usage: validate-built-iso-identity.sh ISO_PATH'
iso_path="$1"

for tool in awk bsdtar chmod cmp cp find git grep makepkg mkdir mktemp readlink rm sort unsquashfs; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
[[ -f "$iso_path" && ! -L "$iso_path" && -s "$iso_path" ]] || fail 'ISO artifact is missing, empty, or unsafe'
iso_path="$(readlink -f -- "$iso_path")"

profile="${project_root}/iso/profiles/kde/profiledef.sh"
source_identity="${project_root}/packages/schweisos-release/os-release"
[[ -f "$profile" && -f "$source_identity" ]] || fail 'canonical ISO identity sources are missing'
source_package_dir="${project_root}/packages/schweisos-release"
srcinfo="$(cd -- "$source_package_dir" && makepkg --printsrcinfo)"
source_pkgver="$(awk -F ' = ' '$1 == "\tpkgver" { print $2; exit }' <<<"$srcinfo")"
source_pkgrel="$(awk -F ' = ' '$1 == "\tpkgrel" { print $2; exit }' <<<"$srcinfo")"
source_epoch="$(awk -F ' = ' '$1 == "\tepoch" { print $2; exit }' <<<"$srcinfo")"
[[ -n "$source_pkgver" && -n "$source_pkgrel" ]] || fail 'source schweisos-release version is unreadable'
if [[ -n "$source_epoch" && "$source_epoch" != 0 ]]; then
  expected_version="${source_epoch}:${source_pkgver}-${source_pkgrel}"
else
  expected_version="${source_pkgver}-${source_pkgrel}"
fi
install_dir="$(
  SOURCE_DATE_EPOCH=0 bash -c 'source "$1"; printf "%s\n" "$install_dir"' _ "$profile"
)"
profile_identity="$(
  SOURCE_DATE_EPOCH=0 bash -c 'source "$1"; printf "%s\n%s\n" "$iso_name" "$iso_version"' _ "$profile"
)"
mapfile -t profile_identity_lines <<<"$profile_identity"
(( ${#profile_identity_lines[@]} == 2 )) || fail 'profile identity metadata is incomplete'
profile_iso_name="${profile_identity_lines[0]}"
profile_iso_version="${profile_identity_lines[1]}"
[[ "$install_dir" =~ ^[a-z0-9._-]+$ ]] || fail 'invalid Archiso install directory'
[[ "$profile_iso_name" =~ ^[a-z0-9._+-]+$ ]] || fail 'profile IMAGE_ID is unsafe'
[[ "$profile_iso_version" == "$source_pkgver" ]] || \
  fail 'profile IMAGE_VERSION must match schweisos-release pkgver'
squashfs_path="${install_dir}/x86_64/airootfs.sfs"
iso_squashfs_count="$(bsdtar -tf "$iso_path" | awk -v expected="$squashfs_path" '$0 == expected { count++ } END { print count + 0 }')"
[[ "$iso_squashfs_count" == 1 ]] || fail "ISO does not contain exactly one ${squashfs_path}"

tmp_parent="${TMPDIR:-${project_root}/work/validators/built-iso-identity}"
[[ -n "$tmp_parent" && "$tmp_parent" != / ]] || fail 'unsafe temporary directory parent'
mkdir -p -- "$tmp_parent"
[[ -d "$tmp_parent" && ! -L "$tmp_parent" ]] || fail 'temporary directory parent is missing or unsafe'
tmp_parent="$(readlink -f -- "$tmp_parent")"
tmp_dir="$(mktemp -d "${tmp_parent%/}/schweisos-built-iso-identity.XXXXXXXXXX")"
cleanup() {
  [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]] || return 0
  chmod -R u+rwX -- "$tmp_dir" 2>/dev/null || true
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT
bsdtar -xOf "$iso_path" "$squashfs_path" >"${tmp_dir}/airootfs.sfs"
[[ -s "${tmp_dir}/airootfs.sfs" ]] || fail 'extracted airootfs SquashFS is empty'
unsquashfs -no-progress -no-xattrs -d "${tmp_dir}/rootfs" "${tmp_dir}/airootfs.sfs" >/dev/null
rootfs="${tmp_dir}/rootfs"

mapfile -t package_records < <(
  find "${rootfs}/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d \
    -name 'schweisos-release-*' -print | sort
)
(( ${#package_records[@]} == 1 )) || \
  fail "expected one installed schweisos-release record; found ${#package_records[@]}"
package_desc="${package_records[0]}/desc"
package_files="${package_records[0]}/files"
installed_name="$(awk '$0 == "%NAME%" { getline; print; exit }' "$package_desc")"
installed_version="$(awk '$0 == "%VERSION%" { getline; print; exit }' "$package_desc")"
[[ "$installed_name" == schweisos-release && -n "$installed_version" ]] || \
  fail 'installed schweisos-release metadata is invalid'
[[ "$installed_version" == "$expected_version" ]] || \
  fail "ISO contains schweisos-release ${installed_version}; source requires ${expected_version}"
grep -Fxq 'etc/os-release' "$package_files" || fail 'schweisos-release does not own /etc/os-release in the ISO'
grep -Fxq 'usr/lib/schweisos-release/os-release' "$package_files" || \
  fail 'schweisos-release canonical identity payload ownership is missing'

effective_link="${rootfs}/etc/os-release"
[[ -L "$effective_link" ]] || fail 'effective /etc/os-release is not a symlink'
[[ "$(readlink -- "$effective_link")" == ../usr/lib/schweisos-release/os-release ]] || \
  fail 'effective /etc/os-release has the wrong target'
effective_identity="${rootfs}/usr/lib/schweisos-release/os-release"
[[ -f "$effective_identity" && ! -L "$effective_identity" ]] || fail 'effective SchweisOS identity target is missing'
if grep -Eq '^IMAGE_(ID|VERSION)=' "$source_identity"; then
  fail 'canonical schweisos-release identity must not contain live-image fields'
fi
expected_live_identity="${tmp_dir}/expected-live-os-release"
cp -- "$source_identity" "$expected_live_identity"
{
  printf 'IMAGE_ID=%s\n' "$profile_iso_name"
  printf 'IMAGE_VERSION=%s\n' "$profile_iso_version"
} >>"$expected_live_identity"
cmp -s "$expected_live_identity" "$effective_identity" || \
  fail 'effective ISO identity must equal schweisos-release identity plus Archiso IMAGE_ID and IMAGE_VERSION'

identity_value() {
  local file="$1"
  local key="$2"
  local raw
  local -a values
  mapfile -t values < <(
    awk -v key="$key" 'index($0, key "=") == 1 { print substr($0, length(key) + 2) }' "$file"
  )
  (( ${#values[@]} == 1 )) || fail "identity field must appear exactly once: $key"
  raw="${values[0]}"
  if [[ "$raw" == \"*\" && ${#raw} -ge 2 ]]; then
    raw="${raw:1:${#raw}-2}"
    [[ "$raw" != *['\\`$"']* ]] || fail "identity field uses unsupported quoting: $key"
  else
    [[ "$raw" =~ ^[A-Za-z0-9._+-]+$ ]] || fail "identity field is not a safe literal: $key"
  fi
  printf '%s\n' "$raw"
}
[[ "$(identity_value "$effective_identity" NAME)" == SchweisOS ]] || fail 'effective NAME is not SchweisOS'
[[ "$(identity_value "$effective_identity" ID)" == schweisos ]] || fail 'effective ID is not schweisos'
[[ "$(identity_value "$effective_identity" PRETTY_NAME)" == 'SchweisOS' ]] || \
  fail 'effective PRETTY_NAME is not SchweisOS'
[[ "$(identity_value "$effective_identity" VERSION)" == "$source_pkgver" ]] || \
  fail 'effective VERSION does not match schweisos-release pkgver'
[[ "$(identity_value "$effective_identity" VERSION_ID)" == "$source_pkgver" ]] || \
  fail 'effective VERSION_ID does not match schweisos-release pkgver'
[[ "$(identity_value "$effective_identity" IMAGE_ID)" == "$profile_iso_name" ]] || \
  fail 'effective IMAGE_ID does not match the Archiso profile'
[[ "$(identity_value "$effective_identity" IMAGE_VERSION)" == "$profile_iso_version" ]] || \
  fail 'effective IMAGE_VERSION does not match the Archiso profile'

printf 'Built ISO identity validation passed.\n'
printf '  ISO: %s\n' "$(basename -- "$iso_path")"
printf '  package: schweisos-release %s\n' "$installed_version"
printf '  /etc/os-release -> ../usr/lib/schweisos-release/os-release\n'
printf '  identity: %s %s\n' \
  "$(identity_value "$effective_identity" PRETTY_NAME)" \
  "$(identity_value "$effective_identity" VERSION_ID)"
printf '  image: %s %s\n' \
  "$(identity_value "$effective_identity" IMAGE_ID)" \
  "$(identity_value "$effective_identity" IMAGE_VERSION)"
