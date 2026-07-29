#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# This validator is intentionally network-free and non-destructive. It
# aggregates independent failures so one run gives a useful host-readiness
# report without changing package databases, host configuration, or trust.
set -uo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

if ! script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)" \
    || [[ -z "$script_dir" ]]; then
    printf 'Build environment validation: FAIL (validator location unavailable)\n' >&2
    exit 1
fi
if ! project_root="$(cd -- "${script_dir}/.." && pwd -P)" \
    || [[ -z "$project_root" || "$project_root" == / ]]; then
    printf 'Build environment validation: FAIL (unsafe repository root)\n' >&2
    exit 1
fi
if ! git_root="$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null)" \
    || ! git_root="$(cd -- "$git_root" && pwd -P)" \
    || [[ "$git_root" != "$project_root" ]]; then
    printf 'Build environment validation: FAIL (repository root not verified)\n' >&2
    exit 1
fi
profile_dir="${project_root}/iso/profiles/kde"
canonical_logo="${project_root}/branding/assets/logo/schweisos.png"
dependency_validator="${project_root}/tests/validate-build-dependencies.sh"
iso_build_mode="${SCHWEISOS_ISO_BUILD_MODE:-development}"

pass_count=0
warn_count=0
fail_count=0
results=()

record_pass() {
    (( pass_count += 1 ))
    results+=("PASS|$*")
}

record_warn() {
    (( warn_count += 1 ))
    results+=("WARN|$*")
}

record_fail() {
    (( fail_count += 1 ))
    results+=("FAIL|$*")
}

join_by_space() {
    local IFS=' '
    printf '%s' "$*"
}

case "$iso_build_mode" in
    development|release)
        record_pass "build mode: ${iso_build_mode}"
        ;;
    *)
        record_fail "build mode: invalid SCHWEISOS_ISO_BUILD_MODE ${iso_build_mode}"
        ;;
esac

if [[ "$iso_build_mode" == release ]]; then
    release_input_failures=()
    if ! release_git_status="$(git -C "$project_root" status --porcelain 2>/dev/null)"; then
        release_input_failures+=('git-state-unavailable')
    elif [[ -n "$release_git_status" ]]; then
        release_input_failures+=('git-tree-dirty')
    fi
    release_epoch=${SOURCE_DATE_EPOCH-}
    if [[ ! "$release_epoch" =~ ^[0-9]+$ ]] \
        || ! date --utc --date="@${release_epoch}" +%Y-%m-%dT%H:%M:%SZ >/dev/null 2>&1; then
        release_input_failures+=('SOURCE_DATE_EPOCH-missing-or-invalid')
    fi
    if (( ${#release_input_failures[@]} == 0 )); then
        record_pass 'release inputs: clean source and explicit valid SOURCE_DATE_EPOCH'
    else
        record_fail "release inputs: $(join_by_space "${release_input_failures[@]}")"
    fi
else
    record_pass 'release inputs: not required in development mode'
fi

os_release=/etc/os-release
[[ -r "$os_release" ]] || os_release=/usr/lib/os-release
host_id=unknown
if [[ -r "$os_release" ]]; then
    unset ID
    # os-release is the canonical machine-readable distribution identity.
    # shellcheck disable=SC1090
    source "$os_release"
    host_id=${ID:-unknown}
fi

if [[ "$host_id" == arch && -f /etc/arch-release ]]; then
    record_pass 'host: canonical Arch Linux'
else
    record_fail "host: expected canonical Arch Linux, found ${host_id}"
fi

host_arch="$(uname -m 2>/dev/null || printf 'unknown')"
if [[ "$host_arch" == x86_64 ]]; then
    record_pass 'architecture: x86_64'
else
    record_fail "architecture: expected x86_64, found ${host_arch}"
fi

if (( EUID == 0 )); then
    record_fail 'execution context: run validation unprivileged; the wrapper escalates only mkarchiso and cleanup'
else
    record_pass 'execution context: unprivileged'
fi

if [[ -f "$dependency_validator" && ! -L "$dependency_validator" \
    && -x "$dependency_validator" ]] \
    && dependency_output="$("$dependency_validator" 2>&1)"; then
    record_pass 'dependencies: canonical package and command contract satisfied'
else
    record_fail 'dependencies: validation failed; run tests/validate-build-dependencies.sh for details'
fi
unset dependency_output

if type -P pacman >/dev/null 2>&1; then
    pending_updates="$(pacman -Quq 2>/dev/null)"
    pending_status=$?
    if (( pending_status > 1 )); then
        record_fail 'upgrade state: pacman query failed'
    elif [[ -n "$pending_updates" ]]; then
        pending_count="$(wc -l <<<"$pending_updates")"
        record_fail "upgrade state: ${pending_count} update(s) known to current sync databases"
    else
        record_pass 'upgrade state: no updates known to current sync databases'
    fi
else
    record_fail 'upgrade state: pacman unavailable'
fi

if type -P pacman-conf >/dev/null 2>&1; then
    mapfile -t global_siglevel < <(pacman-conf SigLevel 2>/dev/null)
    global_siglevel_text=" $(join_by_space "${global_siglevel[@]}") "
    if [[ "$global_siglevel_text" == *' PackageRequired '* \
        && "$global_siglevel_text" == *' PackageTrustedOnly '* \
        && "$global_siglevel_text" != *' Never '* \
        && "$global_siglevel_text" != *' TrustAll '* ]]; then
        record_pass 'host trust policy: package signatures required and trusted'
    else
        record_fail 'host trust policy: pacman package verification is not Required TrustedOnly'
    fi
else
    record_fail 'host trust policy: pacman-conf unavailable'
fi

required_directories=(
    build
    docs/adr
    docs/architecture
    docs/boot
    docs/build
    docs/project
    iso
    iso/profiles/kde
    iso/profiles/kde/airootfs
    iso/profiles/kde/efiboot
    iso/profiles/kde/efiboot/loader/entries
    packages
    packages/calamares
    packages/schweisos-branding
    packages/schweisos-calamares-config
    packages/schweisos-grub-theme
    packages/schweisos-keyring
    packages/schweisos-mirrorlist
    packages/schweisos-pacman-config
    packages/schweisos-release
    release
    scripts
    tests
    tools/release
    tools/repo
    tools/signing
)
required_files=(
    VISION.md
    build/README.md
    build/build-dependencies.txt
    docs/project/CONSTITUTION.md
    docs/architecture/ADD.md
    docs/adr/ADR-011-repository-architecture.md
    docs/adr/ADR-012-iso-build-architecture.md
    docs/adr/ADR-013-iso-build-workflow.md
    docs/adr/ADR-014-live-boot-experience-architecture.md
    docs/adr/ADR-015-grub-theme-architecture.md
    docs/adr/ADR-016-installer-architecture.md
    docs/boot/README.md
    docs/build/environment-readiness.md
    docs/installer/README.md
    docs/installer/manual-installation-runbook.md
    docs/installer/recovery-runbook.md
    docs/release/release-artifact-pipeline.md
    iso/profiles/kde/profiledef.sh
    iso/profiles/kde/packages.x86_64
    iso/profiles/kde/pacman.conf
    release/README.md
    scripts/build-iso.sh
    scripts/create-release-artifacts.sh
    tests/test-plymouth-watchdog.sh
    tests/validate-grub-theme.sh
    tests/validate-build-dependencies.sh
    tests/validate-distribution-identity.sh
    tests/validate-build-environment.sh
    tests/validate-built-iso-boot.sh
    tests/validate-built-iso-identity.sh
    tests/validate-iso-build-manifest.sh
    tests/validate-keyring-package.sh
    tests/validate-installer-config.sh
    tests/validate-iso-profile.sh
    tests/validate-release-artifacts.sh
    tests/validate-signing-tooling.sh
)
layout_failures=()

for relative_path in "${required_directories[@]}"; do
    [[ -d "${project_root}/${relative_path}" && ! -L "${project_root}/${relative_path}" ]] || \
        layout_failures+=("${relative_path}/")
done
for relative_path in "${required_files[@]}"; do
    [[ -f "${project_root}/${relative_path}" && ! -L "${project_root}/${relative_path}" ]] || \
        layout_failures+=("${relative_path}")
done
if ! git -C "$project_root" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    layout_failures+=('git-worktree')
fi

if (( ${#layout_failures[@]} == 0 )); then
    record_pass 'layout: repository contract complete'
else
    record_fail "layout: missing or invalid $(join_by_space "${layout_failures[@]}")"
fi

generated_paths=(
    work/iso/kde
    out/iso
    cache/pacman
    logs/iso
)
generated_path_failures=()
minimum_free_kib=$((20 * 1024 * 1024))
lowest_free_kib=''

for relative_path in "${generated_paths[@]}"; do
    path="${project_root}/${relative_path}"
    resolved_path="$(realpath -m -- "$path" 2>/dev/null || true)"
    if [[ "$resolved_path" != "$path" || "$path" != "${project_root}/"* ]]; then
        generated_path_failures+=("${relative_path}:noncanonical")
        continue
    fi

    unsafe_component=0
    component=$project_root
    component_mode="$(stat -c %a -- "$component" 2>/dev/null || true)"
    if [[ ! "$component_mode" =~ ^[0-7]{3,4}$ ]]; then
        generated_path_failures+=("${relative_path}:ancestor-mode-unknown")
        unsafe_component=1
    elif (( (8#$component_mode & 2) != 0 )); then
        generated_path_failures+=("${relative_path}:world-writable-ancestor")
        unsafe_component=1
    fi
    IFS=/ read -r -a path_parts <<<"$relative_path"
    for part in "${path_parts[@]}"; do
        component="${component}/${part}"
        if [[ -L "$component" ]]; then
            generated_path_failures+=("${relative_path}:symlink-component")
            unsafe_component=1
            break
        elif [[ -e "$component" && ! -d "$component" ]]; then
            generated_path_failures+=("${relative_path}:nondirectory-component")
            unsafe_component=1
            break
        elif [[ -d "$component" ]]; then
            component_mode="$(stat -c %a -- "$component" 2>/dev/null || true)"
            if [[ ! "$component_mode" =~ ^[0-7]{3,4}$ ]]; then
                generated_path_failures+=("${relative_path}:ancestor-mode-unknown")
                unsafe_component=1
                break
            elif (( (8#$component_mode & 2) != 0 )); then
                generated_path_failures+=("${relative_path}:world-writable-ancestor")
                unsafe_component=1
                break
            fi
        fi
    done
    (( unsafe_component == 0 )) || continue

    probe_parent=$path
    while [[ ! -e "$probe_parent" && "$probe_parent" != "$project_root" ]]; do
        probe_parent="${probe_parent%/*}"
    done
    if [[ -e "$path" && ! -d "$path" ]]; then
        generated_path_failures+=("${relative_path}:not-directory")
        continue
    fi
    if [[ ! -d "$probe_parent" || ! -w "$probe_parent" || ! -x "$probe_parent" ]]; then
        generated_path_failures+=("${relative_path}:not-writable")
        continue
    fi
    write_probe="$(mktemp --directory --tmpdir="$probe_parent" .schweisos-write-test.XXXXXX 2>/dev/null || true)"
    if [[ -z "$write_probe" ]]; then
        generated_path_failures+=("${relative_path}:write-probe-failed")
        continue
    fi
    rmdir -- "$write_probe" || generated_path_failures+=("${relative_path}:probe-cleanup-failed")

    if ! git -C "$project_root" check-ignore -q -- "$relative_path"; then
        generated_path_failures+=("${relative_path}:not-gitignored")
    fi
    if [[ -n "$(git -C "$project_root" ls-files -- "$relative_path")" ]]; then
        generated_path_failures+=("${relative_path}:tracked-content")
    fi

    free_kib="$(df -Pk -- "$probe_parent" 2>/dev/null | awk 'NR == 2 { print $4 }')"
    if [[ ! "$free_kib" =~ ^[0-9]+$ ]]; then
        generated_path_failures+=("${relative_path}:space-unknown")
    elif [[ -z "$lowest_free_kib" || "$free_kib" -lt "$lowest_free_kib" ]]; then
        lowest_free_kib=$free_kib
    fi
done

for wrapper_file in work/iso/kde/build_date work/iso/kde/pacman.conf; do
    wrapper_path="${project_root}/${wrapper_file}"
    if [[ -e "$wrapper_path" || -L "$wrapper_path" ]]; then
        [[ -f "$wrapper_path" && ! -L "$wrapper_path" ]] || \
            generated_path_failures+=("${wrapper_file}:unsafe-type")
    fi
done

if (( ${#generated_path_failures[@]} == 0 )); then
    record_pass 'generated paths: canonical, writable, non-world-writable, and ignored'
else
    record_fail "generated paths: $(join_by_space "${generated_path_failures[@]}")"
fi

if [[ "$lowest_free_kib" =~ ^[0-9]+$ ]] && (( lowest_free_kib >= minimum_free_kib )); then
    record_pass "disk space: at least $((lowest_free_kib / 1024 / 1024)) GiB free"
elif [[ "$lowest_free_kib" =~ ^[0-9]+$ ]]; then
    record_fail "disk space: $((lowest_free_kib / 1024 / 1024)) GiB free; 20 GiB required"
else
    record_fail 'disk space: unavailable; 20 GiB required'
fi

permission_failures=()
required_executables=(
    iso/profiles/kde/airootfs/usr/lib/schweisos-live/plymouth-is-stopped
    iso/profiles/kde/airootfs/usr/lib/schweisos-live/plymouth-quit-guarded
    iso/profiles/kde/airootfs/usr/lib/schweisos-live/plymouth-watchdog
    scripts/build-iso.sh
    scripts/create-release-artifacts.sh
    tests/install-local-bootstrap-packages.sh
    tests/test-installer-experience.sh
    tests/test-plymouth-watchdog.sh
    tests/test-release-artifacts.sh
    tests/validate-build-dependencies.sh
    tests/validate-built-iso-boot.sh
    tests/validate-built-iso-identity.sh
    tests/validate-iso-build-manifest.sh
    tests/validate-distribution-identity.sh
    tests/validate-build-environment.sh
    tests/validate-grub-theme.sh
    tests/validate-installer-config.sh
    tests/validate-keyring-package.sh
    tests/validate-iso-profile.sh
    tests/validate-release-artifacts.sh
    tests/validate-repository-bootstrap.sh
    tests/validate-signed-repository-client.sh
    tests/validate-signing-tooling.sh
    tools/release/activate-build-repository.sh
    tools/release/create-repository-candidate.sh
    tools/release/sign-repository-metadata.sh
    tools/release/validate-release-repository.sh
    tools/repo/bootstrap-local-repo.sh
    tools/repo/publish-local-packages.sh
    tools/repo/validate-local-repo.sh
    tools/signing/admit-public-bundle.sh
    tools/signing/bootstrap-pacman-trust.sh
    tools/signing/create-offline-release-key.sh
    tools/signing/export-operational-subkeys.sh
    tools/signing/import-operational-subkeys.sh
    tools/signing/sign-artifact.sh
    tools/signing/smoke-test-signing-home.sh
    tools/signing/validate-admitted-public-bundle.sh
    tools/signing/validate-public-bundle.sh
    tools/signing/validate-signing-home.sh
    tools/signing/verify-artifact-signature.sh
)

input_manifest="$(mktemp /tmp/schweisos-build-inputs.XXXXXX 2>/dev/null || true)"
input_manifest_ready=1
if [[ -z "$input_manifest" ]]; then
    input_manifest_ready=0
elif ! git -C "$project_root" ls-files -co --exclude-standard -z >"$input_manifest"; then
    input_manifest_ready=0
fi

cleanup_input_manifest() {
    if [[ -n "$input_manifest" && -f "$input_manifest" && ! -L "$input_manifest" ]]; then
        /usr/bin/unlink -- "$input_manifest" 2>/dev/null || true
    fi
}
trap cleanup_input_manifest EXIT

for relative_path in "${required_executables[@]}"; do
    candidate="${project_root}/${relative_path}"
    [[ -f "$candidate" && ! -L "$candidate" && -x "$candidate" ]] || \
        permission_failures+=("${relative_path}:not-regular-executable")
done

if (( input_manifest_ready )); then
    while IFS= read -r -d '' relative_path; do
        candidate="${project_root}/${relative_path}"
        [[ -e "$candidate" || -L "$candidate" ]] || continue
        if [[ -f "$candidate" && ! -L "$candidate" ]]; then
            [[ -r "$candidate" ]] || permission_failures+=("${relative_path}:unreadable")
            if [[ -x "$candidate" ]]; then
                executable_allowed=0
                for allowed_executable in "${required_executables[@]}"; do
                    if [[ "$relative_path" == "$allowed_executable" ]]; then
                        executable_allowed=1
                        break
                    fi
                done
                (( executable_allowed )) || permission_failures+=("${relative_path}:unexpected-executable")
            fi
        fi
    done <"$input_manifest"
else
    permission_failures+=('repository-input-enumeration-failed')
fi

for relative_path in "${required_directories[@]}"; do
    candidate="${project_root}/${relative_path}"
    [[ -d "$candidate" && -r "$candidate" && -x "$candidate" ]] || \
        permission_failures+=("${relative_path}/:inaccessible")
done

if (( ${#permission_failures[@]} == 0 )); then
    record_pass 'permissions: source readable and required scripts executable'
else
    record_fail "permissions: $(join_by_space "${permission_failures[@]}")"
fi

force_flag_hit=''
force_flag_token='--for''ce'
if (( input_manifest_ready )); then
    while IFS= read -r -d '' relative_path; do
        candidate="${project_root}/${relative_path}"
        [[ -f "$candidate" && ! -L "$candidate" ]] || continue
        if [[ -x "$candidate" || "${candidate##*/}" == PKGBUILD ]] \
            && grep -Fq -- "$force_flag_token" "$candidate"; then
            force_flag_hit="$relative_path"
            break
        fi
    done <"$input_manifest"
else
    force_flag_hit='repository-input-enumeration-failed'
fi

if [[ -z "$force_flag_hit" ]]; then
    record_pass 'force flags: absent from executable workflows and PKGBUILDs'
else
    record_fail "prohibited ${force_flag_token} flag in repository workflow: ${force_flag_hit}"
fi

world_writable=''
if (( input_manifest_ready )); then
    while IFS= read -r -d '' relative_path; do
        candidate="${project_root}/${relative_path}"
        [[ -f "$candidate" && ! -L "$candidate" ]] || continue
        candidate_mode="$(stat -c %a -- "$candidate" 2>/dev/null || true)"
        if [[ ! "$candidate_mode" =~ ^[0-7]{3,4}$ ]] \
            || (( (8#$candidate_mode & 2) != 0 )); then
            world_writable=$relative_path
            break
        fi
    done <"$input_manifest"
else
    world_writable='repository-input-enumeration-failed'
fi

if [[ -z "$world_writable" ]]; then
    for relative_path in "${required_directories[@]}"; do
        candidate="${project_root}/${relative_path}"
        candidate_mode="$(stat -c %a -- "$candidate" 2>/dev/null || true)"
        if [[ ! "$candidate_mode" =~ ^[0-7]{3,4}$ ]] \
            || (( (8#$candidate_mode & 2) != 0 )); then
            world_writable="${relative_path}/"
            break
        fi
    done
fi

if [[ -z "$world_writable" ]]; then
    record_pass 'world-writable project paths: none'
else
    record_fail "world-writable or unreadable-mode project path: ${world_writable}"
fi

symlink_failures=()
if (( input_manifest_ready )); then
    while IFS= read -r -d '' relative_link; do
        link="${project_root}/${relative_link}"
        [[ -L "$link" ]] || continue
        if ! target="$(readlink -- "$link" 2>/dev/null)" || [[ -z "$target" ]]; then
            symlink_failures+=("${relative_link}:target-unreadable")
            continue
        fi
        case "$relative_link" in
            iso/profiles/kde/airootfs/etc/systemd/system/display-manager.service)
                [[ "$target" == '/usr/lib/systemd/system/sddm.service' ]] || \
                    symlink_failures+=("${relative_link}:unexpected-target")
                ;;
            iso/profiles/kde/airootfs/etc/systemd/system/multi-user.target.wants/NetworkManager.service)
                [[ "$target" == '/usr/lib/systemd/system/NetworkManager.service' ]] || \
                    symlink_failures+=("${relative_link}:unexpected-target")
                ;;
            iso/profiles/kde/airootfs/etc/localtime)
                [[ "$target" == '/usr/share/zoneinfo/UTC' ]] || \
                    symlink_failures+=("${relative_link}:unexpected-target")
                ;;
            *)
                if [[ "$target" == /* ]]; then
                    symlink_failures+=("${relative_link}:unexpected-absolute-target")
                else
                    resolved_target="$(realpath -m -- "$(dirname -- "$link")/${target}" 2>/dev/null || true)"
                    if [[ "$resolved_target" != "${project_root}/"* \
                        || ! -e "$resolved_target" && ! -L "$resolved_target" ]]; then
                        symlink_failures+=("${relative_link}:broken-or-external")
                    fi
                fi
                ;;
        esac
    done <"$input_manifest"
else
    symlink_failures+=('repository-input-enumeration-failed')
fi

if (( ${#symlink_failures[@]} == 0 )); then
    record_pass 'symlinks: valid; live-root systemd links allowlisted'
else
    record_fail "symlinks: $(join_by_space "${symlink_failures[@]}")"
fi

secret_hit=''
private_key_hit=''
secret_scan_failure=''
private_key_scan_failure=''
private_key_markers=(
    'BEGIN PGP'' PRIVATE KEY BLOCK'
    'BEGIN OPENSSH'' PRIVATE KEY'
    'BEGIN RSA'' PRIVATE KEY'
    'BEGIN DSA'' PRIVATE KEY'
    'BEGIN EC'' PRIVATE KEY'
    'BEGIN ENCRYPTED'' PRIVATE KEY'
    'BEGIN PRIVATE'' KEY'
)

if (( input_manifest_ready )); then
    while IFS= read -r -d '' relative_file; do
        file="${project_root}/${relative_file}"
        [[ -f "$file" && ! -L "$file" ]] || continue
        if [[ -z "$secret_hit" && -z "$secret_scan_failure" ]]; then
            grep -IEq \
                'ghp_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|xox[baprs]-[A-Za-z0-9-]+' \
                "$file"
            grep_status=$?
            if (( grep_status == 0 )); then
                secret_hit=$relative_file
            elif (( grep_status > 1 )); then
                secret_scan_failure=$relative_file
            fi
        fi
        if [[ -z "$private_key_hit" && -z "$private_key_scan_failure" ]]; then
            for marker in "${private_key_markers[@]}"; do
                grep -IFq -- "$marker" "$file"
                grep_status=$?
                if (( grep_status == 0 )); then
                    private_key_hit=$relative_file
                    break
                elif (( grep_status > 1 )); then
                    private_key_scan_failure=$relative_file
                    break
                fi
            done
        fi
    done <"$input_manifest"
else
    secret_scan_failure='repository-input-enumeration-failed'
    private_key_scan_failure='repository-input-enumeration-failed'
fi

if [[ -n "$secret_scan_failure" ]]; then
    record_fail "secrets: scan failed for ${secret_scan_failure}"
elif [[ -z "$secret_hit" ]]; then
    record_pass 'secrets: no credential patterns in repository inputs'
else
    record_fail "secrets: suspicious content in ${secret_hit}"
fi

private_container_hit=''
if (( input_manifest_ready )); then
    while IFS= read -r -d '' relative_path; do
        case "/${relative_path}/" in
            */private-keys-v1.d/*)
                private_container_hit=$relative_path
                break
                ;;
        esac
        case "${relative_path##*/}" in
            *.p12|*.pfx|secring.gpg|id_dsa|id_ecdsa|id_ed25519|id_rsa)
                private_container_hit=$relative_path
                break
                ;;
        esac
    done <"$input_manifest"
else
    private_container_hit='repository-input-enumeration-failed'
fi

if [[ -n "$private_key_scan_failure" ]]; then
    record_fail "signing secrets: scan failed for ${private_key_scan_failure}"
elif [[ -z "$private_key_hit" && -z "$private_container_hit" ]]; then
    record_pass 'signing secrets: no private key material in repository inputs'
elif [[ -n "$private_key_hit" ]]; then
    record_fail "signing secrets: private key armor in ${private_key_hit}"
else
    record_fail "signing secrets: private key container ${private_container_hit}"
fi

repository_ready=1
repository_failure=''
bootstrap_host_packages=(
    schweisos-keyring
    schweisos-mirrorlist
    schweisos-pacman-config
)
missing_bootstrap_packages=()
schweisos_profile_packages=()
if [[ -f "${profile_dir}/packages.x86_64" ]]; then
    mapfile -t schweisos_profile_packages < <(
        sed 's/[[:space:]]*#.*$//' "${profile_dir}/packages.x86_64" \
            | awk 'NF && ($1 == "calamares" || $1 ~ /^schweisos-/) { print $1 }' \
            | sort -u
    )
fi

if ! type -P pacman >/dev/null 2>&1 || ! type -P pacman-conf >/dev/null 2>&1; then
    repository_ready=0
    repository_failure='pacman tooling unavailable'
else
    for package in "${bootstrap_host_packages[@]}"; do
        pacman -Qq -- "$package" >/dev/null 2>&1 || missing_bootstrap_packages+=("$package")
    done
    if (( ${#missing_bootstrap_packages[@]} > 0 )); then
        repository_ready=0
        repository_failure="missing host integration packages $(join_by_space "${missing_bootstrap_packages[@]}")"
    elif ! pacman-conf --config "${profile_dir}/pacman.conf" >/dev/null 2>&1; then
        repository_ready=0
        repository_failure='build-time pacman configuration is not resolvable'
    fi
fi

if (( repository_ready )); then
    repository_reader_failures=()
    for repository_tool in bsdtar sha256sum; do
        type -P "$repository_tool" >/dev/null 2>&1 || repository_reader_failures+=("$repository_tool")
    done
    if (( ${#repository_reader_failures[@]} > 0 )); then
        repository_ready=0
        repository_failure="repository payload reader unavailable $(join_by_space "${repository_reader_failures[@]}")"
    fi
fi

repository_db_path=''
if (( repository_ready )); then
    mapfile -t schweisos_servers < <(
        pacman-conf --config "${profile_dir}/pacman.conf" --repo schweisos Server 2>/dev/null
    )
    if (( ${#schweisos_servers[@]} != 1 )); then
        repository_ready=0
        repository_failure='expected exactly one SchweisOS repository endpoint'
    elif [[ "${schweisos_servers[0]}" != file:///* ]]; then
        repository_ready=0
        repository_failure='SchweisOS repository endpoint must be local file:// for build validation'
    else
        repository_root="${schweisos_servers[0]#file://}"
        if [[ ! -d "$repository_root" || -L "$repository_root" ]]; then
            repository_ready=0
            repository_failure='SchweisOS repository endpoint is missing or unsafe'
        else
            repository_db_path="${repository_root}/schweisos.db.tar.gz"
            [[ -f "$repository_db_path" && ! -L "$repository_db_path" ]] || \
                repository_db_path="${repository_root}/schweisos.db"
            if [[ ! -f "$repository_db_path" ]]; then
                repository_ready=0
                repository_failure='SchweisOS repository database is missing'
            elif ! bsdtar -tf "$repository_db_path" >/dev/null 2>&1; then
                repository_ready=0
                repository_failure='SchweisOS repository database is unreadable'
            fi
        fi
    fi
fi

if (( repository_ready )); then
    repository_artifact_failures=()
    while IFS= read -r repository_desc_path; do
        if ! repository_info="$(bsdtar -xOf "$repository_db_path" "$repository_desc_path" 2>/dev/null)"; then
            repository_artifact_failures+=("${repository_desc_path}:metadata-unreadable")
            continue
        fi
        repository_name="$(awk 'previous == "%NAME%" { print; exit } { previous = $0 }' <<<"$repository_info")"
        repository_filename="$(awk 'previous == "%FILENAME%" { print; exit } { previous = $0 }' <<<"$repository_info")"
        if [[ -z "$repository_name" || -z "$repository_filename" ]]; then
            repository_artifact_failures+=("${repository_desc_path}:metadata-incomplete")
            continue
        fi
        package_path="${repository_root}/${repository_filename}"
        package_signature="${package_path}.sig"
        if [[ ! -f "$package_path" || -L "$package_path" || ! -s "$package_path" ]]; then
            repository_artifact_failures+=("${repository_name}:package-missing")
            continue
        fi
        if [[ ! -f "$package_signature" || -L "$package_signature" || ! -s "$package_signature" ]]; then
            repository_artifact_failures+=("${repository_name}:signature-missing")
        fi
    done < <(bsdtar -tf "$repository_db_path" 2>/dev/null | sed -n '/\/desc$/p' | sort)

    if (( ${#repository_artifact_failures[@]} > 0 )); then
        repository_ready=0
        repository_failure="SchweisOS repository package/signature files incomplete $(join_by_space "${repository_artifact_failures[@]}")"
    fi
fi

if (( repository_ready )); then
    repository_version_failures=()
    if (( ${#schweisos_profile_packages[@]} == 0 )); then
        repository_version_failures+=('profile-schweisos-package-list-empty')
    fi
    for package in "${schweisos_profile_packages[@]}"; do
        package_dir="${project_root}/packages/${package}"
        if [[ ! -d "$package_dir" || -L "$package_dir" ]]; then
            repository_version_failures+=("${package}:source-directory-missing")
            continue
        fi
        if ! source_info="$(cd -- "$package_dir" && makepkg --printsrcinfo 2>/dev/null)"; then
            repository_version_failures+=("${package}:source-metadata-unavailable")
            continue
        fi
        source_pkgver="$(awk '$1 == "pkgver" && $2 == "=" { print $3; exit }' <<<"$source_info")"
        source_pkgrel="$(awk '$1 == "pkgrel" && $2 == "=" { print $3; exit }' <<<"$source_info")"
        source_epoch="$(awk '$1 == "epoch" && $2 == "=" { print $3; exit }' <<<"$source_info")"
        if [[ -z "$source_pkgver" || -z "$source_pkgrel" ]]; then
            repository_version_failures+=("${package}:source-version-invalid")
            continue
        fi
        expected_version="${source_pkgver}-${source_pkgrel}"
        if [[ -n "$source_epoch" && "$source_epoch" != 0 ]]; then
            expected_version="${source_epoch}:${expected_version}"
        fi

        if ! repository_desc_path="$(bsdtar -tf "$repository_db_path" 2>/dev/null | awk -v package="$package" '
            /\/desc$/ {
                entry = $0
                sub(/\/desc$/, "", entry)
                if (index(entry, package "-") == 1) {
                    matches[++count] = $0
                }
            }
            END { if (count == 1) print matches[1]; else exit 1 }
        ')"; then
            repository_version_failures+=("${package}:repository-metadata-unavailable")
            continue
        fi
        if ! repository_info="$(bsdtar -xOf "$repository_db_path" "$repository_desc_path" 2>/dev/null)"; then
            repository_version_failures+=("${package}:repository-metadata-unavailable")
            continue
        fi
        repository_name="$(awk 'previous == "%NAME%" { print; exit } { previous = $0 }' <<<"$repository_info")"
        repository_version="$(awk 'previous == "%VERSION%" { print; exit } { previous = $0 }' <<<"$repository_info")"
        if [[ "$repository_name" != "$package" || "$repository_version" != "$expected_version" ]]; then
            repository_version_failures+=(
                "${package}:expected-${expected_version}:found-schweisos/${repository_version:-none}"
            )
        fi
    done

    if (( ${#repository_version_failures[@]} > 0 )); then
        repository_version_failure="repository package/source mismatch $(join_by_space "${repository_version_failures[@]}")"
        repository_ready=0
        repository_failure="$repository_version_failure"
    fi
fi

if (( repository_ready )); then
    branding_desc_path="$(bsdtar -tf "$repository_db_path" 2>/dev/null | awk '
        /\/desc$/ {
            entry = $0
            sub(/\/desc$/, "", entry)
            if (index(entry, "schweisos-branding-") == 1) {
                matches[++count] = $0
            }
        }
        END { if (count == 1) print matches[1]; else exit 1 }
    ')" || branding_desc_path=''
    if [[ -z "$branding_desc_path" ]] \
        || ! branding_info="$(bsdtar -xOf "$repository_db_path" "$branding_desc_path" 2>/dev/null)"; then
        repository_ready=0
        repository_failure='schweisos-branding repository metadata is unavailable'
    else
        branding_filename="$(awk 'previous == "%FILENAME%" { print; exit } { previous = $0 }' <<<"$branding_info")"
        branding_package_path="${repository_root}/${branding_filename}"
        if [[ -z "$branding_filename" || ! -f "$branding_package_path" || -L "$branding_package_path" ]] \
            || ! branding_listing="$(bsdtar -tf "$branding_package_path" 2>/dev/null)"; then
            repository_ready=0
            repository_failure='schweisos-branding package payload is unavailable'
        else
            branding_logo_path='usr/share/schweisos/branding/schweisos.png'
            branding_logo_count="$(awk -v expected="$branding_logo_path" \
                '$0 == expected { count++ } END { print count + 0 }' <<<"$branding_listing")"
            stale_logo_count="$(awk \
                '$0 == "usr/share/schweisos/branding/schweisos-logo.png" { count++ } END { print count + 0 }' \
                <<<"$branding_listing")"
            branding_logo_details="$(bsdtar -tvf "$branding_package_path" "$branding_logo_path" 2>/dev/null || true)"
            if [[ "$branding_logo_count" -ne 1 || "$stale_logo_count" -ne 0 \
                || "$branding_logo_details" != -* ]]; then
                repository_ready=0
                repository_failure='schweisos-branding package does not contain exactly one canonical regular logo payload'
            elif ! packaged_logo_sha256="$(
                bsdtar -xOf "$branding_package_path" "$branding_logo_path" 2>/dev/null \
                    | sha256sum | awk '{ print $1 }'
            )" || ! source_logo_sha256="$(sha256sum -- "$canonical_logo" 2>/dev/null | awk '{ print $1 }')" \
                || [[ ! "$packaged_logo_sha256" =~ ^[0-9a-f]{64}$ \
                    || "$packaged_logo_sha256" != "$source_logo_sha256" ]]; then
                repository_ready=0
                repository_failure='schweisos-branding canonical logo payload does not match the repository source'
            fi
        fi
    fi
fi

if (( repository_ready )); then
    mapfile -t configured_repositories < <(
        pacman-conf --config "${profile_dir}/pacman.conf" --repo-list 2>/dev/null
    )
    configured_repository_text=" $(join_by_space "${configured_repositories[@]}") "
    if (( ${#configured_repositories[@]} != 3 )) \
        || [[ "$configured_repository_text" != *' core '* \
        || "$configured_repository_text" != *' extra '* \
        || "$configured_repository_text" != *' schweisos '* ]]; then
        repository_ready=0
        repository_failure='expected exactly core, extra, and schweisos repositories'
    fi
fi

if (( repository_ready )); then
    mapfile -t repository_siglevel < <(
        pacman-conf --config "${profile_dir}/pacman.conf" --repo schweisos SigLevel 2>/dev/null
    )
    repository_siglevel_text=" $(join_by_space "${repository_siglevel[@]}") "
    server_count="$(pacman-conf --config "${profile_dir}/pacman.conf" \
        --repo schweisos Server 2>/dev/null | sed '/^[[:space:]]*$/d' | wc -l)"
    if [[ "$repository_siglevel_text" != *' PackageRequired '* \
        || "$repository_siglevel_text" != *' PackageTrustedOnly '* \
        || "$repository_siglevel_text" != *' DatabaseRequired '* \
        || "$repository_siglevel_text" != *' DatabaseTrustedOnly '* \
        || "$repository_siglevel_text" == *' Never '* \
        || "$repository_siglevel_text" == *' TrustAll '* ]]; then
        repository_ready=0
        repository_failure='SchweisOS repository signature policy is not Required TrustedOnly'
    elif [[ ! "$server_count" =~ ^[1-9][0-9]*$ ]]; then
        repository_ready=0
        repository_failure='SchweisOS repository has no publication endpoint'
    fi
fi

if (( repository_ready )); then
    record_pass 'repository integration: trusted SchweisOS source configured'
else
    record_fail "repository integration: ${repository_failure}"
fi

if (( fail_count == 0 )); then
    if (( warn_count == 0 )); then
        printf 'Build environment validation: PASS (%d checks)\n' "$pass_count"
    else
        printf 'Build environment validation: PASS (%d checks, %d warnings)\n' \
            "$pass_count" "$warn_count"
    fi
else
    if (( warn_count == 0 )); then
        printf 'Build environment validation: FAIL (%d passed, %d failed)\n' \
            "$pass_count" "$fail_count"
    else
        printf 'Build environment validation: FAIL (%d passed, %d warnings, %d failed)\n' \
            "$pass_count" "$warn_count" "$fail_count"
    fi
fi

for result in "${results[@]}"; do
    status="${result%%|*}"
    message="${result#*|}"
    printf '  [%s] %s\n' "$status" "$message"
done

(( fail_count == 0 ))
