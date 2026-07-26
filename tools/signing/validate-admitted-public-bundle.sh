#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

(( $# == 1 )) || fail 'usage: validate-admitted-public-bundle.sh PUBLIC_BUNDLE_DIR'
supplied_bundle="$1"

for tool in awk bash cmp dirname find git grep readlink sh sort stat; do
  command -v "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
canonical_bundle="${project_root}/packages/schweisos-keyring/keys"
package_dir="${project_root}/packages/schweisos-keyring"
package_pathspec='packages/schweisos-keyring'

"${script_dir}/validate-public-bundle.sh" "$canonical_bundle"
"${script_dir}/validate-public-bundle.sh" "$supplied_bundle"
canonical_bundle="$(readlink -f -- "$canonical_bundle")"
supplied_bundle="$(readlink -f -- "$supplied_bundle")"

expected_files=(
  SHA256SUMS
  release-key-metadata.tsv
  schweisos-release.asc
  schweisos-revoked
  schweisos-trusted
  schweisos.gpg
)
mapfile -t canonical_entries < <(
  find "$canonical_bundle" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
)
[[ "${canonical_entries[*]}" == "${expected_files[*]}" ]] || \
  fail 'canonical keyring package is not in the exact production state'

[[ -z "$(git -C "$project_root" status --porcelain --untracked-files=all -- "$package_pathspec")" ]] || \
  fail 'canonical keyring package has uncommitted or untracked changes'

for bootstrap_template in \
  PKGBUILD.production.in \
  README.production.md \
  future-keys.production.md \
  keyring-policy.production.md; do
  [[ ! -e "${package_dir}/${bootstrap_template}" && ! -L "${package_dir}/${bootstrap_template}" ]] || \
    fail "canonical keyring package retains a bootstrap template: $bootstrap_template"
done
for production_source in PKGBUILD README.md future-keys.md keyring-policy.md schweisos-keyring.install; do
  source_path="${package_dir}/${production_source}"
  [[ -f "$source_path" && ! -L "$source_path" ]] || \
    fail "canonical keyring production source is missing or unsafe: $production_source"
  relative_source="${package_pathspec}/${production_source}"
  [[ "$(git -C "$project_root" ls-files -s -- "$relative_source" | awk '{ print $1 }')" == 100644 ]] || \
    fail "canonical keyring production source must be tracked as 100644: $production_source"
done
bash -n "${package_dir}/PKGBUILD"
sh -n "${package_dir}/schweisos-keyring.install"
grep -Eq '^pkgver=[1-9][0-9]*\.[0-9]+\.[0-9]+$' "${package_dir}/PKGBUILD" || \
  fail 'canonical keyring package does not use an operational version'
grep -Fq 'install=schweisos-keyring.install' "${package_dir}/PKGBUILD" || \
  fail 'canonical keyring package does not activate the reviewed install hook'
grep -Eq "depends=.*'archlinux-keyring'" "${package_dir}/PKGBUILD" || \
  fail 'canonical keyring package lacks Arch trust ordering'

for filename in "${expected_files[@]}"; do
  relative_path="${package_pathspec}/keys/${filename}"
  git -C "$project_root" ls-files --error-unmatch -- "$relative_path" >/dev/null 2>&1 || \
    fail "canonical trust file is not tracked: $relative_path"
  [[ "$(git -C "$project_root" ls-files -s -- "$relative_path" | awk '{ print $1 }')" == 100644 ]] || \
    fail "canonical trust file must be tracked as 100644: $relative_path"
  cmp -s "${canonical_bundle}/${filename}" "${supplied_bundle}/${filename}" || \
    fail "supplied public bundle differs from the repository-admitted trust root: $filename"
  source_link="${package_dir}/${filename}"
  [[ -L "$source_link" && "$(readlink -- "$source_link")" == "keys/${filename}" ]] || \
    fail "canonical keyring package source link is missing or unsafe: $filename"
  relative_link="${package_pathspec}/${filename}"
  [[ "$(git -C "$project_root" ls-files -s -- "$relative_link" | awk '{ print $1 }')" == 120000 ]] || \
    fail "canonical keyring package source link must be tracked as 120000: $filename"
done

git -C "$project_root" diff-index --quiet HEAD -- "$package_pathspec" || \
  fail 'canonical keyring package differs from the reviewed HEAD commit'

printf 'Repository-admitted SchweisOS public bundle validation passed.\n'
printf '  commit: %s\n' "$(git -C "$project_root" rev-parse HEAD)"
