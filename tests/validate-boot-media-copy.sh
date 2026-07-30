#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Bind a copied SchweisOS ISO on removable/multiboot media to the exact
# completed ISO that was validated before copying. This validator is
# intentionally read-only: it does not copy, rename, delete, mount, unmount,
# or repair media.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'Boot media copy validation: FAIL (%s)\n' "$*" >&2
    exit 1
}

media_mount_target() {
    findmnt -rn -T "$1" -o TARGET
}

media_mount_source() {
    findmnt -rn -T "$1" -o SOURCE
}

media_mount_options() {
    findmnt -rn -T "$1" -o OPTIONS
}

root_mount_source() {
    findmnt -rn -T / -o SOURCE
}

mount_source_is_block_device() {
    [[ -b "$1" ]]
}

validate_source_iso() {
    local validator_dir

    validator_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
        || return 1
    "${validator_dir}/validate-built-iso-identity.sh" "$1" >/dev/null \
        || return 1
    "${validator_dir}/validate-built-iso-boot.sh" "$1" >/dev/null \
        || return 1
}

validate_build_manifest() {
    local validator_dir

    validator_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
        || return 1
    "${validator_dir}/validate-iso-build-manifest.sh" "$1" "$2" >/dev/null \
        || return 1
}

validate_current_source_state() {
    local build_manifest=$1
    local current_commit
    local git_status
    local manifest_commit
    local project_root
    local validator_dir

    validator_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
        || return 1
    project_root="$(git -C "$validator_dir" rev-parse --show-toplevel)" \
        || return 1
    git_status="$(git -c status.showUntrackedFiles=all -C "$project_root" \
        status --porcelain --untracked-files=all)" || return 1
    [[ -z "$git_status" ]] || return 1
    current_commit="$(git -C "$project_root" rev-parse --verify HEAD)" \
        || return 1
    manifest_commit="$(jq -r '.git.commit' "$build_manifest")" \
        || return 1
    [[ "$manifest_commit" == "$current_commit" ]]
}

main() {
    local build_manifest
    local destination_block_source
    local destination_iso
    local destination_mount
    local destination_mount_options
    local destination_mount_source
    local destination_name
    local destination_sha256
    local destination_size
    local source_iso
    local source_name
    local source_sha256
    local source_size
    local root_source
    local scan_status
    local status_index
    local status_record
    local tool
    local -a schweisos_isos=()

    (( $# == 3 )) || \
        fail 'usage: validate-boot-media-copy.sh BUILD_MANIFEST SOURCE_ISO COPIED_ISO'

    for tool in basename cmp find findmnt git jq readlink sha256sum stat; do
        type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
    done

    build_manifest=$1
    source_iso=$2
    destination_iso=$3
    [[ -f "$build_manifest" && ! -L "$build_manifest" \
        && -s "$build_manifest" ]] || \
        fail 'build manifest is missing, empty, or unsafe'
    [[ -f "$source_iso" && ! -L "$source_iso" && -s "$source_iso" ]] || \
        fail 'source ISO is missing, empty, or unsafe'
    [[ -f "$destination_iso" && ! -L "$destination_iso" && -s "$destination_iso" ]] || \
        fail 'copied ISO is missing, empty, or unsafe'

    source_iso="$(readlink -f -- "$source_iso")"
    destination_iso="$(readlink -f -- "$destination_iso")"
    [[ "$source_iso" != "$destination_iso" ]] || \
        fail 'source and copied ISO resolve to the same file'
    [[ ! "$source_iso" -ef "$destination_iso" ]] || \
        fail 'source and copied ISO are the same filesystem object'

    source_name="$(basename -- "$source_iso")"
    destination_name="$(basename -- "$destination_iso")"
    [[ "$source_name" =~ ^schweisos-[0-9]{4}\.[0-9]{2}\.[0-9]{2}-x86_64\.iso$ ]] || \
        fail "source ISO name is outside the release contract: ${source_name}"
    [[ "$destination_name" == "$source_name" ]] || \
        fail 'copied ISO basename does not match the validated source'
    validate_build_manifest "$build_manifest" "$source_iso" || \
        fail 'source ISO is not bound to a successful clean build manifest'
    validate_current_source_state "$build_manifest" || \
        fail 'build manifest is not bound to the current clean repository commit'
    validate_source_iso "$source_iso" || \
        fail 'source ISO does not pass the current identity and boot composition contracts'

    destination_mount="$(media_mount_target "$destination_iso")" || \
        fail 'copied ISO is not on a discoverable mounted filesystem'
    [[ -n "$destination_mount" ]] || \
        fail 'copied ISO mount target is empty'
    destination_mount="$(readlink -f -- "$destination_mount")"
    [[ -d "$destination_mount" && "$destination_mount" != / ]] || \
        fail 'copied ISO must be on a separately mounted media filesystem'
    [[ "$destination_iso" == "$destination_mount/"* ]] || \
        fail 'copied ISO is outside its resolved media mount'
    destination_mount_options="$(media_mount_options "$destination_iso")" || \
        fail 'copied ISO mount options are unavailable'
    [[ ",${destination_mount_options}," == *,ro,* ]] || \
        fail 'copied ISO media must be safely reinserted and mounted read-only'
    destination_mount_source="$(media_mount_source "$destination_iso")" || \
        fail 'copied ISO mount source is unavailable'
    root_source="$(root_mount_source)" || \
        fail 'host root mount source is unavailable'
    destination_block_source="${destination_mount_source%%\[*}"
    root_source="${root_source%%\[*}"
    [[ "$destination_block_source" == /dev/* ]] || \
        fail 'copied ISO destination is not backed by a block device'
    mount_source_is_block_device "$destination_block_source" || \
        fail 'copied ISO destination block device is unavailable'
    [[ "$destination_block_source" != "$root_source" ]] || \
        fail 'copied ISO destination uses the host root filesystem device'

    mapfile -d '' -t schweisos_isos < <(
        find "$destination_mount" -xdev -type f \
            -iname 'schweisos-*.iso' -print0
        printf 'SCHWEISOS_FIND_STATUS:%d\0' "$?"
    )
    (( ${#schweisos_isos[@]} >= 1 )) || \
        fail 'destination media enumeration returned no status'
    status_index=$(( ${#schweisos_isos[@]} - 1 ))
    status_record="${schweisos_isos[$status_index]}"
    unset "schweisos_isos[$status_index]"
    [[ "$status_record" =~ ^SCHWEISOS_FIND_STATUS:([0-9]+)$ ]] || \
        fail 'destination media enumeration status is invalid'
    scan_status="${BASH_REMATCH[1]}"
    if (( scan_status != 0 )); then
        fail 'unable to enumerate SchweisOS ISOs on the destination media'
    fi
    (( ${#schweisos_isos[@]} == 1 )) || \
        fail "destination media must contain exactly one SchweisOS ISO; found ${#schweisos_isos[@]}"
    [[ "$(readlink -f -- "${schweisos_isos[0]}")" == "$destination_iso" ]] || \
        fail 'the sole SchweisOS ISO on the media is not the requested copy'

    source_size="$(stat -c %s -- "$source_iso")"
    destination_size="$(stat -c %s -- "$destination_iso")"
    [[ "$source_size" == "$destination_size" ]] || \
        fail 'copied ISO size does not match the validated source'

    source_sha256="$(sha256sum -- "$source_iso")"
    source_sha256="${source_sha256%% *}"
    destination_sha256="$(sha256sum -- "$destination_iso")"
    destination_sha256="${destination_sha256%% *}"
    [[ "$source_sha256" == "$destination_sha256" ]] || \
        fail 'copied ISO SHA256 does not match the validated source'
    cmp -s -- "$source_iso" "$destination_iso" || \
        fail 'copied ISO is not byte-identical to the validated source'

    printf 'Boot media copy validation: PASS\n'
    printf '  build manifest: %s\n' "$(readlink -f -- "$build_manifest")"
    printf '  source: %s\n' "$source_iso"
    printf '  media copy: %s\n' "$destination_iso"
    printf '  media mount: %s\n' "$destination_mount"
    printf '  media mount mode: read-only\n'
    printf '  media device: %s\n' "$destination_block_source"
    printf '  SchweisOS ISO count: 1\n'
    printf '  size: %s bytes\n' "$source_size"
    printf '  SHA256: %s\n' "$source_sha256"
    printf '  byte comparison: identical\n'
}

if [[ ${BASH_SOURCE[0]} == "$0" ]]; then
    main "$@"
fi
