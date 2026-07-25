#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

usage() {
    cat <<'EOF'
Usage: scripts/build-iso.sh [--clean]

Validate and build the KDE ISO profile with upstream mkarchiso.

  --clean  Remove only work/iso/kde contents before starting the build.
  -h, --help
           Show this help text.
EOF
}

clean_requested=0

while (( $# > 0 )); do
    case "$1" in
        --clean)
            clean_requested=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            printf 'ERROR: Unknown argument: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac
    shift
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"
profile_dir="${repo_root}/iso/profiles/kde"
work_dir="${repo_root}/work/iso/kde"
out_dir="${repo_root}/out/iso"
cache_dir="${repo_root}/cache/pacman"
log_dir="${repo_root}/logs/iso"

generated_dirs=("$work_dir" "$out_dir" "$cache_dir" "$log_dir")
bootstrap_commands=(date flock mkdir mktemp realpath tee)
for bootstrap_command in "${bootstrap_commands[@]}"; do
    if ! type -P "$bootstrap_command" >/dev/null 2>&1; then
        printf 'ERROR: Required wrapper bootstrap command is unavailable: %s\n' "$bootstrap_command" >&2
        exit 1
    fi
done
for generated_dir in "${generated_dirs[@]}"; do
    if [[ "$(realpath -m -- "$generated_dir")" != "$generated_dir" \
        || "$generated_dir" != "${repo_root}/"* ]]; then
        printf 'ERROR: Refusing noncanonical generated path.\n' >&2
        exit 1
    fi
done

if ! exec {build_lock_fd}<"$repo_root" || ! flock -n "$build_lock_fd"; then
    printf 'ERROR: Another ISO build owns this repository work state.\n' >&2
    exit 1
fi

if ! mkdir -p -- "${generated_dirs[@]}"; then
    printf 'ERROR: Unable to prepare canonical generated directories.\n' >&2
    exit 1
fi

start_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
start_compact="$(date -u +%Y%m%dT%H%M%SZ)"
if ! log_file="$(mktemp --tmpdir="$log_dir" "build-${start_compact}-XXXXXX.log")"; then
    printf 'ERROR: Unable to create the private build log.\n' >&2
    exit 1
fi
log_name="${log_file##*/}"
build_id="${log_name#build-}"
build_id="${build_id%.log}"
manifest_path="${log_dir}/build-manifest.json"
run_manifest_path="${log_dir}/build-${build_id}.json"

exec 3>&2
exec > >(tee -a "$log_file") 2>&1
logger_pid=$!

info() {
    printf '[build-iso] INFO: %s\n' "$*"
}

warn() {
    printf '[build-iso] WARNING: %s\n' "$*" >&2
}

error() {
    printf '[build-iso] ERROR: %s\n' "$*" >&2
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

json_number_or_null() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        printf '%s' "$1"
    else
        printf 'null'
    fi
}

build_status=running
current_stage=initialization
finished_timestamp=''
final_exit_code=''
failure_code=''
environment_validation=not_run
profile_validation=not_run
artifact_validation=not_run
mkarchiso_exit_code=''
source_date_epoch=''
epoch_origin=''
expected_iso_name=''
artifact_name=''
artifact_size=''
artifact_sha256=''
artifact_blake2b_512=''
sha256_file_name=''
artifact_candidate_count=''
temporary_files=()

git_commit=''
git_dirty_json=null
git_dirty_after_json=null
if git_commit="$(git -C "$repo_root" rev-parse --verify HEAD 2>/dev/null)"; then
    [[ "$git_commit" =~ ^[0-9a-f]{40,64}$ ]] || git_commit=''
    if git_status="$(git -C "$repo_root" status --porcelain 2>/dev/null)"; then
        if [[ -n "$git_status" ]]; then
            git_dirty_json=true
        else
            git_dirty_json=false
        fi
    fi
else
    git_commit=''
fi

os_release=/etc/os-release
[[ -r "$os_release" ]] || os_release=/usr/lib/os-release
host_id=unknown
if [[ -r "$os_release" ]]; then
    unset ID
    # shellcheck disable=SC1090
    source "$os_release"
    host_id=${ID:-unknown}
fi
host_arch="$(uname -m 2>/dev/null || printf 'unknown')"
[[ "$host_id" =~ ^[a-z0-9._-]+$ ]] || host_id=unknown
[[ "$host_arch" =~ ^[A-Za-z0-9._-]+$ ]] || host_arch=unknown

archiso_version=''
if type -P pacman >/dev/null 2>&1; then
    archiso_version="$(pacman -Q -- archiso 2>/dev/null | awk 'NR == 1 { print $2 }' || true)"
fi
[[ -z "$archiso_version" || "$archiso_version" =~ ^[A-Za-z0-9.+_~:-]+$ ]] || archiso_version=''

write_manifest_target() {
    local target=$1
    local manifest_tmp
    local temporary_index
    manifest_tmp="$(mktemp --tmpdir="$log_dir" .build-manifest.json.XXXXXX)" || return 1
    temporary_index=${#temporary_files[@]}
    temporary_files+=("$manifest_tmp")

    if ! {
        printf '{\n'
        printf '  "schema": "schweisos.iso-build-manifest.v1",\n'
        printf '  "build_id": %s,\n' "$(json_string "$build_id")"
        printf '  "build_timestamp_utc": %s,\n' "$(json_string "$start_timestamp")"
        printf '  "finished_at_utc": %s,\n' "$(json_string_or_null "$finished_timestamp")"
        printf '  "status": %s,\n' "$(json_string "$build_status")"
        printf '  "stage": %s,\n' "$(json_string "$current_stage")"
        printf '  "exit_code": %s,\n' "$(json_number_or_null "$final_exit_code")"
        printf '  "git": {\n'
        printf '    "commit": %s,\n' "$(json_string_or_null "$git_commit")"
        printf '    "dirty_at_start": %s,\n' "$git_dirty_json"
        printf '    "dirty_at_finish": %s\n' "$git_dirty_after_json"
        printf '  },\n'
        printf '  "host": {\n'
        printf '    "id": %s,\n' "$(json_string "$host_id")"
        printf '    "architecture": %s\n' "$(json_string "$host_arch")"
        printf '  },\n'
        printf '  "archiso_version": %s,\n' "$(json_string_or_null "$archiso_version")"
        printf '  "source_date_epoch": %s,\n' "$(json_number_or_null "$source_date_epoch")"
        printf '  "epoch_origin": %s,\n' "$(json_string_or_null "$epoch_origin")"
        printf '  "expected_iso_name": %s,\n' "$(json_string_or_null "$expected_iso_name")"
        printf '  "validation": {\n'
        printf '    "build_environment": %s,\n' "$(json_string "$environment_validation")"
        printf '    "iso_profile": %s,\n' "$(json_string "$profile_validation")"
        printf '    "artifact": %s\n' "$(json_string "$artifact_validation")"
        printf '  },\n'
        printf '  "mkarchiso_exit_code": %s,\n' "$(json_number_or_null "$mkarchiso_exit_code")"
        printf '  "artifact_candidate_count": %s,\n' "$(json_number_or_null "$artifact_candidate_count")"
        printf '  "artifact": {\n'
        printf '    "name": %s,\n' "$(json_string_or_null "$artifact_name")"
        printf '    "size_bytes": %s,\n' "$(json_number_or_null "$artifact_size")"
        printf '    "sha256": %s,\n' "$(json_string_or_null "$artifact_sha256")"
        printf '    "blake2b_512": %s,\n' "$(json_string_or_null "$artifact_blake2b_512")"
        printf '    "sha256_file": %s\n' "$(json_string_or_null "$sha256_file_name")"
        printf '  },\n'
        printf '  "build_log": %s,\n' "$(json_string "$log_name")"
        printf '  "failure_code": %s\n' "$(json_string_or_null "$failure_code")"
        printf '}\n'
    } >"$manifest_tmp"; then
        unlink -- "$manifest_tmp" 2>/dev/null || true
        temporary_files[$temporary_index]=''
        return 1
    fi

    if ! chmod 0644 -- "$manifest_tmp" || ! mv -fT -- "$manifest_tmp" "$target"; then
        unlink -- "$manifest_tmp" 2>/dev/null || true
        temporary_files[$temporary_index]=''
        return 1
    fi
    temporary_files[$temporary_index]=''
}

write_manifest() {
    write_manifest_target "$run_manifest_path" || return 1
    write_manifest_target "$manifest_path"
}

checkpoint_manifest() {
    if ! write_manifest; then
        failure_code=manifest_write_failed
        error 'Unable to atomically update the build manifest.'
        exit 1
    fi
}

cleanup_temporaries() {
    local temporary
    for temporary in "${temporary_files[@]}"; do
        [[ -n "$temporary" && -f "$temporary" && ! -L "$temporary" ]] || continue
        case "$temporary" in
            "${log_dir}/"*|"${work_dir}/"*|"${out_dir}/"*)
                unlink -- "$temporary" 2>/dev/null || true
                ;;
        esac
    done
}

finish() {
    local exit_status=$?
    local logger_status=0

    trap - EXIT INT TERM HUP
    cleanup_temporaries

    if git_status_after="$(git -C "$repo_root" status --porcelain 2>/dev/null)"; then
        if [[ -n "$git_status_after" ]]; then
            git_dirty_after_json=true
        else
            git_dirty_after_json=false
        fi
    fi

    if (( exit_status == 0 )) && [[ "$build_status" != success ]]; then
        exit_status=1
        failure_code=unexpected_exit
    fi
    if (( exit_status == 0 )) \
        && { [[ "$git_dirty_after_json" == null ]] \
            || [[ "$git_dirty_json" != "$git_dirty_after_json" ]]; }; then
        exit_status=1
        build_status=failed
        failure_code=source_state_changed
    fi
    if (( exit_status != 0 )); then
        build_status=failed
        [[ -n "$failure_code" ]] || failure_code=unexpected_exit
    fi

    finished_timestamp="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    info "Finished at ${finished_timestamp} with exit status ${exit_status}."
    info "Build log: logs/iso/${log_name}"
    info "Per-run manifest: logs/iso/build-${build_id}.json"
    info 'Latest-attempt manifest: logs/iso/build-manifest.json'

    exec 1>&- 2>&-
    wait "$logger_pid" || logger_status=$?
    if (( logger_status != 0 )); then
        exit_status=1
        build_status=failed
        failure_code=build_log_failed
        printf '[build-iso] ERROR: Build log registration failed.\n' >&3
    fi

    final_exit_code=$exit_status
    if ! write_manifest; then
        exit_status=1
        build_status=failed
        failure_code=manifest_write_failed
        final_exit_code=1
        write_manifest || true
        printf '[build-iso] ERROR: Unable to write the final build manifest.\n' >&3
    fi

    exit "$exit_status"
}

trap finish EXIT
trap 'failure_code=interrupted; exit 130' INT TERM HUP

checkpoint_manifest

info "Started at ${start_timestamp}."
info 'Profile: iso/profiles/kde'
info 'Work directory: work/iso/kde'
info 'Output directory: out/iso'
info 'Package cache: cache/pacman'
if [[ "$git_dirty_json" == true ]]; then
    warn 'The git working tree is dirty; this build cannot be an official release artifact.'
elif [[ "$git_dirty_json" == false ]]; then
    info 'Git working tree: clean'
else
    warn 'Git working tree state could not be determined.'
fi

environment_validator="${repo_root}/tests/validate-build-environment.sh"
profile_validator="${repo_root}/tests/validate-iso-profile.sh"

current_stage=build_environment_validation
checkpoint_manifest
if ! "$environment_validator"; then
    environment_validation=fail
    failure_code=build_environment_validation_failed
    error 'Build environment validation failed; profile validation and mkarchiso were not invoked.'
    exit 1
fi
environment_validation=pass
checkpoint_manifest

current_stage=iso_profile_validation
checkpoint_manifest
if ! "$profile_validator"; then
    profile_validation=fail
    failure_code=iso_profile_validation_failed
    error 'ISO profile validation failed; mkarchiso was not invoked.'
    exit 1
fi
profile_validation=pass
checkpoint_manifest

current_stage=input_preparation
requested_epoch=${SOURCE_DATE_EPOCH-}
build_date_file="${work_dir}/build_date"

if ! existing_work_entry="$(find "$work_dir" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)"; then
    failure_code=work_state_inspection_failed
    error 'Unable to inspect existing Archiso work state.'
    exit 1
fi
if [[ -n "$existing_work_entry" ]] && (( ! clean_requested )); then
    failure_code=existing_work_requires_clean
    error 'Existing Archiso work state is not reusable; rerun with --clean after reviewing it.'
    exit 1
fi

if [[ -n "$requested_epoch" ]]; then
    effective_epoch=$requested_epoch
    epoch_origin=environment
else
    effective_epoch="$(date +%s)"
    epoch_origin=development_default
fi

if [[ ! "$effective_epoch" =~ ^[0-9]+$ ]] \
    || ! epoch_utc="$(date --utc --date="@${effective_epoch}" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)"; then
    failure_code=invalid_epoch
    error 'SOURCE_DATE_EPOCH must be a non-negative decimal timestamp.'
    exit 1
fi

source_date_epoch=$effective_epoch
SOURCE_DATE_EPOCH=$effective_epoch
export SOURCE_DATE_EPOCH
info "SOURCE_DATE_EPOCH: ${SOURCE_DATE_EPOCH} (${epoch_utc}; ${epoch_origin})"

if ! profile_metadata="$(bash -c '
    set -eu
    source "$1"
    printf "%s\n%s\n%s\n" "$iso_name" "$iso_version" "$arch"
' _ "${profile_dir}/profiledef.sh")"; then
    failure_code=profile_metadata_failed
    error 'Unable to derive expected artifact metadata from the validated profile.'
    exit 1
fi
mapfile -t profile_metadata_lines <<<"$profile_metadata"
if (( ${#profile_metadata_lines[@]} != 3 )); then
    failure_code=profile_metadata_failed
    error 'Validated profile returned incomplete artifact metadata.'
    exit 1
fi

expected_iso_name="${profile_metadata_lines[0]}-${profile_metadata_lines[1]}-${profile_metadata_lines[2]}.iso"
if [[ "$expected_iso_name" == */* || "$expected_iso_name" == .* || "$expected_iso_name" != *.iso ]]; then
    failure_code=artifact_name_invalid
    error 'Validated profile produced an unsafe artifact name.'
    exit 1
fi
expected_iso="${out_dir}/${expected_iso_name}"
checkpoint_manifest

shopt -s nullglob
preexisting_isos=("$out_dir"/*.iso)
preexisting_checksums=("$out_dir"/*.iso.sha256)
shopt -u nullglob
if (( ${#preexisting_isos[@]} > 0 || ${#preexisting_checksums[@]} > 0 )); then
    artifact_candidate_count=${#preexisting_isos[@]}
    failure_code=preexisting_artifact_output
    error 'Output contains an existing ISO or checksum; archive or remove it explicitly before building.'
    exit 1
fi

sha256_path="${expected_iso}.sha256"

root_command=()
if (( EUID != 0 )); then
    if sudo -n true >/dev/null 2>&1; then
        root_command=(sudo -n)
    elif [[ -t 0 ]]; then
        root_command=(sudo)
    else
        failure_code=privilege_unavailable
        error 'mkarchiso requires root; use an interactive terminal so sudo can authenticate.'
        exit 1
    fi
fi

if (( clean_requested )); then
    expected_work_dir="${repo_root}/work/iso/kde"
    resolved_work_dir="$(realpath -m -- "$work_dir")"
    if [[ "$work_dir" != "$expected_work_dir" || "$resolved_work_dir" != "$expected_work_dir" \
        || "$work_dir" == "$repo_root" || "$work_dir" == / ]]; then
        failure_code=unsafe_cleanup_target
        error 'Refusing to clean an unexpected work directory.'
        exit 1
    fi

    if ! mount_targets="$(findmnt -rn -o TARGET 2>/dev/null)"; then
        failure_code=mount_inspection_failed
        error 'Unable to inspect mountpoints before cleaning Archiso work state.'
        exit 1
    fi
    mounted_work_state=0
    while IFS= read -r mount_target; do
        if [[ "$mount_target" == "$work_dir" || "$mount_target" == "${work_dir}/"* ]]; then
            mounted_work_state=1
            break
        fi
    done <<<"$mount_targets"
    if (( mounted_work_state )); then
        failure_code=mounted_work_state
        error 'Refusing to clean Archiso work state while it contains a mountpoint; unmount it explicitly first.'
        exit 1
    fi

    info 'Cleaning generated work state: work/iso/kde'
    if ! "${root_command[@]}" find "$work_dir" -xdev -mindepth 1 -delete; then
        failure_code=cleanup_failed
        error 'Unable to clean generated Archiso work state.'
        exit 1
    fi
fi

build_pacman_conf="${work_dir}/pacman.conf"
if [[ -e "$build_pacman_conf" || -L "$build_pacman_conf" ]] \
    && [[ ! -f "$build_pacman_conf" || -L "$build_pacman_conf" ]]; then
    failure_code=unsafe_build_config
    error 'Build-local pacman configuration has an unsafe file type.'
    exit 1
fi

if ! pacman_conf_tmp="$(mktemp --tmpdir="$work_dir" .pacman.conf.XXXXXX)"; then
    failure_code=build_config_generation_failed
    error 'Unable to allocate the build-local pacman configuration.'
    exit 1
fi
temporary_files+=("$pacman_conf_tmp")
if ! awk -v cache_dir="$cache_dir" '
    /^[[:space:]]*CacheDir[[:space:]]*=/ { next }
    /^\[options\][[:space:]]*$/ {
        print
        print "CacheDir = " cache_dir
        cache_inserted = 1
        next
    }
    { print }
    END { if (!cache_inserted) exit 1 }
' "${profile_dir}/pacman.conf" >"$pacman_conf_tmp"; then
    failure_code=build_config_generation_failed
    error 'Unable to generate the build-local pacman configuration.'
    exit 1
fi
if ! chmod 0644 -- "$pacman_conf_tmp" || ! mv -fT -- "$pacman_conf_tmp" "$build_pacman_conf"; then
    failure_code=build_config_publication_failed
    error 'Unable to atomically publish the build-local pacman configuration.'
    exit 1
fi
temporary_files[((${#temporary_files[@]} - 1))]=''

if ! pacman-conf --config "$build_pacman_conf" >/dev/null 2>&1; then
    failure_code=build_config_validation_failed
    error 'Generated build-local pacman configuration does not parse.'
    exit 1
fi

current_stage=mkarchiso
checkpoint_manifest
info 'Invoking upstream mkarchiso.'
info 'mkarchiso command: mkarchiso -v -C work/iso/kde/pacman.conf -w work/iso/kde -o out/iso iso/profiles/kde'
set +e
"${root_command[@]}" env "SOURCE_DATE_EPOCH=${SOURCE_DATE_EPOCH}" mkarchiso \
    -v \
    -C "$build_pacman_conf" \
    -w "$work_dir" \
    -o "$out_dir" \
    "$profile_dir"
mkarchiso_status=$?
set -e
mkarchiso_exit_code=$mkarchiso_status
info "mkarchiso exit status: ${mkarchiso_status}"
if (( mkarchiso_status != 0 )); then
    failure_code=mkarchiso_failed
    error 'ISO build failed; inspect the registered build log.'
    exit "$mkarchiso_status"
fi

current_stage=artifact_validation
checkpoint_manifest
if [[ ! -f "$build_date_file" || -L "$build_date_file" \
    || "$(<"$build_date_file")" != "$SOURCE_DATE_EPOCH" ]]; then
    artifact_validation=fail
    failure_code=epoch_state_mismatch
    error 'Archiso work state does not preserve the selected SOURCE_DATE_EPOCH.'
    exit 1
fi

shopt -s nullglob
iso_candidates=("$out_dir"/*.iso)
shopt -u nullglob
artifact_candidate_count=${#iso_candidates[@]}
if (( artifact_candidate_count != 1 )); then
    artifact_validation=fail
    failure_code=artifact_count_mismatch
    error "Expected exactly one ISO artifact; found ${artifact_candidate_count}."
    exit 1
fi

artifact_path=${iso_candidates[0]}
if [[ "$artifact_path" != "$expected_iso" ]]; then
    artifact_validation=fail
    failure_code=artifact_name_mismatch
    error 'Generated ISO does not have the expected profile-derived name.'
    exit 1
fi
if [[ ! -f "$artifact_path" || -L "$artifact_path" ]]; then
    artifact_validation=fail
    failure_code=artifact_type_invalid
    error 'Generated ISO is not a regular non-symlink file.'
    exit 1
fi
if [[ ! -s "$artifact_path" ]]; then
    artifact_validation=fail
    failure_code=artifact_empty
    error 'Generated ISO is empty.'
    exit 1
fi

artifact_size="$(stat -c %s -- "$artifact_path" 2>/dev/null || true)"
if [[ ! "$artifact_size" =~ ^[1-9][0-9]*$ ]]; then
    artifact_validation=fail
    failure_code=artifact_size_invalid
    error 'Generated ISO size could not be validated.'
    exit 1
fi

if ! sha256_tmp="$(mktemp --tmpdir="$out_dir" ".${expected_iso_name}.sha256.XXXXXX")"; then
    artifact_validation=fail
    failure_code=sha256_generation_failed
    error 'Unable to allocate a temporary SHA256 sidecar.'
    exit 1
fi
temporary_files+=("$sha256_tmp")
sha256_tmp_name=${sha256_tmp##*/}
if ! (cd -- "$out_dir" && sha256sum -- "$expected_iso_name" >"$sha256_tmp_name"); then
    artifact_validation=fail
    failure_code=sha256_generation_failed
    error 'Unable to generate the ISO SHA256 checksum.'
    exit 1
fi

mapfile -t sha256_lines <"$sha256_tmp"
read -r checksum_value checksum_filename <<<"${sha256_lines[0]-}"
if (( ${#sha256_lines[@]} != 1 )) \
    || [[ ! "$checksum_value" =~ ^[0-9a-f]{64}$ ]] \
    || [[ "$checksum_filename" != "$expected_iso_name" ]] \
    || ! (cd -- "$out_dir" && sha256sum --check --strict --status -- "$sha256_tmp_name"); then
    artifact_validation=fail
    failure_code=sha256_verification_failed
    error 'Generated SHA256 checksum did not verify.'
    exit 1
fi

if type -P b2sum >/dev/null 2>&1; then
    if ! blake2_line="$(cd -- "$out_dir" && b2sum -- "$expected_iso_name")"; then
        artifact_validation=fail
        failure_code=blake2_generation_failed
        error 'Installed b2sum could not generate a checksum.'
        exit 1
    fi
    read -r blake2_value blake2_filename <<<"$blake2_line"
    if [[ ! "$blake2_value" =~ ^[0-9a-f]{128}$ \
        || "$blake2_filename" != "$expected_iso_name" ]] \
        || ! (cd -- "$out_dir" && printf '%s\n' "$blake2_line" | b2sum --check --strict --status); then
        artifact_validation=fail
        failure_code=blake2_verification_failed
        error 'Generated BLAKE2b-512 checksum did not verify.'
        exit 1
    fi
    artifact_blake2b_512=$blake2_value
fi

if ! chmod 0644 -- "$sha256_tmp" || ! mv -fT -- "$sha256_tmp" "$sha256_path"; then
    artifact_validation=fail
    failure_code=sha256_publication_failed
    error 'Unable to atomically publish the verified SHA256 sidecar.'
    exit 1
fi
temporary_files[((${#temporary_files[@]} - 1))]=''
if ! (cd -- "$out_dir" && sha256sum --check --strict --status -- "${expected_iso_name}.sha256"); then
    artifact_validation=fail
    failure_code=sha256_verification_failed
    error 'Published SHA256 sidecar did not verify.'
    exit 1
fi

artifact_sha256=$checksum_value

artifact_name=$expected_iso_name
sha256_file_name="${expected_iso_name}.sha256"
artifact_validation=pass
build_status=success
current_stage=complete
failure_code=''

info "ISO artifact: out/iso/${artifact_name} (${artifact_size} bytes)"
info "SHA256: ${artifact_sha256}"
if [[ -n "$artifact_blake2b_512" ]]; then
    info "BLAKE2b-512: ${artifact_blake2b_512}"
fi

exit 0
