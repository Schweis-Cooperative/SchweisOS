#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate the canonical build dependency contract without refreshing package
# databases, installing packages, or changing host state.
set -uo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

if (( $# != 0 )); then
    printf 'Usage: %s\n' "${0##*/}" >&2
    exit 2
fi

if ! script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
    || [[ -z "$script_dir" ]]; then
    printf 'Build dependency validation: FAIL (validator location unavailable)\n' >&2
    exit 1
fi
if ! project_root="$(cd -- "${script_dir}/.." && pwd -P)" \
    || [[ -z "$project_root" || "$project_root" == / ]]; then
    printf 'Build dependency validation: FAIL (unsafe repository root)\n' >&2
    exit 1
fi
if ! git_root="$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null)" \
    || ! git_root="$(cd -- "$git_root" && pwd -P)" \
    || [[ "$git_root" != "$project_root" ]]; then
    printf 'Build dependency validation: FAIL (repository root not verified)\n' >&2
    exit 1
fi

manifest="${project_root}/build/build-dependencies.txt"
pass_count=0
fail_count=0
results=()

record_pass() {
    (( pass_count += 1 ))
    results+=("PASS|$*")
}

record_fail() {
    (( fail_count += 1 ))
    results+=("FAIL|$*")
}

join_by_space() {
    local IFS=' '
    printf '%s' "$*"
}

canonical_packages=(
    archiso
    bash
    git
    pacman
    sudo
    util-linux
)

declare -A expected_command_owner=(
    [awk]=gawk
    [bash]=bash
    [bsdtar]=libarchive
    [chmod]=coreutils
    [date]=coreutils
    [df]=coreutils
    [dirname]=coreutils
    [env]=coreutils
    [find]=findutils
    [findmnt]=util-linux
    [flock]=util-linux
    [git]=git
    [grep]=grep
    [head]=coreutils
    [mkarchiso]=archiso
    [mkfs.erofs]=erofs-utils
    [mkfs.ext4]=e2fsprogs
    [mkfs.fat]=dosfstools
    [mktemp]=coreutils
    [mkdir]=coreutils
    [mcopy]=mtools
    [mmd]=mtools
    [mksquashfs]=squashfs-tools
    [mv]=coreutils
    [pacman]=pacman
    [pacman-conf]=pacman
    [pacstrap]=arch-install-scripts
    [readlink]=coreutils
    [realpath]=coreutils
    [rmdir]=coreutils
    [sed]=sed
    [sha256sum]=coreutils
    [sort]=coreutils
    [stat]=coreutils
    [sudo]=sudo
    [tee]=coreutils
    [uname]=coreutils
    [uniq]=coreutils
    [unlink]=coreutils
    [wc]=coreutils
    [xorriso]=libisoburn
)

manifest_packages=()
manifest_format_failures=()
if [[ ! -f "$manifest" || -L "$manifest" || ! -r "$manifest" ]]; then
    record_fail 'manifest: missing, unreadable, or not a regular file'
else
    line_number=0
    while IFS= read -r line || [[ -n "$line" ]]; do
        (( line_number += 1 ))
        if [[ ! "$line" =~ ^[a-z0-9][a-z0-9@._+-]*$ ]]; then
            manifest_format_failures+=("line-${line_number}")
        else
            manifest_packages+=("$line")
        fi
    done <"$manifest"

    if (( ${#manifest_format_failures[@]} == 0 && ${#manifest_packages[@]} > 0 )); then
        record_pass 'manifest: package names only'
    elif (( ${#manifest_packages[@]} == 0 )); then
        record_fail 'manifest: contains no package names'
    else
        record_fail "manifest: invalid content at $(join_by_space "${manifest_format_failures[@]}")"
    fi
fi

ordering_failures=()
if (( ${#manifest_packages[@]} > 0 )); then
    mapfile -t sorted_packages < <(printf '%s\n' "${manifest_packages[@]}" | sort)
    if [[ "$(printf '%s\n' "${manifest_packages[@]}")" != "$(printf '%s\n' "${sorted_packages[@]}")" ]]; then
        ordering_failures+=('not-sorted')
    fi
    duplicate_packages="$(printf '%s\n' "${manifest_packages[@]}" | sort | uniq -d)"
    [[ -z "$duplicate_packages" ]] || ordering_failures+=('duplicates')
else
    ordering_failures+=('unavailable')
fi

if (( ${#ordering_failures[@]} == 0 )); then
    record_pass 'manifest ordering: sorted and unique'
else
    record_fail "manifest ordering: $(join_by_space "${ordering_failures[@]}")"
fi

policy_failures=()
for package in "${canonical_packages[@]}"; do
    found=0
    for manifest_package in "${manifest_packages[@]}"; do
        [[ "$manifest_package" == "$package" ]] && found=1
    done
    (( found )) || policy_failures+=("missing:${package}")
done
for manifest_package in "${manifest_packages[@]}"; do
    supported=0
    for package in "${canonical_packages[@]}"; do
        [[ "$manifest_package" == "$package" ]] && supported=1
    done
    (( supported )) || policy_failures+=("unsupported:${manifest_package}")
done

if (( ${#policy_failures[@]} == 0 )); then
    record_pass 'manifest policy: canonical direct dependency set'
else
    record_fail "manifest policy: $(join_by_space "${policy_failures[@]}")"
fi

sync_failures=()
if ! type -P pacman >/dev/null 2>&1; then
    sync_failures+=('pacman-unavailable')
else
    for package in "${manifest_packages[@]}"; do
        package_info="$(pacman -Si -- "$package" 2>/dev/null || true)"
        repository="$(sed -n 's/^Repository[[:space:]]*:[[:space:]]*//p' <<<"$package_info" | head -n 1)"
        case "$repository" in
            core|extra) ;;
            '') sync_failures+=("not-in-sync-db:${package}") ;;
            *) sync_failures+=("unsupported-repository:${package}:${repository}") ;;
        esac
    done
fi

if (( ${#sync_failures[@]} == 0 )); then
    record_pass 'package support: exact packages available from official Arch repositories'
else
    record_fail "package support: $(join_by_space "${sync_failures[@]}")"
fi

missing_packages=()
if ! type -P pacman >/dev/null 2>&1; then
    missing_packages=('pacman-unavailable')
else
    for package in "${manifest_packages[@]}"; do
        pacman -Qq -- "$package" >/dev/null 2>&1 || missing_packages+=("$package")
    done
fi

if (( ${#missing_packages[@]} == 0 )); then
    record_pass 'package presence: canonical direct dependencies installed exactly'
else
    record_fail "package presence: missing $(join_by_space "${missing_packages[@]}")"
fi

missing_commands=()
ownership_failures=()
mapfile -t required_commands < <(printf '%s\n' "${!expected_command_owner[@]}" | sort)
for command_name in "${required_commands[@]}"; do
    command_path="$(type -P "$command_name" 2>/dev/null || true)"
    if [[ -z "$command_path" ]]; then
        missing_commands+=("$command_name")
        continue
    fi
    if type -P pacman >/dev/null 2>&1; then
        package_owner="$(pacman -Qqo -- "$command_path" 2>/dev/null || true)"
        [[ "$package_owner" == "${expected_command_owner[$command_name]}" ]] || \
            ownership_failures+=("${command_name}:${package_owner:-unowned}")
    else
        ownership_failures+=("${command_name}:owner-unavailable")
    fi
done

if (( ${#missing_commands[@]} == 0 )); then
    record_pass 'command availability: complete Archiso build toolchain'
else
    record_fail "command availability: missing $(join_by_space "${missing_commands[@]}")"
fi

if (( ${#ownership_failures[@]} == 0 )); then
    record_pass 'unexpected replacements: available commands have canonical package owners'
else
    record_fail "unexpected replacements: $(join_by_space "${ownership_failures[@]}")"
fi

if (( fail_count == 0 )); then
    printf 'Build dependency validation: PASS (%d checks)\n' "$pass_count"
else
    printf 'Build dependency validation: FAIL (%d passed, %d failed)\n' "$pass_count" "$fail_count"
fi

for result in "${results[@]}"; do
    status="${result%%|*}"
    message="${result#*|}"
    printf '  [%s] %s\n' "$status" "$message"
done

(( fail_count == 0 ))
