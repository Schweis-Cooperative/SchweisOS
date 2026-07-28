#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

for tool in bash bsdtar cmp find git grep makepkg mkdir mktemp readlink rm sed sh sort stat; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
package_dir="${project_root}/packages/schweisos-keyring"
keys_dir="${package_dir}/keys"
signing_dir="${project_root}/tools/signing"

for required_file in \
  "${package_dir}/PKGBUILD" \
  "${package_dir}/README.md" \
  "${package_dir}/future-keys.md" \
  "${package_dir}/keyring-policy.md" \
  "${package_dir}/schweisos-keyring.install"; do
  [[ -f "$required_file" && ! -L "$required_file" ]] || fail "missing or unsafe keyring source: $required_file"
done
[[ -d "$keys_dir" && ! -L "$keys_dir" ]] || fail 'keyring source directory is missing or unsafe'

mapfile -t key_entries < <(find "$keys_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)
production_entries=(
  SHA256SUMS
  release-key-metadata.tsv
  schweisos-release.asc
  schweisos-revoked
  schweisos-trusted
  schweisos.gpg
)

if [[ "${key_entries[*]}" == README.md ]]; then
  keyring_state=bootstrap
  [[ -f "${keys_dir}/README.md" && ! -L "${keys_dir}/README.md" \
    && "$(stat -c '%a' "${keys_dir}/README.md")" == 644 ]] || \
    fail 'bootstrap sentinel must be a regular 0644 README'
  [[ -f "${package_dir}/PKGBUILD.production.in" && ! -L "${package_dir}/PKGBUILD.production.in" ]] || \
    fail 'bootstrap operational PKGBUILD template is missing or unsafe'
  [[ -f "${package_dir}/README.production.md" && ! -L "${package_dir}/README.production.md" ]] || \
    fail 'bootstrap operational README template is missing or unsafe'
  [[ -f "${package_dir}/future-keys.production.md" && ! -L "${package_dir}/future-keys.production.md" ]] || \
    fail 'bootstrap operational trust-evolution template is missing or unsafe'
  [[ -f "${package_dir}/keyring-policy.production.md" && ! -L "${package_dir}/keyring-policy.production.md" ]] || \
    fail 'bootstrap operational policy template is missing or unsafe'
  grep -Fq "pkgver=0.1.0" "${package_dir}/PKGBUILD" || fail 'unexpected bootstrap package version'
  ! grep -Eq '^[[:space:]]*install=' "${package_dir}/PKGBUILD" || \
    fail 'bootstrap PKGBUILD must not activate the install hook'
  grep -Fq "pkgver=1.0.0" "${package_dir}/PKGBUILD.production.in" || \
    fail 'unexpected first operational package version'
  grep -Eq "depends=.*'archlinux-keyring'" "${package_dir}/PKGBUILD.production.in" || \
    fail 'operational template does not order trust setup after archlinux-keyring'
  grep -Eq '@[A-Z0-9_]+@' "${package_dir}/PKGBUILD.production.in" || \
    fail 'operational PKGBUILD template has no checksum admission tokens'
  production_source_block="$(
    awk '
      /^[[:space:]]*source=\(/ { in_source = 1 }
      in_source { print }
      in_source && /^[[:space:]]*\)[[:space:]]*$/ { in_source = 0 }
    ' "${package_dir}/PKGBUILD.production.in"
  )"
  grep -Fq "'schweisos-release-public'" <<<"$production_source_block" || \
    fail 'operational PKGBUILD template does not use a neutral public certificate source name'
  ! grep -Fq "'schweisos-release.asc'" <<<"$production_source_block" || \
    fail 'operational PKGBUILD template exposes the public certificate as a .asc source'
  unexpected_source_link="$(find "$package_dir" -maxdepth 1 -type l -print -quit)"
  [[ -z "$unexpected_source_link" ]] || fail "unexpected bootstrap source link: $unexpected_source_link"
elif [[ "${key_entries[*]}" == "${production_entries[*]}" ]]; then
  keyring_state=production
  [[ ! -e "${package_dir}/PKGBUILD.production.in" && ! -L "${package_dir}/PKGBUILD.production.in" ]] || \
    fail 'production package retains the bootstrap PKGBUILD template'
  [[ ! -e "${package_dir}/README.production.md" && ! -L "${package_dir}/README.production.md" ]] || \
    fail 'production package retains the bootstrap README template'
  [[ ! -e "${package_dir}/future-keys.production.md" \
    && ! -L "${package_dir}/future-keys.production.md" ]] || \
    fail 'production package retains the bootstrap trust-evolution template'
  [[ ! -e "${package_dir}/keyring-policy.production.md" \
    && ! -L "${package_dir}/keyring-policy.production.md" ]] || \
    fail 'production package retains the bootstrap policy template'
  "${signing_dir}/validate-public-bundle.sh" "$keys_dir"
  for filename in "${production_entries[@]}"; do
    if [[ "$filename" == schweisos-release.asc ]]; then
      source_link="${package_dir}/schweisos-release-public"
      expected_target='keys/schweisos-release.asc'
    else
      source_link="${package_dir}/${filename}"
      expected_target="keys/${filename}"
    fi
    [[ -L "$source_link" && "$(readlink -- "$source_link")" == "$expected_target" ]] || \
      fail "operational makepkg source link is missing or unsafe: $source_link"
  done
  [[ ! -e "${package_dir}/schweisos-release.asc" && ! -L "${package_dir}/schweisos-release.asc" ]] || \
    fail 'operational makepkg source must not use the .asc filename'
  grep -Fq 'install=schweisos-keyring.install' "${package_dir}/PKGBUILD" || \
    fail 'operational package does not activate its reviewed install script'
  grep -Eq "depends=.*'archlinux-keyring'" "${package_dir}/PKGBUILD" || \
    fail 'operational package does not order trust setup after archlinux-keyring'
else
  printf 'Found key entries:\n' >&2
  printf '  %s\n' "${key_entries[@]}" >&2
  fail 'keyring package is in a forbidden partial bootstrap state'
fi

bash -n "${package_dir}/PKGBUILD" "${BASH_SOURCE[0]}"
sh -n "${package_dir}/schweisos-keyring.install"
grep -Fq -- 'pacman-key --populate schweisos' "${package_dir}/schweisos-keyring.install" || \
  fail 'install script does not populate only the SchweisOS keyring'
grep -Fq -- 'pacman-key -l' "${package_dir}/schweisos-keyring.install" || \
  fail 'install script does not use pacman-key to verify initialized state'
if grep -Eq -- 'pacman-key.*--init|recv-keys|refresh-keys|archlinux|SigLevel' \
    "${package_dir}/schweisos-keyring.install"; then
  fail 'install script crosses the approved trust-bootstrap boundary'
fi

unsafe_source="$(
  find "$package_dir" \
    \( -path "$package_dir/pkg" -o -path "$package_dir/src" \) -prune -o \
    -type f \
    \( -name '*.key' -o -name '*.pem' -o -name '*.rev' -o -name secring.gpg \) \
    -print -quit
)"
[[ -z "$unsafe_source" ]] || fail "private-material filename found in keyring source: $unsafe_source"

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "$tmp_dir"' EXIT
mkdir -p "${tmp_dir}/artifacts" "${tmp_dir}/build" "${tmp_dir}/sources"
(
  cd -- "$package_dir"
  SRCDEST="${tmp_dir}/sources" makepkg --verifysource
  makepkg --printsrcinfo >"${tmp_dir}/.SRCINFO"
  BUILDDIR="${tmp_dir}/build" \
  SRCDEST="${tmp_dir}/sources" \
  PKGDEST="${tmp_dir}/artifacts" \
    makepkg --nodeps --cleanbuild --clean --noconfirm
)

mapfile -t artifacts < <(
  find "${tmp_dir}/artifacts" -maxdepth 1 -type f \
    -name 'schweisos-keyring-*.pkg.tar.*' ! -name '*-debug-*' -print | sort
)
(( ${#artifacts[@]} == 1 )) || fail "expected one primary keyring package; found ${#artifacts[@]}"
payload_root="${tmp_dir}/payload"
mkdir -p "$payload_root"
bsdtar -xf "${artifacts[0]}" -C "$payload_root"

[[ ! -e "${payload_root}/etc" ]] || fail 'keyring package unexpectedly owns /etc'
[[ -d "${payload_root}/usr/share/pacman/keyrings" ]] || fail 'pacman keyring directory is absent'
expected_files=(.BUILDINFO .MTREE .PKGINFO)
if [[ "$keyring_state" == bootstrap ]]; then
  [[ ! -e "${payload_root}/.INSTALL" ]] || fail 'bootstrap package unexpectedly activates an install hook'
  expected_files+=(
    usr/share/doc/schweisos-keyring/future-keys.md
    usr/share/doc/schweisos-keyring/keyring-policy.md
  )
  [[ -z "$(find "${payload_root}/usr/share/pacman/keyrings" -type f -print -quit)" ]] || \
    fail 'bootstrap package contains operational trust material'
else
  expected_files+=(
    .INSTALL
    usr/share/doc/schweisos-keyring/future-keys.md
    usr/share/doc/schweisos-keyring/keyring-policy.md
    usr/share/doc/schweisos-keyring/public-bundle-SHA256SUMS
    usr/share/doc/schweisos-keyring/release-key-metadata.tsv
    usr/share/doc/schweisos-keyring/schweisos-release.asc
    usr/share/pacman/keyrings/schweisos-revoked
    usr/share/pacman/keyrings/schweisos-trusted
    usr/share/pacman/keyrings/schweisos.gpg
  )
  cmp -s "${package_dir}/schweisos-keyring.install" "${payload_root}/.INSTALL" || \
    fail 'packaged install hook differs from reviewed source'
  for filename in schweisos.gpg schweisos-trusted schweisos-revoked; do
    cmp -s "${keys_dir}/${filename}" "${payload_root}/usr/share/pacman/keyrings/${filename}" || \
      fail "installed trust file differs from admitted public bundle: $filename"
  done
  cmp -s "${keys_dir}/schweisos-release.asc" \
    "${payload_root}/usr/share/doc/schweisos-keyring/schweisos-release.asc" || \
    fail 'installed armored public certificate differs from admitted public bundle'
fi

expected_directories=(
  usr
  usr/share
  usr/share/doc
  usr/share/doc/schweisos-keyring
  usr/share/pacman
  usr/share/pacman/keyrings
)
find "$payload_root" -mindepth 1 -type f -printf '%P\n' | sort >"${tmp_dir}/actual-files"
printf '%s\n' "${expected_files[@]}" | sort >"${tmp_dir}/expected-files"
cmp -s "${tmp_dir}/expected-files" "${tmp_dir}/actual-files" || {
  printf 'Expected keyring payload files:\n' >&2
  sed 's/^/  /' "${tmp_dir}/expected-files" >&2
  printf 'Actual keyring payload files:\n' >&2
  sed 's/^/  /' "${tmp_dir}/actual-files" >&2
  fail 'keyring package file payload is incomplete or unexpected'
}
find "$payload_root" -mindepth 1 -type d -printf '%P\n' | sort >"${tmp_dir}/actual-directories"
printf '%s\n' "${expected_directories[@]}" | sort >"${tmp_dir}/expected-directories"
cmp -s "${tmp_dir}/expected-directories" "${tmp_dir}/actual-directories" || \
  fail 'keyring package directory payload is incomplete or unexpected'
unexpected_file_type="$(find "$payload_root" -mindepth 1 ! -type f ! -type d -print -quit)"
[[ -z "$unexpected_file_type" ]] || fail "unexpected keyring payload file type: $unexpected_file_type"
while IFS= read -r payload_file; do
  [[ "$(stat -c '%a' "$payload_file")" == 644 ]] || \
    fail "keyring payload file mode must be 0644: $payload_file"
done < <(find "$payload_root" -type f -print)
while IFS= read -r payload_directory; do
  [[ "$(stat -c '%a' "$payload_directory")" == 755 ]] || \
    fail "keyring payload directory mode must be 0755: $payload_directory"
done < <(find "$payload_root" -mindepth 1 -type d -print)

if find "$payload_root" -type f -perm /022 -print -quit | grep -q .; then
  fail 'keyring package contains a group- or world-writable payload file'
fi
git -C "$project_root" diff --check -- packages/schweisos-keyring tools/signing tests

printf 'SchweisOS keyring package validation passed.\n'
printf '  state: %s\n' "$keyring_state"
printf '  artifact: %s\n' "$(basename -- "${artifacts[0]}")"
