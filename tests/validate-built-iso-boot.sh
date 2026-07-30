#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate the boot payload that mkarchiso actually embedded. Static source
# validation cannot prove that the active signed repository supplied the
# current branding package or that mkinitcpio copied its external ImageDir.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

(( $# == 1 )) || fail 'usage: validate-built-iso-boot.sh ISO_PATH'
iso_path=$1

for tool in awk bash bsdtar chmod cmp find git grep lsinitcpio makepkg mkdir \
    mktemp readlink rm sha256sum sort stat systemd-analyze unsquashfs; do
    type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/.." && pwd -P)"
git_root="$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null)" || \
    fail 'repository root is unavailable'
git_root="$(cd -- "$git_root" && pwd -P)"
[[ "$git_root" == "$project_root" ]] || fail 'validator is not running from the repository root'

[[ -f "$iso_path" && ! -L "$iso_path" && -s "$iso_path" ]] || \
    fail 'ISO artifact is missing, empty, or unsafe'
iso_path="$(readlink -f -- "$iso_path")"
"${project_root}/tests/validate-iso-loopback-boot.sh" "$iso_path" >/dev/null || \
    fail 'built ISO does not satisfy the GRUB loopback boot contract'

profile_dir="${project_root}/iso/profiles/kde"
profiledef="${profile_dir}/profiledef.sh"
branding_dir="${project_root}/packages/schweisos-branding"
canonical_logo="${project_root}/branding/assets/logo/schweisos.png"
[[ -f "$profiledef" && -f "$canonical_logo" ]] || fail 'canonical boot sources are missing'

branding_srcinfo="$(cd -- "$branding_dir" && makepkg --printsrcinfo)"
branding_pkgver="$(awk -F ' = ' '$1 == "\tpkgver" { print $2; exit }' <<<"$branding_srcinfo")"
branding_pkgrel="$(awk -F ' = ' '$1 == "\tpkgrel" { print $2; exit }' <<<"$branding_srcinfo")"
branding_epoch="$(awk -F ' = ' '$1 == "\tepoch" { print $2; exit }' <<<"$branding_srcinfo")"
[[ -n "$branding_pkgver" && -n "$branding_pkgrel" ]] || \
    fail 'source schweisos-branding version is unreadable'
expected_branding_version="${branding_pkgver}-${branding_pkgrel}"
if [[ -n "$branding_epoch" && "$branding_epoch" != 0 ]]; then
    expected_branding_version="${branding_epoch}:${expected_branding_version}"
fi

install_dir="$(
    SOURCE_DATE_EPOCH=0 bash -c 'source "$1"; printf "%s\n" "$install_dir"' _ "$profiledef"
)"
[[ "$install_dir" =~ ^[a-z0-9._-]+$ ]] || fail 'invalid Archiso install directory'
arch="$(
    SOURCE_DATE_EPOCH=0 bash -c 'source "$1"; printf "%s\n" "$arch"' _ "$profiledef"
)"
[[ "$arch" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'invalid Archiso architecture'
squashfs_member="${install_dir}/${arch}/airootfs.sfs"
initramfs_member="${install_dir}/boot/${arch}/initramfs-linux.img"

iso_listing="$(bsdtar -tf "$iso_path")" || fail 'ISO archive is unreadable'
for member in \
    "$squashfs_member" \
    "$initramfs_member" \
    loader/loader.conf \
    loader/entries/01-schweisos-linux.conf \
    loader/entries/02-schweisos-linux-debug.conf; do
    member_count="$(awk -v expected="$member" '$0 == expected { count++ } END { print count + 0 }' \
        <<<"$iso_listing")"
    [[ "$member_count" -eq 1 ]] || fail "ISO must contain exactly one ${member}"
done

mapfile -t iso_loader_entries < <(
    awk '/^loader\/entries\/[^/]+\.conf$/ { print }' <<<"$iso_listing" | sort
)
[[ "${iso_loader_entries[*]}" == \
    'loader/entries/01-schweisos-linux.conf loader/entries/02-schweisos-linux-debug.conf' ]] || \
    fail 'ISO contains an unexpected systemd-boot entry set'

mapfile -t iso_uuid_members < <(
    awk '$0 ~ /^boot\/[0-9-]+\.uuid$/ { print }' <<<"$iso_listing" | sort
)
(( ${#iso_uuid_members[@]} == 1 )) || \
    fail "ISO must contain exactly one Archiso UUID marker; found ${#iso_uuid_members[@]}"
iso_uuid="${iso_uuid_members[0]#boot/}"
iso_uuid="${iso_uuid%.uuid}"

tmp_parent="${TMPDIR:-${project_root}/work/validators/built-iso-boot}"
[[ -n "$tmp_parent" && "$tmp_parent" != / ]] || fail 'unsafe temporary directory parent'
mkdir -p -- "$tmp_parent"
[[ -d "$tmp_parent" && ! -L "$tmp_parent" ]] || \
    fail 'temporary directory parent is missing or unsafe'
tmp_parent="$(readlink -f -- "$tmp_parent")"
tmp_dir="$(mktemp -d "${tmp_parent%/}/schweisos-built-iso-boot.XXXXXXXXXX")"
cleanup() {
    [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]] || return 0
    chmod -R u+rwX -- "$tmp_dir" 2>/dev/null || true
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

bsdtar -xOf "$iso_path" loader/loader.conf >"${tmp_dir}/loader.conf" || \
    fail 'unable to extract loader/loader.conf'
cmp -s "${profile_dir}/efiboot/loader/loader.conf" "${tmp_dir}/loader.conf" || \
    fail 'built loader.conf differs from the validated profile source'

for entry_name in 01-schweisos-linux.conf 02-schweisos-linux-debug.conf; do
    entry_member="loader/entries/${entry_name}"
    entry_file="${tmp_dir}/${entry_name}"
    expected_entry="${tmp_dir}/expected-${entry_name}"
    bsdtar -xOf "$iso_path" "$entry_member" >"$entry_file" || \
        fail "unable to extract ${entry_member}"
    sed "s|%INSTALL_DIR%|${install_dir}|g; s|%ARCH%|${arch}|g; s|%ARCHISO_UUID%|${iso_uuid}|g" \
        "${profile_dir}/efiboot/loader/entries/${entry_name}" >"$expected_entry"
    cmp -s "$expected_entry" "$entry_file" || \
        fail "built ${entry_name} differs from the validated profile source"
    options="$(awk '$1 == "options" { $1 = ""; sub(/^[[:space:]]+/, ""); print }' "$entry_file")"
    firstboot_options="$(tr ' ' '\n' <<<"$options" | grep '^systemd\.firstboot=' || true)"
    [[ "$firstboot_options" == systemd.firstboot=no ]] || \
        fail "${entry_name} does not disable interactive systemd-firstboot exactly once"
    case "$entry_name" in
        01-schweisos-linux.conf)
            [[ " $options " == *' quiet '* && " $options " == *' splash '* \
                && " $options " == *' systemd.show_status=auto '* ]] || \
                fail 'built normal entry does not preserve the quiet diagnostic-aware contract'
            ;;
        02-schweisos-linux-debug.conf)
            [[ " $options " != *' quiet '* && " $options " != *' splash '* \
                && " $options " == *' systemd.show_status=yes '* ]] || \
                fail 'built debug entry does not preserve the visible diagnostic contract'
            ;;
    esac
done

bsdtar -xOf "$iso_path" "$squashfs_member" >"${tmp_dir}/airootfs.sfs" || \
    fail 'unable to extract the airootfs SquashFS'
[[ -s "${tmp_dir}/airootfs.sfs" ]] || fail 'extracted airootfs SquashFS is empty'
unsquashfs -no-progress -no-xattrs -d "${tmp_dir}/rootfs" \
    "${tmp_dir}/airootfs.sfs" >/dev/null
rootfs="${tmp_dir}/rootfs"

mapfile -t branding_records < <(
    find "${rootfs}/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d \
        -name 'schweisos-branding-*' -print | sort
)
(( ${#branding_records[@]} == 1 )) || \
    fail "expected one installed schweisos-branding record; found ${#branding_records[@]}"
branding_desc="${branding_records[0]}/desc"
branding_files="${branding_records[0]}/files"
installed_branding_name="$(awk '$0 == "%NAME%" { getline; print; exit }' "$branding_desc")"
installed_branding_version="$(awk '$0 == "%VERSION%" { getline; print; exit }' "$branding_desc")"
[[ "$installed_branding_name" == schweisos-branding ]] || \
    fail 'installed schweisos-branding metadata is invalid'
[[ "$installed_branding_version" == "$expected_branding_version" ]] || \
    fail "ISO contains schweisos-branding ${installed_branding_version}; source requires ${expected_branding_version}"
grep -Fxq 'usr/share/schweisos/branding/schweisos.png' "$branding_files" || \
    fail 'installed schweisos-branding does not own the canonical runtime logo'

runtime_logo="${rootfs}/usr/share/schweisos/branding/schweisos.png"
[[ -f "$runtime_logo" && ! -L "$runtime_logo" ]] || \
    fail 'canonical runtime logo is missing or not a regular file'
cmp -s "$canonical_logo" "$runtime_logo" || \
    fail 'runtime logo does not match the canonical repository artwork'
[[ ! -e "${rootfs}/usr/share/schweisos/branding/schweisos-logo.png" \
    && ! -L "${rootfs}/usr/share/schweisos/branding/schweisos-logo.png" ]] || \
    fail 'stale runtime logo path is present in the built ISO'

rootfs_payloads=(
    etc/hostname
    etc/locale.conf
    etc/plymouth/plymouthd.conf
    etc/polkit-1/rules.d/49-schweisos-live-admin.rules
    etc/sddm.conf.d/10-schweisos-live.conf
    etc/systemd/system/emergency.target.d/10-schweisos-debug-fallback.conf
    etc/systemd/system/plymouth-quit-wait.service.d/10-schweisos-debug-fallback.conf
    etc/systemd/system/plymouth-quit.service.d/10-schweisos-debug-fallback.conf
    etc/systemd/system/plymouth-start.service.d/10-schweisos-debug-fallback.conf
    etc/systemd/system/schweisos-boot-debug-fallback.service
    etc/systemd/system/schweisos-plymouth-exit-fallback.service
    etc/systemd/system/schweisos-plymouth-exit-watch.path
    etc/systemd/system/schweisos-plymouth-watchdog.service
    etc/systemd/system/sddm.service.d/10-schweisos-debug-fallback.conf
    etc/systemd/system/sysinit.target.d/10-schweisos-plymouth-watch.conf
    etc/sysusers.d/schweisos-live.conf
    etc/sudoers.d/10-schweisos-live
    etc/tmpfiles.d/schweisos-live.conf
    usr/lib/initcpio/hooks/schweisos_iso_file_fallback
    usr/lib/initcpio/install/schweisos_iso_file_fallback
    usr/lib/schweisos-live/plymouth-is-stopped
    usr/lib/schweisos-live/plymouth-quit-guarded
    usr/lib/schweisos-live/session
    usr/lib/schweisos-live/plymouth-watchdog
    usr/share/plymouth/themes/schweisos/schweisos.plymouth
    usr/share/plymouth/themes/schweisos/schweisos.script
)
for relative_path in "${rootfs_payloads[@]}"; do
    source_path="${profile_dir}/airootfs/${relative_path}"
    built_path="${rootfs}/${relative_path}"
    [[ -f "$source_path" && ! -L "$source_path" \
        && -f "$built_path" && ! -L "$built_path" ]] || \
        fail "built live-boot payload is missing: ${relative_path}"
    cmp -s "$source_path" "$built_path" || \
        fail "built live-boot payload differs from source: ${relative_path}"
    if [[ "$relative_path" == etc/sudoers.d/10-schweisos-live ]]; then
        [[ "$(stat -c %a -- "$built_path")" == 440 ]] || \
            fail 'built live sudoers drop-in must be mode 0440'
    else
        [[ "$(stat -c %a -- "$source_path")" == "$(stat -c %a -- "$built_path")" ]] || \
            fail "built live-boot payload mode differs from source: ${relative_path}"
    fi
done

[[ "$(stat -c %a -- "${rootfs}/usr/lib/schweisos-live/plymouth-is-stopped")" == 755 \
    && "$(stat -c %a -- "${rootfs}/usr/lib/schweisos-live/plymouth-quit-guarded")" == 755 \
    && "$(stat -c %a -- "${rootfs}/usr/lib/schweisos-live/plymouth-watchdog")" == 755 ]] || \
    fail 'built Plymouth fallback helpers are not executable'
[[ "$(<"${rootfs}/etc/locale.conf")" == LANG=C.UTF-8 ]] || \
    fail 'built live root does not use the Archiso C.UTF-8 locale baseline'
[[ "$(<"${rootfs}/usr/lib/schweisos-live/session")" == SCHWEISOS_LIVE_SESSION=1 ]] || \
    fail 'built live root does not contain the canonical live-session marker'
mapfile -t live_marker_package_owners < <(
    for package_files in "${rootfs}"/var/lib/pacman/local/*/files; do
        [[ -f "$package_files" ]] || continue
        if grep -Fxq 'usr/lib/schweisos-live/session' "$package_files"; then
            package_record="${package_files%/files}"
            printf '%s\n' "${package_record##*/}"
        fi
    done | sort
)
(( ${#live_marker_package_owners[@]} == 0 )) || \
    fail "built live profile marker must be overlay-owned, not package-owned: ${live_marker_package_owners[*]}"
[[ -L "${rootfs}/etc/localtime" \
    && "$(readlink -- "${rootfs}/etc/localtime")" == /usr/share/zoneinfo/UTC ]] || \
    fail 'built live root does not use the neutral UTC timezone baseline'
[[ -L "${rootfs}/etc/systemd/system/display-manager.service" \
    && "$(readlink -- "${rootfs}/etc/systemd/system/display-manager.service")" \
        == /usr/lib/systemd/system/sddm.service ]] || \
    fail 'built live root does not enable SDDM'
grep -Fxq 'm live wheel' "${rootfs}/etc/sysusers.d/schweisos-live.conf" || \
    fail 'built live root does not add the live user to wheel'
grep -Fxq 'live ALL=(ALL:ALL) NOPASSWD: ALL' "${rootfs}/etc/sudoers.d/10-schweisos-live" || \
    fail 'built live root does not grant passwordless sudo to the live user'
for required_polkit_fragment in \
    'subject.user == "live"' \
    'subject.local' \
    'subject.active' \
    'polkit.Result.YES'; do
    grep -Fq "$required_polkit_fragment" \
        "${rootfs}/etc/polkit-1/rules.d/49-schweisos-live-admin.rules" || \
        fail "built live polkit rule is missing: ${required_polkit_fragment}"
done
[[ ! -e "${rootfs}/usr/share/applications/calamares.desktop" \
    && ! -L "${rootfs}/usr/share/applications/calamares.desktop" ]] || \
    fail 'built live root retains the generic Calamares launcher'
installer_desktop="${rootfs}/usr/share/applications/schweisos-installer.desktop"
installer_autostart="${rootfs}/etc/xdg/autostart/schweisos-installer-autostart.desktop"
installer_wrapper="${rootfs}/usr/bin/schweisos-installer"
installer_autostart_helper="${rootfs}/usr/lib/schweisos-calamares/autostart"
installer_live_session_helper="${rootfs}/usr/lib/schweisos-calamares/is-live-session"
installer_root_helper="${rootfs}/usr/lib/schweisos-calamares/launch-root"
installer_policy="${rootfs}/usr/share/polkit-1/actions/org.schweisos.installer.policy"
installer_branding="${rootfs}/etc/calamares/branding/schweisos/branding.desc"
installer_slideshow="${rootfs}/etc/calamares/branding/schweisos/show.qml"
for installer_payload in \
    "$installer_desktop" \
    "$installer_autostart" \
    "$installer_wrapper" \
    "$installer_autostart_helper" \
    "$installer_live_session_helper" \
    "$installer_root_helper" \
    "$installer_policy" \
    "$installer_branding" \
    "$installer_slideshow"; do
    [[ -f "$installer_payload" && ! -L "$installer_payload" ]] || \
        fail "built live root is missing installer experience payload: ${installer_payload#"$rootfs"/}"
done
[[ "$(stat -c %a -- "$installer_wrapper")" == 755 \
    && "$(stat -c %a -- "$installer_autostart_helper")" == 755 \
    && "$(stat -c %a -- "$installer_live_session_helper")" == 755 \
    && "$(stat -c %a -- "$installer_root_helper")" == 755 ]] || \
    fail 'built installer launch helpers are not executable'
grep -Fxq 'Name=Install SchweisOS' "$installer_desktop" || \
    fail 'built installer launcher does not use the SchweisOS product name'
grep -Fxq 'Icon=schweisos' "$installer_desktop" || \
    fail 'built installer launcher does not use the canonical icon name'
grep -Fxq 'NoDisplay=true' "$installer_autostart" || \
    fail 'built installer autostart entry is visible in the application menu'
grep -Fxq 'Exec=/usr/lib/schweisos-calamares/autostart' "$installer_autostart" || \
    fail 'built installer autostart entry does not use the packaged helper'
grep -Fq '/usr/bin/sleep 3' "$installer_autostart_helper" || \
    fail 'built installer autostart does not preserve the desktop-settle delay'
grep -Fq 'autostart-attempted' "$installer_autostart_helper" || \
    fail 'built installer autostart is not once-only'
grep -Fq '/usr/lib/schweisos-calamares/is-live-session' "$installer_autostart_helper" || \
    fail 'built installer autostart bypasses the shared live-session predicate'
grep -Fq '/usr/bin/flock -n' "$installer_wrapper" || \
    fail 'built installer launcher lacks its single-instance guard'
grep -Fq '/usr/bin/kdialog' "$installer_wrapper" || \
    fail 'built installer launcher lacks visible failure handling'
grep -Fq '/usr/lib/schweisos-calamares/is-live-session' "$installer_wrapper" || \
    fail 'built installer launcher bypasses the shared live-session predicate'
grep -Fq 'mountpoint_is_mounted /run/archiso/airootfs' \
    "$installer_live_session_helper" || \
    fail 'built installer live-session predicate omits the persistent Archiso root'
grep -Fq '/usr/bin/stat -c %s' "$installer_live_session_helper" || \
    fail 'built installer live-session predicate does not require an exact marker'
grep -Fq 'Automatic installer start was blocked.' "$installer_autostart_helper" || \
    fail 'built installer autostart hides live-session contract failures'
if grep -Fq '/run/archiso/bootmnt' \
    "$installer_wrapper" "$installer_autostart_helper" "$installer_live_session_helper"; then
    fail 'built installer launch policy depends on transient Archiso bootmnt'
fi
grep -Fxq 'export QT_QPA_PLATFORM=xcb' "$installer_root_helper" || \
    fail 'built installer root helper does not use the XWayland bridge'
grep -Fq '/usr/lib/schweisos-calamares/launch-root</annotate>' "$installer_policy" || \
    fail 'built installer Polkit policy is not bound to the exact helper path'
grep -Fq 'org.freedesktop.policykit.exec.allow_gui">true</annotate>' "$installer_policy" || \
    fail 'built installer Polkit policy cannot carry display authorization'
grep -Fxq 'slideshow: "show.qml"' "$installer_branding" || \
    fail 'built installer branding omits the Calamares slideshow contract'
grep -Fq 'file:///usr/share/schweisos/branding/schweisos.png' "$installer_slideshow" || \
    fail 'built installer slideshow does not reference the canonical runtime logo'
generic_installer_entry="$(grep -RIl --include='*.desktop' \
    '^Name=Install System$' "${rootfs}/usr/share/applications" \
    "${rootfs}/usr/local/share/applications" 2>/dev/null || true)"
[[ -z "$generic_installer_entry" ]] || \
    fail "built live root exposes a generic installer launcher: ${generic_installer_entry#"$rootfs"/}"
for plymouth_activation in \
    sysinit.target.wants/plymouth-start.service:../plymouth-start.service \
    multi-user.target.wants/plymouth-quit.service:../plymouth-quit.service \
    multi-user.target.wants/plymouth-quit-wait.service:../plymouth-quit-wait.service; do
    activation_path="${plymouth_activation%%:*}"
    activation_target="${plymouth_activation#*:}"
    built_activation="${rootfs}/usr/lib/systemd/system/${activation_path}"
    [[ -L "$built_activation" && "$(readlink -- "$built_activation")" == "$activation_target" ]] || \
        fail "built live root is missing Plymouth activation: ${activation_path}"
done
[[ -f "${rootfs}/usr/share/wayland-sessions/plasma.desktop" \
    && -x "${rootfs}/usr/bin/startplasma-wayland" ]] || \
    fail 'built live root is missing the Plasma Wayland session'

if ! systemd-analyze --root="$rootfs" --man=no --generators=no verify \
    plymouth-start.service \
    plymouth-quit.service \
    plymouth-quit-wait.service \
    schweisos-boot-debug-fallback.service \
    schweisos-plymouth-exit-fallback.service \
    schweisos-plymouth-exit-watch.path \
    schweisos-plymouth-watchdog.service \
    sddm.service \
    emergency.target; then
    fail 'built live-root boot units failed systemd verification'
fi

bsdtar -xOf "$iso_path" "$initramfs_member" >"${tmp_dir}/initramfs-linux.img" || \
    fail 'unable to extract the live initramfs'
[[ -s "${tmp_dir}/initramfs-linux.img" ]] || fail 'extracted live initramfs is empty'
initramfs_config="$(lsinitcpio --config "${tmp_dir}/initramfs-linux.img")" || \
    fail 'unable to read the live initramfs configuration'
grep -Fxq 'HOOKS=(base udev modconf kms plymouth archiso archiso_loop_mnt schweisos_iso_file_fallback block filesystems)' \
    <<<"$initramfs_config" || \
    fail 'built initramfs does not contain the approved Plymouth, loopback, and ISO-file fallback hook order'

mkdir -p "${tmp_dir}/initramfs-root"
(
    cd -- "${tmp_dir}/initramfs-root"
    lsinitcpio --extract --cpio "${tmp_dir}/initramfs-linux.img" >/dev/null
) || fail 'unable to extract the main live initramfs'
initramfs_root="${tmp_dir}/initramfs-root"

initramfs_payloads=(
    etc/plymouth/plymouthd.conf
    usr/share/plymouth/themes/schweisos/schweisos.plymouth
    usr/share/plymouth/themes/schweisos/schweisos.script
)
for relative_path in "${initramfs_payloads[@]}"; do
    source_path="${profile_dir}/airootfs/${relative_path}"
    initramfs_path="${initramfs_root}/${relative_path}"
    [[ -f "$initramfs_path" && ! -L "$initramfs_path" ]] || \
        fail "initramfs payload is missing: ${relative_path}"
    cmp -s "$source_path" "$initramfs_path" || \
        fail "initramfs payload differs from source: ${relative_path}"
done
initramfs_logo="${initramfs_root}/usr/share/schweisos/branding/schweisos.png"
[[ -f "$initramfs_logo" && ! -L "$initramfs_logo" ]] || \
    fail 'initramfs is missing the canonical Plymouth logo'
cmp -s "$canonical_logo" "$initramfs_logo" || \
    fail 'initramfs Plymouth logo does not match the canonical repository artwork'
[[ ! -e "${initramfs_root}/usr/share/schweisos/branding/schweisos-logo.png" \
    && ! -L "${initramfs_root}/usr/share/schweisos/branding/schweisos-logo.png" ]] || \
    fail 'initramfs contains the stale runtime logo path'
[[ -f "${initramfs_root}/usr/lib/plymouth/script.so" \
    && -x "${initramfs_root}/usr/bin/plymouth" ]] || \
    fail 'initramfs is missing the Plymouth script runtime'
[[ -f "${initramfs_root}/hooks/schweisos_iso_file_fallback" \
    && -x "${initramfs_root}/hooks/schweisos_iso_file_fallback" ]] || \
    fail 'initramfs is missing the SchweisOS ISO-file fallback runtime hook'
cmp -s "${profile_dir}/airootfs/usr/lib/initcpio/hooks/schweisos_iso_file_fallback" \
    "${initramfs_root}/hooks/schweisos_iso_file_fallback" || \
    fail 'initramfs ISO-file fallback runtime hook differs from source'
for fallback_runtime in \
    usr/bin/find \
    usr/bin/grep \
    usr/bin/losetup \
    usr/bin/lsblk \
    usr/bin/modprobe \
    usr/bin/mount \
    usr/bin/umount; do
    [[ -x "${initramfs_root}/${fallback_runtime}" ]] || \
        fail "initramfs is missing ISO-file fallback runtime binary: ${fallback_runtime}"
done
grep -Fq "mount_handler='schweisos_iso_file_mount_handler'" \
    "${initramfs_root}/hooks/schweisos_iso_file_fallback" || \
    fail 'initramfs ISO-file fallback hook does not install the SchweisOS mount handler'

printf 'Built ISO boot validation passed.\n'
printf '  ISO: %s\n' "$(basename -- "$iso_path")"
printf '  branding: schweisos-branding %s\n' "$installed_branding_version"
printf '  logo SHA256: %s\n' "$(sha256sum -- "$runtime_logo" | awk '{ print $1 }')"
printf '  loopback: GRUB ISO-file handoff and native-search fallback verified\n'
printf '  live defaults: LANG=C.UTF-8, UTC, systemd-firstboot disabled\n'
printf '  initramfs: Plymouth theme, script plugin, and canonical logo verified\n'
