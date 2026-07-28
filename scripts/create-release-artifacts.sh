#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

usage() {
    cat <<'EOF'
Usage: scripts/create-release-artifacts.sh --release-id YYYY.MM.DD --iso PATH --build-manifest PATH [--output-root PATH] [--profile NAME]

Create an immutable local release artifact directory from a successful ISO
build output. This command does not build, sign, publish, or upload anything.
EOF
}

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_tool() {
    type -P "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

json_string() {
    local value=$1
    value=${value//\\/\\\\}
    value=${value//\"/\\\"}
    value=${value//$'\n'/\\n}
    value=${value//$'\r'/\\r}
    value=${value//$'\t'/\\t}
    printf '"%s"' "$value"
}

json_string_or_null() {
    if [[ -n "$1" ]]; then
        json_string "$1"
    else
        printf 'null'
    fi
}

json_bool_or_null() {
    case "$1" in
        true|false) printf '%s' "$1" ;;
        *) printf 'null' ;;
    esac
}

json_number_or_null() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        printf '%s' "$1"
    else
        printf 'null'
    fi
}

json_value() {
    local filter=$1
    local file=$2
    jq -r "$filter" "$file"
}

for tool in awk basename b2sum chmod cp date dirname find git grep install mkdir mktemp mv \
    jq realpath rm sed sha256sum sort stat wc; do
    require_tool "$tool"
done

release_id=''
iso_input=''
build_manifest_input=''
profile=''
output_root=''

while (( $# > 0 )); do
    case "$1" in
        --release-id)
            (( $# >= 2 )) || fail '--release-id requires a value'
            release_id=$2
            shift 2
            ;;
        --iso)
            (( $# >= 2 )) || fail '--iso requires a value'
            iso_input=$2
            shift 2
            ;;
        --build-manifest)
            (( $# >= 2 )) || fail '--build-manifest requires a value'
            build_manifest_input=$2
            shift 2
            ;;
        --output-root)
            (( $# >= 2 )) || fail '--output-root requires a value'
            output_root=$2
            shift 2
            ;;
        --profile)
            (( $# >= 2 )) || fail '--profile requires a value'
            profile=$2
            shift 2
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
done

[[ "$release_id" =~ ^[0-9]{4}\.(0[1-9]|1[0-2])\.(0[1-9]|[12][0-9]|3[01])$ ]] || \
    fail 'release id must use YYYY.MM.DD format'
[[ -n "$iso_input" ]] || fail '--iso is required'
[[ -n "$build_manifest_input" ]] || fail '--build-manifest is required'
[[ -z "$profile" || "$profile" =~ ^[a-z0-9._+-]+$ ]] || fail 'profile name is invalid'

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
build_manifest_validator="${repo_root}/tests/validate-iso-build-manifest.sh"
[[ -x "$build_manifest_validator" ]] || fail 'build manifest validator is unavailable'

if [[ -z "$output_root" ]]; then
    output_root="${repo_root}/release"
else
    output_root="$(realpath -m -- "$output_root")"
fi

case "$output_root" in
    "$repo_root/release"|"$repo_root/release"/*) ;;
    *) fail 'output root must stay inside the repository release directory' ;;
esac

[[ "$output_root" != "$repo_root" && "$output_root" != / && "$output_root" != "$repo_root/release/.." ]] || \
    fail 'refusing unsafe output root'

mkdir -p -- "$output_root"
[[ -d "$output_root" && ! -L "$output_root" ]] || \
    fail 'output root must be a real directory'

release_dir="${output_root}/${release_id}"
[[ ! -e "$release_dir" && ! -L "$release_dir" ]] || \
    fail "release already exists: ${release_id}"

[[ -f "$iso_input" && ! -L "$iso_input" ]] || fail 'ISO must be a regular non-symlink file'
[[ -f "$build_manifest_input" && ! -L "$build_manifest_input" ]] || \
    fail 'build manifest must be a regular non-symlink file'
iso_path="$(realpath -e -- "$iso_input")"
build_manifest_path="$(realpath -e -- "$build_manifest_input")"
[[ -f "$iso_path" && ! -L "$iso_path" ]] || fail 'ISO must be a regular file'
[[ -s "$iso_path" ]] || fail 'ISO artifact is empty'
[[ -f "$build_manifest_path" && ! -L "$build_manifest_path" ]] || \
    fail 'build manifest must be a regular file'

iso_filename="$(basename -- "$iso_path")"
[[ "$iso_filename" == "schweisos-${release_id}-x86_64.iso" ]] || \
    fail 'ISO filename does not match the requested release identifier'
"$build_manifest_validator" --release "$build_manifest_path" "$iso_path" >/dev/null || \
    fail 'build manifest or ISO binding validation failed'

build_timestamp="$(json_value '.build_timestamp_utc' "$build_manifest_path")"
git_commit="$(json_value '.git.commit' "$build_manifest_path")"
archiso_version="$(json_value '.archiso_version' "$build_manifest_path")"
source_date_epoch="$(json_value '.source_date_epoch' "$build_manifest_path")"
build_profile="$(json_value '.profile' "$build_manifest_path")"
environment_validation="$(json_value '.validation.build_environment' "$build_manifest_path")"
profile_validation="$(json_value '.validation.iso_profile' "$build_manifest_path")"
built_identity_validation="$(json_value '.validation.built_iso_identity' "$build_manifest_path")"
built_boot_validation="$(json_value '.validation.built_iso_boot' "$build_manifest_path")"
artifact_validation="$(json_value '.validation.artifact' "$build_manifest_path")"

if [[ -n "$profile" && "$profile" != "$build_profile" ]]; then
    fail 'requested profile does not match the build manifest'
fi
profile=$build_profile

iso_size="$(stat -c %s -- "$iso_path")"
[[ "$iso_size" =~ ^[1-9][0-9]*$ ]] || fail 'ISO size is invalid'
iso_sha256="$(sha256sum -- "$iso_path" | awk 'NR == 1 { print $1 }')"
[[ "$iso_sha256" =~ ^[0-9a-f]{64}$ ]] || fail 'ISO SHA256 is invalid'

staging_parent="$(mktemp --directory --tmpdir="$output_root" ".${release_id}.tmp.XXXXXX")"
tmp_dir="${staging_parent}/${release_id}"
mkdir -- "$tmp_dir"
cleanup() {
    if [[ -n "${staging_parent:-}" && -d "$staging_parent" && ! -L "$staging_parent" ]]; then
        rm -rf -- "$staging_parent"
    fi
}
trap cleanup EXIT INT TERM HUP

install -d -m 0755 -- \
    "${tmp_dir}/iso" \
    "${tmp_dir}/checksum" \
    "${tmp_dir}/manifests" \
    "${tmp_dir}/logs"

install -m 0644 -- "$iso_path" "${tmp_dir}/iso/${iso_filename}"
install -m 0644 -- "$build_manifest_path" "${tmp_dir}/manifests/build-manifest.json"

sha256_file="${iso_filename}.sha256"
(
    cd -- "${tmp_dir}/iso"
    sha256sum -- "$iso_filename"
) >"${tmp_dir}/checksum/${sha256_file}"
chmod 0644 -- "${tmp_dir}/checksum/${sha256_file}"
(
    cd -- "${tmp_dir}/iso"
    sha256sum --check --strict --status -- "../checksum/${sha256_file}"
) || fail 'generated SHA256 checksum failed verification'
read -r sha256_value sha256_name <"${tmp_dir}/checksum/${sha256_file}"
[[ "$sha256_name" == "$iso_filename" && "$sha256_value" =~ ^[0-9a-f]{64}$ ]] || \
    fail 'generated SHA256 checksum format is invalid'

blake2b_file="${iso_filename}.b2"
(
    cd -- "${tmp_dir}/iso"
    b2sum -- "$iso_filename"
) >"${tmp_dir}/checksum/${blake2b_file}"
chmod 0644 -- "${tmp_dir}/checksum/${blake2b_file}"
(
    cd -- "${tmp_dir}/iso"
    b2sum --check --strict --status -- "../checksum/${blake2b_file}"
) || fail 'generated BLAKE2b-512 checksum failed verification'
read -r blake2b_value blake2b_name <"${tmp_dir}/checksum/${blake2b_file}"
[[ "$blake2b_name" == "$iso_filename" && "$blake2b_value" =~ ^[0-9a-f]{128}$ ]] || \
    fail 'generated BLAKE2b-512 checksum format is invalid'

generated_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
release_manifest="${tmp_dir}/manifests/release-manifest.json"
{
    printf '{\n'
    printf '  "schema": "schweisos.release-artifact-manifest.v2",\n'
    printf '  "schema_version": 2,\n'
    printf '  "release_format_version": "2",\n'
    printf '  "release_id": %s,\n' "$(json_string "$release_id")"
    printf '  "generated_at_utc": %s,\n' "$(json_string "$generated_at")"
    printf '  "build_timestamp_utc": %s,\n' "$(json_string "$build_timestamp")"
    printf '  "git_commit": %s,\n' "$(json_string "$git_commit")"
    printf '  "git_tree_state": "clean",\n'
    printf '  "iso_filename": %s,\n' "$(json_string "$iso_filename")"
    printf '  "iso_size_bytes": %s,\n' "$(json_number_or_null "$iso_size")"
    printf '  "sha256": %s,\n' "$(json_string "$sha256_value")"
    printf '  "sha256_file": %s,\n' "$(json_string "$sha256_file")"
    printf '  "blake2b_512": %s,\n' "$(json_string_or_null "$blake2b_value")"
    printf '  "blake2b_512_file": %s,\n' "$(json_string_or_null "$blake2b_file")"
    printf '  "profile": %s,\n' "$(json_string "$profile")"
    printf '  "arch": "x86_64",\n'
    printf '  "archiso_version": %s,\n' "$(json_string_or_null "$archiso_version")"
    printf '  "source_date_epoch": %s,\n' "$(json_number_or_null "$source_date_epoch")"
    printf '  "validator_versions": {\n'
    printf '    "release_artifact_validator": "2"\n'
    printf '  },\n'
    printf '  "validator_results": {\n'
    printf '    "build_environment": %s,\n' "$(json_string "$environment_validation")"
    printf '    "iso_profile": %s,\n' "$(json_string "$profile_validation")"
    printf '    "built_iso_identity": %s,\n' "$(json_string "$built_identity_validation")"
    printf '    "built_iso_boot": %s,\n' "$(json_string "$built_boot_validation")"
    printf '    "artifact": %s,\n' "$(json_string "$artifact_validation")"
    printf '    "release_artifacts": "pass"\n'
    printf '  }\n'
    printf '}\n'
} >"$release_manifest"
chmod 0644 -- "$release_manifest"

notes_path="${tmp_dir}/RELEASE_NOTES.md"
{
    printf '# SchweisOS %s Release Artifact Summary\n\n' "$release_id"
    printf 'Generated: %s\n\n' "$generated_at"
    printf 'Git commit: `%s`\n\n' "$git_commit"
    printf 'ISO: `%s`\n\n' "$iso_filename"
    printf 'Size: %s bytes\n\n' "$iso_size"
    printf 'Validator summary:\n\n'
    printf '%s\n' "- Build environment: \`${environment_validation}\`"
    printf '%s\n' "- ISO profile: \`${profile_validation}\`"
    printf '%s\n' "- Built ISO identity: \`${built_identity_validation}\`"
    printf '%s\n' "- Built ISO boot: \`${built_boot_validation}\`"
    printf '%s\n' "- Build artifact: \`${artifact_validation}\`"
    printf '%s\n\n' '- Release artifacts: `pass`'
    printf 'Checksum summary:\n\n'
    printf '%s\n' "- SHA256: \`${sha256_value}\`"
    printf '%s\n' "- BLAKE2b-512: \`${blake2b_value}\`"
    printf '\nThis summary is generated from local release evidence. It is not a signature or publication approval.\n'
} >"$notes_path"
chmod 0644 -- "$notes_path"

{
    printf 'release_id=%s\n' "$release_id"
    printf 'generated_at_utc=%s\n' "$generated_at"
    printf 'iso=%s\n' "$iso_filename"
    printf 'sha256=%s\n' "$sha256_value"
    printf 'status=prepared\n'
} >"${tmp_dir}/logs/release-artifacts.log"
chmod 0644 -- "${tmp_dir}/logs/release-artifacts.log"

"${repo_root}/tests/validate-release-artifacts.sh" "$tmp_dir"

if [[ -e "$release_dir" || -L "$release_dir" ]]; then
    fail "release appeared during preparation: ${release_id}"
fi
mv -T -- "$tmp_dir" "$release_dir"
rmdir -- "$staging_parent"
staging_parent=''

"${repo_root}/tests/validate-release-artifacts.sh" "$release_dir"

printf 'Release artifacts prepared: %s\n' "${release_dir#"$repo_root"/}"
printf '  ISO: iso/%s\n' "$iso_filename"
printf '  SHA256: checksum/%s\n' "$sha256_file"
printf '  BLAKE2b-512: checksum/%s\n' "$blake2b_file"
printf '  Manifest: manifests/release-manifest.json\n'
printf '  Notes: RELEASE_NOTES.md\n'
