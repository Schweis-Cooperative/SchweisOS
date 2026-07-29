#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'Release artifact validation: FAIL (%s)\n' "$*" >&2
    exit 1
}

require_tool() {
    type -P "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

json_value() {
    local filter=$1
    local file=$2
    jq -r "$filter" "$file"
}

valid_basename() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] && [[ "$1" != *..* ]]
}

for tool in awk basename b2sum cmp comm find grep jq mktemp readlink realpath rm sed sha256sum sort stat wc; do
    require_tool "$tool"
done

(( $# == 1 )) || fail 'usage: validate-release-artifacts.sh RELEASE_DIR'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/.." && pwd -P)"
build_manifest_validator="${project_root}/tests/validate-iso-build-manifest.sh"
[[ -x "$build_manifest_validator" ]] || fail 'build manifest validator is unavailable'

release_dir="$(realpath -m -- "$1")"
[[ -d "$release_dir" && ! -L "$release_dir" ]] || fail 'release directory is not a real directory'

release_id="$(basename -- "$release_dir")"
[[ "$release_id" =~ ^[0-9]{4}\.(0[1-9]|1[0-2])\.(0[1-9]|[12][0-9]|3[01])$ ]] || fail 'release directory name must be YYYY.MM.DD'

for required_dir in iso checksum manifests logs; do
    [[ -d "${release_dir}/${required_dir}" && ! -L "${release_dir}/${required_dir}" ]] || \
        fail "missing required directory: ${required_dir}"
done
[[ -f "${release_dir}/RELEASE_NOTES.md" && ! -L "${release_dir}/RELEASE_NOTES.md" ]] || \
    fail 'missing release notes'
[[ -f "${release_dir}/manifests/build-manifest.json" \
    && ! -L "${release_dir}/manifests/build-manifest.json" ]] || \
    fail 'missing build manifest copy'
[[ -f "${release_dir}/manifests/release-manifest.json" \
    && ! -L "${release_dir}/manifests/release-manifest.json" ]] || \
    fail 'missing release manifest'
[[ -f "${release_dir}/logs/release-artifacts.log" \
    && ! -L "${release_dir}/logs/release-artifacts.log" ]] || \
    fail 'missing release artifact log'

symlink_found="$(find "$release_dir" -type l -print -quit)"
[[ -z "$symlink_found" ]] || fail "symlink found: ${symlink_found}"

world_writable="$(find "$release_dir" \( -type d -o -type f \) -perm -0002 -print -quit)"
[[ -z "$world_writable" ]] || fail "world-writable path found: ${world_writable}"

while IFS= read -r -d '' directory; do
    mode="$(stat -c %a -- "$directory")"
    [[ "$mode" == 755 ]] || fail "directory must be mode 0755: ${directory} (${mode})"
done < <(find "$release_dir" -type d -print0 | sort -z)

while IFS= read -r -d '' file; do
    mode="$(stat -c %a -- "$file")"
    [[ "$mode" == 644 ]] || fail "file must be mode 0644: ${file} (${mode})"
done < <(find "$release_dir" -type f -print0 | sort -z)

mapfile -t iso_files < <(find "${release_dir}/iso" -maxdepth 1 -type f -name '*.iso' -printf '%f\n' | sort)
(( ${#iso_files[@]} == 1 )) || fail "expected exactly one ISO, found ${#iso_files[@]}"
iso_filename="${iso_files[0]}"
valid_basename "$iso_filename" || fail 'ISO filename contains path traversal'
[[ "$iso_filename" =~ ^schweisos-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-x86_64\.iso$ ]] || \
    fail 'ISO filename does not match expected format'
[[ "$iso_filename" == "schweisos-${release_id}-x86_64.iso" ]] || \
    fail 'ISO filename does not match release directory identifier'

iso_path="${release_dir}/iso/${iso_filename}"
[[ -s "$iso_path" ]] || fail 'ISO artifact is empty'
iso_size="$(stat -c %s -- "$iso_path")"
[[ "$iso_size" =~ ^[1-9][0-9]*$ ]] || fail 'ISO size is invalid'

sha256_file="${iso_filename}.sha256"
[[ -f "${release_dir}/checksum/${sha256_file}" \
    && ! -L "${release_dir}/checksum/${sha256_file}" ]] || \
    fail 'missing SHA256 checksum'
mapfile -t sha256_lines <"${release_dir}/checksum/${sha256_file}"
(( ${#sha256_lines[@]} == 1 )) || fail 'SHA256 checksum must contain exactly one line'
read -r sha256_value sha256_name <<<"${sha256_lines[0]}"
[[ "$sha256_value" =~ ^[0-9a-f]{64}$ ]] || fail 'SHA256 checksum value is invalid'
[[ "$sha256_name" == "$iso_filename" ]] || fail 'SHA256 checksum filename mismatch'
valid_basename "$sha256_name" || fail 'SHA256 checksum contains path traversal'
(
    cd -- "${release_dir}/iso"
    sha256sum --check --strict --status -- "../checksum/${sha256_file}"
) || fail 'SHA256 checksum verification failed'

mapfile -t b2_files < <(find "${release_dir}/checksum" -maxdepth 1 -type f -name '*.b2' -printf '%f\n' | sort)
(( ${#b2_files[@]} == 1 )) || fail "expected exactly one BLAKE2b checksum, found ${#b2_files[@]}"
blake2b_file="${b2_files[0]}"
[[ "$blake2b_file" == "${iso_filename}.b2" ]] || fail 'BLAKE2b checksum filename mismatch'
mapfile -t b2_lines <"${release_dir}/checksum/${blake2b_file}"
(( ${#b2_lines[@]} == 1 )) || fail 'BLAKE2b checksum must contain exactly one line'
read -r blake2b_value blake2b_name <<<"${b2_lines[0]}"
[[ "$blake2b_value" =~ ^[0-9a-f]{128}$ ]] || fail 'BLAKE2b checksum value is invalid'
[[ "$blake2b_name" == "$iso_filename" ]] || fail 'BLAKE2b checksum target mismatch'
valid_basename "$blake2b_name" || fail 'BLAKE2b checksum contains path traversal'
(
    cd -- "${release_dir}/iso"
    b2sum --check --strict --status -- "../checksum/${blake2b_file}"
) || fail 'BLAKE2b checksum verification failed'

release_manifest="${release_dir}/manifests/release-manifest.json"
build_manifest="${release_dir}/manifests/build-manifest.json"

if ! jq --indent 2 . "$release_manifest" | cmp -s -- "$release_manifest" -; then
    fail 'release manifest is not canonical unambiguous JSON'
fi
if ! jq -e '
    def exact_keys($expected):
        type == "object" and (keys == ($expected | sort));

    exact_keys([
        "schema", "schema_version", "release_format_version", "release_id",
        "generated_at_utc", "build_timestamp_utc", "git_commit",
        "git_tree_state", "iso_filename", "iso_size_bytes", "sha256",
        "sha256_file", "blake2b_512", "blake2b_512_file", "profile", "arch",
        "archiso_version", "source_date_epoch", "validator_versions",
        "validator_results"
    ])
    and .schema == "schweisos.release-artifact-manifest.v2"
    and .schema_version == 2
    and .release_format_version == "2"
    and (.release_id | type == "string"
        and test("^[0-9]{4}\\.(0[1-9]|1[0-2])\\.(0[1-9]|[12][0-9]|3[01])$"))
    and (.generated_at_utc | type == "string"
        and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and (.build_timestamp_utc | type == "string"
        and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and (.git_commit | type == "string" and test("^[0-9a-f]{40,64}$"))
    and .git_tree_state == "clean"
    and (.iso_filename | type == "string"
        and test("^schweisos-[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}-x86_64\\.iso$"))
    and (.iso_size_bytes | type == "number" and . > 0 and floor == .)
    and (.sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and (.sha256_file | type == "string" and test("^[A-Za-z0-9._+-]+\\.sha256$"))
    and (.blake2b_512 | type == "string" and test("^[0-9a-f]{128}$"))
    and (.blake2b_512_file | type == "string" and test("^[A-Za-z0-9._+-]+\\.b2$"))
    and (.profile | type == "string" and test("^[a-z0-9._+-]+$"))
    and .arch == "x86_64"
    and (.archiso_version | type == "string" and test("^[A-Za-z0-9.+_~:-]+$"))
    and (.source_date_epoch | type == "number" and . >= 0 and floor == .)
    and (.validator_versions | exact_keys(["release_artifact_validator"]))
    and .validator_versions.release_artifact_validator == "2"
    and (.validator_results | exact_keys([
        "build_environment", "installer_config", "iso_profile",
        "built_iso_identity", "built_iso_boot", "artifact",
        "release_artifacts"
    ]))
    and ([.validator_results[]] | all(. == "pass"))
' "$release_manifest" >/dev/null; then
    fail 'release manifest schema, types, or success invariants are invalid'
fi

[[ "$(json_value '.release_id' "$release_manifest")" == "$release_id" ]] || fail 'release id mismatch'
[[ "$(json_value '.iso_filename' "$release_manifest")" == "$iso_filename" ]] || fail 'manifest ISO mismatch'
[[ "$(json_value '.iso_size_bytes' "$release_manifest")" == "$iso_size" ]] || fail 'manifest ISO size mismatch'
[[ "$(json_value '.sha256' "$release_manifest")" == "$sha256_value" ]] || fail 'manifest SHA256 mismatch'
[[ "$(json_value '.sha256_file' "$release_manifest")" == "$sha256_file" ]] || fail 'manifest SHA256 file mismatch'
manifest_blake2b="$(json_value '.blake2b_512' "$release_manifest")"
manifest_b2_file="$(json_value '.blake2b_512_file' "$release_manifest")"
[[ "$manifest_blake2b" == "$blake2b_value" ]] || fail 'manifest BLAKE2b mismatch'
[[ "$manifest_b2_file" == "$blake2b_file" ]] || fail 'manifest BLAKE2b file mismatch'
[[ "$(json_value '.arch' "$release_manifest")" == x86_64 ]] || fail 'architecture value mismatch'
for timestamp_key in generated_at_utc build_timestamp_utc; do
    timestamp_value="$(json_value ".${timestamp_key}" "$release_manifest")"
    [[ "$timestamp_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || \
        fail "${timestamp_key} must be a UTC timestamp"
done

"$build_manifest_validator" --release "$build_manifest" "$iso_path" >/dev/null || \
    fail 'copied build manifest or ISO binding validation failed'
for validation_key in build_environment installer_config iso_profile built_iso_identity built_iso_boot artifact; do
    [[ "$(json_value ".validation.${validation_key}" "$build_manifest")" == pass ]] || \
        fail "copied build manifest validator did not pass: ${validation_key}"
    [[ "$(json_value ".validator_results.${validation_key}" "$release_manifest")" == pass ]] || \
        fail "release manifest validator did not pass: ${validation_key}"
done
[[ "$(json_value '.validator_results.release_artifacts' "$release_manifest")" == pass ]] || \
    fail 'release artifact validator result did not pass'
[[ "$(json_value '.build_timestamp_utc' "$release_manifest")" \
    == "$(json_value '.build_timestamp_utc' "$build_manifest")" ]] || \
    fail 'release/build manifest timestamp mismatch'
[[ "$(json_value '.git_commit' "$release_manifest")" \
    == "$(json_value '.git.commit' "$build_manifest")" ]] || \
    fail 'release/build manifest Git commit mismatch'
[[ "$(json_value '.archiso_version' "$release_manifest")" \
    == "$(json_value '.archiso_version' "$build_manifest")" ]] || \
    fail 'release/build manifest Archiso version mismatch'
[[ "$(json_value '.source_date_epoch' "$release_manifest")" \
    == "$(json_value '.source_date_epoch' "$build_manifest")" ]] || \
    fail 'release/build manifest SOURCE_DATE_EPOCH mismatch'
[[ "$(json_value '.profile' "$release_manifest")" \
    == "$(json_value '.profile' "$build_manifest")" ]] || \
    fail 'release/build manifest profile mismatch'

comparison_tmp="$(mktemp --directory)"
trap 'rm -rf -- "$comparison_tmp"' EXIT

generated_at="$(json_value '.generated_at_utc' "$release_manifest")"
git_commit="$(json_value '.git_commit' "$release_manifest")"
environment_validation="$(json_value '.validator_results.build_environment' "$release_manifest")"
installer_validation="$(json_value '.validator_results.installer_config' "$release_manifest")"
profile_validation="$(json_value '.validator_results.iso_profile' "$release_manifest")"
built_identity_validation="$(json_value '.validator_results.built_iso_identity' "$release_manifest")"
built_boot_validation="$(json_value '.validator_results.built_iso_boot' "$release_manifest")"
artifact_validation="$(json_value '.validator_results.artifact' "$release_manifest")"

{
    printf '# SchweisOS %s Release Artifact Summary\n\n' "$release_id"
    printf 'Generated: %s\n\n' "$generated_at"
    printf 'Git commit: `%s`\n\n' "$git_commit"
    printf 'ISO: `%s`\n\n' "$iso_filename"
    printf 'Size: %s bytes\n\n' "$iso_size"
    printf 'Validator summary:\n\n'
    printf '%s\n' "- Build environment: \`${environment_validation}\`"
    printf '%s\n' "- Installer config: \`${installer_validation}\`"
    printf '%s\n' "- ISO profile: \`${profile_validation}\`"
    printf '%s\n' "- Built ISO identity: \`${built_identity_validation}\`"
    printf '%s\n' "- Built ISO boot: \`${built_boot_validation}\`"
    printf '%s\n' "- Build artifact: \`${artifact_validation}\`"
    printf '%s\n\n' '- Release artifacts: `pass`'
    printf 'Checksum summary:\n\n'
    printf '%s\n' "- SHA256: \`${sha256_value}\`"
    printf '%s\n' "- BLAKE2b-512: \`${blake2b_value}\`"
    printf '\nThis summary is generated from local release evidence. It is not a signature or publication approval.\n'
} >"${comparison_tmp}/expected-release-notes.md"
cmp -s "${comparison_tmp}/expected-release-notes.md" "${release_dir}/RELEASE_NOTES.md" || \
    fail 'release notes do not match the validated manifest evidence'

{
    printf 'release_id=%s\n' "$release_id"
    printf 'generated_at_utc=%s\n' "$generated_at"
    printf 'iso=%s\n' "$iso_filename"
    printf 'sha256=%s\n' "$sha256_value"
    printf 'status=prepared\n'
} >"${comparison_tmp}/expected-release-artifacts.log"
cmp -s "${comparison_tmp}/expected-release-artifacts.log" \
    "${release_dir}/logs/release-artifacts.log" || \
    fail 'release artifact log does not match the validated manifest evidence'

if grep -rIEq '(/home/|/root/|machine-id|hostname|ip_address|private_key|PASSWORD|TOKEN|SECRET)' \
    "$build_manifest" "$release_manifest" "${release_dir}/RELEASE_NOTES.md" \
    "${release_dir}/logs/release-artifacts.log"; then
    fail 'private information pattern found in release metadata'
fi

find "$release_dir" -printf '%P\n' | sort >"${comparison_tmp}/actual-files"
{
    printf '\n'
    printf 'RELEASE_NOTES.md\n'
    printf 'checksum\n'
    printf 'checksum/%s\n' "$sha256_file"
    printf 'checksum/%s\n' "$blake2b_file"
    printf 'iso\n'
    printf 'iso/%s\n' "$iso_filename"
    printf 'logs\n'
    printf 'logs/release-artifacts.log\n'
    printf 'manifests\n'
    printf 'manifests/build-manifest.json\n'
    printf 'manifests/release-manifest.json\n'
} | sort >"${comparison_tmp}/expected-files"
unexpected="$(comm -13 "${comparison_tmp}/expected-files" "${comparison_tmp}/actual-files")"
missing="$(comm -23 "${comparison_tmp}/expected-files" "${comparison_tmp}/actual-files")"
rm -rf -- "$comparison_tmp"
trap - EXIT
[[ -z "$unexpected" ]] || fail "unexpected files: ${unexpected}"
[[ -z "$missing" ]] || fail "missing files: ${missing}"

printf 'Release artifact validation: PASS\n'
printf '  release: %s\n' "$release_id"
printf '  iso: %s (%s bytes)\n' "$iso_filename" "$iso_size"
printf '  sha256: %s\n' "$sha256_value"
printf '  blake2b_512: %s\n' "$blake2b_value"
