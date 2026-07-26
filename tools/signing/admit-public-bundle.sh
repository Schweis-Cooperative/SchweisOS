#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

public_bundle=''
ceremony_record=''
fingerprint_review_acknowledged=false

usage() {
  cat <<'EOF'
Usage: admit-public-bundle.sh OPTIONS

Required options:
  --public-bundle PATH
  --ceremony-record PATH
  --acknowledge-fingerprint-review
  -h, --help

Admit a reviewed production public bundle into schweisos-keyring. This command
reads public material only and requires a clean tracked repository worktree.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

while (( $# > 0 )); do
  case "$1" in
    --public-bundle) (( $# >= 2 )) || fail 'missing value for --public-bundle'; public_bundle="$2"; shift 2 ;;
    --ceremony-record) (( $# >= 2 )) || fail 'missing value for --ceremony-record'; ceremony_record="$2"; shift 2 ;;
    --acknowledge-fingerprint-review) fingerprint_review_acknowledged=true; shift ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ -n "$public_bundle" && -n "$ceremony_record" ]] || fail 'all path options are required'
[[ "$fingerprint_review_acknowledged" == true ]] || \
  fail '--acknowledge-fingerprint-review is required'

for tool in awk bash chmod cp dirname find git grep install ln makepkg mktemp mv readlink rm sed sha256sum sort stat; do
  require_tool "$tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(git -C "$script_dir" rev-parse --show-toplevel)"
package_dir="${project_root}/packages/schweisos-keyring"
keys_dir="${package_dir}/keys"
template="${package_dir}/PKGBUILD.production.in"
production_readme="${package_dir}/README.production.md"
production_future_keys="${package_dir}/future-keys.production.md"
production_keyring_policy="${package_dir}/keyring-policy.production.md"

"${script_dir}/validate-public-bundle.sh" "$public_bundle"
public_bundle="$(readlink -f -- "$public_bundle")"
[[ -f "$ceremony_record" && ! -L "$ceremony_record" && -s "$ceremony_record" ]] || \
  fail 'accepted ceremony record is missing, empty, or unsafe'
ceremony_record="$(readlink -f -- "$ceremony_record")"
ceremony_record_mode="$(stat -c '%a' "$ceremony_record")"
[[ "$ceremony_record_mode" =~ ^[0-7]{3,4}$ ]] || fail 'ceremony record mode is unreadable'
(( (8#$ceremony_record_mode & 8#022) == 0 )) || \
  fail 'ceremony record must not be writable by group or other'
grep -Eq '^- Ceremony result:[[:space:]]*accepted[[:space:]]*$' "$ceremony_record" || \
  fail 'ceremony record does not contain an accepted result'
grep -Eq '^- Reviewer decision and date \(UTC\):[[:space:]]*[^[:space:]].*$' "$ceremony_record" || \
  fail 'ceremony record lacks the final reviewer decision'
reviewed_commit="$(
  awk -F ': ' '$1 == "- Repository commit reviewed" { print $2 }' "$ceremony_record"
)"
[[ "$reviewed_commit" =~ ^[a-f0-9]{40}$ ]] || \
  fail 'ceremony record must contain one full reviewed Git commit'
[[ "$reviewed_commit" == "$(git -C "$project_root" rev-parse HEAD)" ]] || \
  fail 'ceremony record is not bound to the current reviewed Git commit'

metadata="${public_bundle}/release-key-metadata.tsv"
metadata_fingerprint() {
  local key="$1"
  awk -F '\t' -v key="$key" '$1 == key { print $2 }' "$metadata"
}
primary_fingerprint="$(metadata_fingerprint primary_fingerprint)"
package_fingerprint="$(metadata_fingerprint package_signing_fingerprint)"
database_fingerprint="$(metadata_fingerprint database_signing_fingerprint)"
reading_fields=(
  "First reading certification-only primary fingerprint|${primary_fingerprint}"
  "First reading package-signing subkey fingerprint|${package_fingerprint}"
  "First reading repository-database-signing subkey fingerprint|${database_fingerprint}"
  "Second reading certification-only primary fingerprint|${primary_fingerprint}"
  "Second reading package-signing subkey fingerprint|${package_fingerprint}"
  "Second reading repository-database-signing subkey fingerprint|${database_fingerprint}"
)
for reading_field in "${reading_fields[@]}"; do
  IFS='|' read -r label expected_fingerprint <<<"$reading_field"
  mapfile -t recorded_values < <(
    awk -v prefix="- ${label}:" '
      index($0, prefix) == 1 {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]+/, "", value)
        print value
      }
    ' "$ceremony_record"
  )
  (( ${#recorded_values[@]} == 1 )) || fail "ceremony record field must appear exactly once: $label"
  [[ "${recorded_values[0]}" == "$expected_fingerprint" ]] || \
    fail "ceremony record fingerprint mismatch: $label"
done

for operational_template in \
  "$template" \
  "$production_readme" \
  "$production_future_keys" \
  "$production_keyring_policy"; do
  [[ -f "$operational_template" && ! -L "$operational_template" ]] || \
    fail "operational keyring package template is missing or unsafe: $operational_template"
done
[[ -f "${package_dir}/schweisos-keyring.install" && ! -L "${package_dir}/schweisos-keyring.install" ]] || \
  fail 'operational keyring install script is missing or unsafe'
[[ -d "$keys_dir" && ! -L "$keys_dir" ]] || fail 'bootstrap key directory is missing or unsafe'

assert_operator_custody() {
  local path="$1"
  local mode
  [[ "$(stat -c '%u' "$path")" == "$EUID" ]] || \
    fail "admission source is not owned by the invoking user: $path"
  mode="$(stat -c '%a' "$path")"
  [[ "$mode" =~ ^[0-7]{3,4}$ ]] || fail "admission source mode is unreadable: $path"
  (( (8#$mode & 8#022) == 0 )) || \
    fail "admission source is group- or world-writable: $path"
}
for custody_path in \
  "$project_root" \
  "${project_root}/packages" \
  "$package_dir" \
  "$keys_dir" \
  "$template" \
  "$production_readme" \
  "$production_future_keys" \
  "$production_keyring_policy" \
  "${package_dir}/schweisos-keyring.install"; do
  assert_operator_custody "$custody_path"
done

bootstrap_entries="$(find "$keys_dir" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort)"
[[ "$bootstrap_entries" == README.md ]] || \
  fail 'keyring package is not in the exact bootstrap state'
[[ -z "$(git -C "$project_root" status --porcelain --untracked-files=no)" ]] || \
  fail 'tracked repository worktree must be clean before admission'

stage_dir="$(mktemp -d --tmpdir="${package_dir}/.." .schweisos-keyring-admission.XXXXXX)"
backup_dir="$(mktemp -d --tmpdir="${package_dir}/.." .schweisos-keyring-backup.XXXXXX)"
transition_started=false
transition_complete=false
cleanup() {
  local status=$?
  if [[ "$transition_started" == true && "$transition_complete" == false ]]; then
    rm -f -- \
      "${package_dir}/schweisos.gpg" \
      "${package_dir}/schweisos-trusted" \
      "${package_dir}/schweisos-revoked" \
      "${package_dir}/schweisos-release.asc" \
      "${package_dir}/release-key-metadata.tsv" \
      "${package_dir}/SHA256SUMS"
    [[ ! -e "${backup_dir}/keys" ]] || { rm -rf -- "$keys_dir"; mv -T -- "${backup_dir}/keys" "$keys_dir"; }
    for filename in \
      PKGBUILD README.md future-keys.md keyring-policy.md \
      PKGBUILD.production.in README.production.md \
      future-keys.production.md keyring-policy.production.md; do
      [[ ! -e "${backup_dir}/${filename}" ]] || mv -fT -- "${backup_dir}/${filename}" "${package_dir}/${filename}"
    done
  fi
  rm -rf -- "$stage_dir" "$backup_dir"
  exit "$status"
}
trap cleanup EXIT

mkdir -m 0755 -- "${stage_dir}/keys"
for filename in SHA256SUMS release-key-metadata.tsv schweisos-release.asc schweisos-revoked schweisos-trusted schweisos.gpg; do
  install -m 0644 -- "${public_bundle}/${filename}" "${stage_dir}/keys/${filename}"
done

hash_of() {
  sha256sum "$1" | awk '{ print $1 }'
}
sed \
  -e "s/@SCHWEISOS_GPG_SHA256@/$(hash_of "${public_bundle}/schweisos.gpg")/" \
  -e "s/@SCHWEISOS_TRUSTED_SHA256@/$(hash_of "${public_bundle}/schweisos-trusted")/" \
  -e "s/@SCHWEISOS_REVOKED_SHA256@/$(hash_of "${public_bundle}/schweisos-revoked")/" \
  -e "s/@SCHWEISOS_RELEASE_ASC_SHA256@/$(hash_of "${public_bundle}/schweisos-release.asc")/" \
  -e "s/@RELEASE_KEY_METADATA_SHA256@/$(hash_of "${public_bundle}/release-key-metadata.tsv")/" \
  -e "s/@PUBLIC_BUNDLE_SHA256SUMS_SHA256@/$(hash_of "${public_bundle}/SHA256SUMS")/" \
  -e "s/@KEYRING_POLICY_SHA256@/$(hash_of "$production_keyring_policy")/" \
  -e "s/@FUTURE_KEYS_SHA256@/$(hash_of "$production_future_keys")/" \
  -- "$template" >"${stage_dir}/PKGBUILD"
chmod 0644 -- "${stage_dir}/PKGBUILD"
install -m 0644 -- "$production_readme" "${stage_dir}/README.md"
install -m 0644 -- "$production_future_keys" "${stage_dir}/future-keys.md"
install -m 0644 -- "$production_keyring_policy" "${stage_dir}/keyring-policy.md"
bash -n "${stage_dir}/PKGBUILD"
grep -Eq '@[A-Z0-9_]+@' "${stage_dir}/PKGBUILD" && fail 'unresolved operational PKGBUILD token'

cp -a -- "$keys_dir" "${backup_dir}/keys"
cp -a -- \
  "${package_dir}/PKGBUILD" \
  "${package_dir}/README.md" \
  "${package_dir}/future-keys.md" \
  "${package_dir}/keyring-policy.md" \
  "$template" \
  "$production_readme" \
  "$production_future_keys" \
  "$production_keyring_policy" \
  "$backup_dir/"
transition_started=true
rm -rf -- "$keys_dir"
mv -T -- "${stage_dir}/keys" "$keys_dir"
mv -fT -- "${stage_dir}/PKGBUILD" "${package_dir}/PKGBUILD"
mv -fT -- "${stage_dir}/README.md" "${package_dir}/README.md"
mv -fT -- "${stage_dir}/future-keys.md" "${package_dir}/future-keys.md"
mv -fT -- "${stage_dir}/keyring-policy.md" "${package_dir}/keyring-policy.md"
rm -f -- \
  "$template" \
  "$production_readme" \
  "$production_future_keys" \
  "$production_keyring_policy"
for filename in SHA256SUMS release-key-metadata.tsv schweisos-release.asc schweisos-revoked schweisos-trusted schweisos.gpg; do
  ln -s -- "keys/${filename}" "${package_dir}/${filename}"
done

"${script_dir}/validate-public-bundle.sh" "$keys_dir"
(
  cd -- "$package_dir"
  makepkg --printsrcinfo >/dev/null
)
"${project_root}/tests/validate-keyring-package.sh"
transition_complete=true

printf 'Production public bundle admitted into schweisos-keyring.\n'
printf 'Review and commit the resulting package-only worktree change before building.\n'
