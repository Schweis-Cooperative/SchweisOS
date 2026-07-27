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

for tool in bash bsdtar find git jq makepkg mkdir mktemp readlink rm sort; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
package_dir="${project_root}/packages/schweisos-release"
identity_file="${package_dir}/os-release"
metadata_file="${package_dir}/release.json"

for required_file in "${package_dir}/PKGBUILD" "$identity_file" "$metadata_file"; do
  [[ -f "$required_file" ]] || fail "missing identity source: ${required_file}"
done

bash -n "${package_dir}/PKGBUILD" "${BASH_SOURCE[0]}"

srcinfo="$(cd -- "$package_dir" && makepkg --printsrcinfo)"
source_pkgver="$(awk -F ' = ' '$1 == "\tpkgver" { print $2; exit }' <<<"$srcinfo")"
[[ -n "$source_pkgver" ]] || fail 'source schweisos-release pkgver is unreadable'

set -a
# shellcheck disable=SC1090
source "$identity_file"
set +a

[[ "$NAME" == SchweisOS ]] || fail 'NAME must identify SchweisOS'
[[ "$PRETTY_NAME" == 'SchweisOS' ]] || fail 'unexpected PRETTY_NAME'
[[ "$ID" == schweisos ]] || fail 'ID must be schweisos'
[[ "$ID_LIKE" == arch ]] || fail 'ID_LIKE must preserve the Arch base relationship'
[[ "$VERSION" == "$source_pkgver" ]] || fail 'VERSION must match schweisos-release pkgver'
[[ "$VERSION_ID" == "$source_pkgver" ]] || fail 'VERSION_ID must match schweisos-release pkgver'
[[ "$BUILD_ID" == "$source_pkgver" ]] || fail 'BUILD_ID must match schweisos-release pkgver'
[[ "$LOGO" == schweisos ]] || fail 'LOGO must reference the SchweisOS icon name'
[[ "$SCHWEISOS_RELEASE_CHANNEL" == rolling ]] || fail 'unexpected release channel'
[[ "$SCHWEISOS_RELEASE_SCHEMA" == 1 ]] || fail 'unexpected release schema'

for project_url in \
  "$HOME_URL" \
  "$DOCUMENTATION_URL" \
  "$SUPPORT_URL" \
  "$BUG_REPORT_URL" \
  "$PRIVACY_POLICY_URL"; do
  [[ "$project_url" == https://github.com/Schweis-Cooperative/SchweisOS* ]] || \
    fail "identity URL is outside the canonical project namespace: ${project_url}"
done

jq -e --arg release_version "$source_pkgver" '
  .schema == "org.schweisos.release.v1" and
  .id == "schweisos" and
  .name == "SchweisOS" and
  .version.name == $release_version and
  .version.id == $release_version and
  .version.build_id == $release_version and
  .phase == "bootstrap" and
  .release_channel == "rolling" and
  .base.id == "arch" and
  .base.policy == "upstream-first" and
  (.urls | keys | sort) ==
    ["bug_report", "documentation", "home", "privacy_policy", "support"]
' "$metadata_file" >/dev/null || fail 'release.json does not match the identity contract'

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

mkdir -p "${tmp_dir}/artifacts" "${tmp_dir}/build" "${tmp_dir}/sources"
(
  cd "$package_dir"
  BUILDDIR="${tmp_dir}/build" \
  SRCDEST="${tmp_dir}/sources" \
  PKGDEST="${tmp_dir}/artifacts" \
    makepkg --nodeps --cleanbuild --clean --force --noconfirm
)

mapfile -t artifacts < <(
  find "${tmp_dir}/artifacts" -maxdepth 1 -type f \
    -name 'schweisos-release-*.pkg.tar.*' ! -name '*-debug-*' -print | sort
)
[[ "${#artifacts[@]}" -eq 1 ]] || fail "expected one release package, found ${#artifacts[@]}"

package_root="${tmp_dir}/package-root"
mkdir -p "$package_root"
bsdtar -xf "${artifacts[0]}" -C "$package_root"

[[ -L "${package_root}/etc/os-release" ]] || fail '/etc/os-release must be a package-owned symlink'
[[ "$(readlink -- "${package_root}/etc/os-release")" == ../usr/lib/schweisos-release/os-release ]] || \
  fail '/etc/os-release must use the portable relative target'
[[ -f "${package_root}/usr/lib/schweisos-release/os-release" ]] || \
  fail 'canonical os-release payload is missing'
[[ -f "${package_root}/usr/lib/schweisos-release/release.json" ]] || \
  fail 'release metadata payload is missing'
[[ ! -e "${package_root}/usr/lib/os-release" ]] || \
  fail 'schweisos-release must not replace Arch filesystem ownership'

git -C "$project_root" diff --check -- \
  packages/schweisos-release \
  docs/adr/ADR-009-distribution-identity-packages.md \
  docs/architecture/ADD.md \
  iso/profiles/kde \
  tests

printf 'Distribution identity validation passed.\n'
printf '  identity: %s %s (%s)\n' "$PRETTY_NAME" "$VERSION_ID" "$ID"
printf '  base: %s\n' "$ID_LIKE"
printf '  os-release: /etc/os-release -> ../usr/lib/schweisos-release/os-release\n'
