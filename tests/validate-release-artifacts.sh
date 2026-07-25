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
    local key=$1
    local file=$2
    sed -nE 's/^[[:space:]]*"'"$key"'"[[:space:]]*:[[:space:]]*"?([^",}]*)"?[,]?[[:space:]]*$/\1/p' "$file" | head -n 1
}

valid_basename() {
    [[ "$1" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*$ ]] && [[ "$1" != *..* ]]
}

for tool in awk basename b2sum comm find grep mktemp readlink realpath rm sed sha256sum sort stat wc; do
    require_tool "$tool"
done

(( $# == 1 )) || fail 'usage: validate-release-artifacts.sh RELEASE_DIR'

release_dir="$(realpath -m -- "$1")"
[[ -d "$release_dir" && ! -L "$release_dir" ]] || fail 'release directory is not a real directory'

release_id="$(basename -- "$release_dir")"
[[ "$release_id" =~ ^[0-9]{4}\.(0[1-9]|1[0-2])$ ]] || fail 'release directory name must be YYYY.MM'

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
if (( ${#b2_files[@]} > 1 )); then
    fail 'multiple BLAKE2b checksum files found'
fi
blake2b_value=''
blake2b_file=''
if (( ${#b2_files[@]} == 1 )); then
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
fi

release_manifest="${release_dir}/manifests/release-manifest.json"
build_manifest="${release_dir}/manifests/build-manifest.json"

[[ "$(head -n 1 -- "$release_manifest")" == "{" ]] || fail 'release manifest is not JSON object syntax'
[[ "$(tail -n 1 -- "$release_manifest")" == "}" ]] || fail 'release manifest is not JSON object syntax'
[[ "$(json_value schema "$release_manifest")" == schweisos.release-artifact-manifest.v1 ]] || \
    fail 'release manifest schema mismatch'
[[ "$(json_value schema_version "$release_manifest")" == 1 ]] || fail 'release manifest schema version mismatch'
[[ "$(json_value release_format_version "$release_manifest")" == 1 ]] || \
    fail 'release format version mismatch'
[[ "$(json_value release_id "$release_manifest")" == "$release_id" ]] || fail 'release id mismatch'
[[ "$(json_value iso_filename "$release_manifest")" == "$iso_filename" ]] || fail 'manifest ISO mismatch'
[[ "$(json_value iso_size_bytes "$release_manifest")" == "$iso_size" ]] || fail 'manifest ISO size mismatch'
[[ "$(json_value sha256 "$release_manifest")" == "$sha256_value" ]] || fail 'manifest SHA256 mismatch'
[[ "$(json_value sha256_file "$release_manifest")" == "$sha256_file" ]] || fail 'manifest SHA256 file mismatch'
manifest_blake2b="$(json_value blake2b_512 "$release_manifest")"
manifest_b2_file="$(json_value blake2b_512_file "$release_manifest")"
if [[ -n "$blake2b_file" ]]; then
    [[ "$manifest_blake2b" == "$blake2b_value" ]] || fail 'manifest BLAKE2b mismatch'
    [[ "$manifest_b2_file" == "$blake2b_file" ]] || fail 'manifest BLAKE2b file mismatch'
else
    [[ "$manifest_blake2b" == null && "$manifest_b2_file" == null ]] || \
        fail 'manifest advertises missing BLAKE2b checksum'
fi
[[ "$(json_value profile "$release_manifest")" =~ ^[a-z0-9._+-]+$ ]] || fail 'profile value is invalid'
[[ "$(json_value arch "$release_manifest")" == x86_64 ]] || fail 'architecture value mismatch'
[[ "$(json_value git_tree_state "$release_manifest")" == clean ]] || fail 'git tree state must be clean'
[[ "$(json_value git_commit "$release_manifest")" =~ ^[0-9a-f]{40,64}$ ]] || fail 'git commit is invalid'
for timestamp_key in generated_at_utc build_timestamp_utc; do
    timestamp_value="$(json_value "$timestamp_key" "$release_manifest")"
    [[ "$timestamp_value" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]] || \
        fail "${timestamp_key} must be a UTC timestamp"
done

[[ "$(json_value status "$build_manifest")" == success ]] || fail 'copied build manifest is not successful'
[[ "$(json_value expected_iso_name "$build_manifest")" == "$iso_filename" ]] || \
    fail 'copied build manifest expected ISO mismatch'

if grep -rIEq '(/home/|/root/|machine-id|hostname|ip_address|private_key|PASSWORD|TOKEN|SECRET)' \
    "$release_manifest" "${release_dir}/RELEASE_NOTES.md" "${release_dir}/logs/release-artifacts.log"; then
    fail 'private information pattern found in release metadata'
fi

comparison_tmp="$(mktemp --directory)"
trap 'rm -rf -- "$comparison_tmp"' EXIT
find "$release_dir" -printf '%P\n' | sort >"${comparison_tmp}/actual-files"
{
    printf '\n'
    printf 'RELEASE_NOTES.md\n'
    printf 'checksum\n'
    printf 'checksum/%s\n' "$sha256_file"
    if [[ -n "$blake2b_file" ]]; then
        printf 'checksum/%s\n' "$blake2b_file"
    fi
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
if [[ -n "$blake2b_value" ]]; then
    printf '  blake2b_512: %s\n' "$blake2b_value"
fi
