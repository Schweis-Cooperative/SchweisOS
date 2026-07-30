#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate the ISO-visible GRUB loopback contract available to an outer GRUB
# that consumes Archiso's loopback.cfg. A multiboot tool's mode label does not
# prove that it selected this contract. This intentionally avoids extracting
# SquashFS: it only proves that the bootloader-visible ISO root contains the
# kernel, initramfs, systemd-boot entries, and upstream-Archiso-style
# loopback.cfg that can hand img_dev/img_loop to the Archiso initramfs. It also
# proves that the generated ISO volume metadata, Archiso UUID marker, native
# systemd-boot cmdlines, and initramfs hook list agree with one another,
# including SchweisOS' narrow removable ISO-file fallback for multiboot paths
# that use native Archiso search without an img_dev/img_loop handoff.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

(( $# == 1 )) || fail 'usage: validate-iso-loopback-boot.sh ISO_PATH'
iso_path=$1

for tool in awk bash bsdtar cmp git grep lsinitcpio mktemp readlink rm sed sort xorriso; do
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
volume_id="$(
    xorriso -indev "$iso_path" -pvd_info 2>/dev/null | \
        awk -F ':' '$1 ~ /^[[:space:]]*Volume Id[[:space:]]*$/ {
            value = $2
            sub(/^[[:space:]]+/, "", value)
            sub(/[[:space:]]+$/, "", value)
            print value
            exit
        }'
)"
[[ -n "$volume_id" ]] || fail 'unable to read ISO volume ID'
[[ "$volume_id" =~ ^[A-Z0-9_]{1,32}$ ]] || \
    fail "ISO volume ID is outside the approved Archiso label contract: ${volume_id}"

profile_dir="${project_root}/iso/profiles/kde"
profiledef="${profile_dir}/profiledef.sh"
loopback_source="${profile_dir}/grub/loopback.cfg"
[[ -f "$profiledef" && ! -L "$profiledef" ]] || fail 'profiledef.sh is missing'
[[ -f "$loopback_source" && ! -L "$loopback_source" ]] || \
    fail 'source loopback.cfg is missing'

install_dir="$(
    SOURCE_DATE_EPOCH=0 bash -c 'source "$1"; printf "%s\n" "$install_dir"' _ "$profiledef"
)"
arch="$(
    SOURCE_DATE_EPOCH=0 bash -c 'source "$1"; printf "%s\n" "$arch"' _ "$profiledef"
)"
[[ "$install_dir" =~ ^[a-z0-9._-]+$ ]] || fail 'invalid Archiso install directory'
[[ "$arch" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'invalid Archiso architecture'

iso_listing="$(bsdtar -tf "$iso_path")" || fail 'ISO archive is unreadable'

require_iso_member_once() {
    local member=$1
    local count
    count="$(awk -v expected="$member" '$0 == expected { count++ } END { print count + 0 }' \
        <<<"$iso_listing")"
    [[ "$count" -eq 1 ]] || fail "ISO must contain exactly one ${member}; found ${count}"
}

require_iso_member_once "${install_dir}/boot/${arch}/vmlinuz-linux"
require_iso_member_once "${install_dir}/boot/${arch}/initramfs-linux.img"
require_iso_member_once "${install_dir}/${arch}/airootfs.sfs"
require_iso_member_once boot/grub/grubenv
require_iso_member_once boot/grub/loopback.cfg
require_iso_member_once loader/loader.conf
require_iso_member_once loader/entries/01-schweisos-linux.conf
require_iso_member_once loader/entries/02-schweisos-linux-debug.conf
require_iso_member_once EFI/boot.cat
require_iso_member_once EFI/BOOT/BOOTx64.EFI

for forbidden_member in boot/grub/grub.cfg syslinux/syslinux.cfg; do
    forbidden_count="$(awk -v expected="$forbidden_member" \
        '$0 == expected { count++ } END { print count + 0 }' <<<"$iso_listing")"
    [[ "$forbidden_count" -eq 0 ]] || \
        fail "ISO must not contain ${forbidden_member} under the current UEFI systemd-boot live contract"
done

mapfile -t uuid_members < <(
    awk '$0 ~ /^boot\/[0-9-]+\.uuid$/ { print }' <<<"$iso_listing" | sort
)
(( ${#uuid_members[@]} == 1 )) || \
    fail "ISO must contain exactly one Archiso UUID marker; found ${#uuid_members[@]}"
iso_uuid="${uuid_members[0]#boot/}"
iso_uuid="${iso_uuid%.uuid}"
[[ "$iso_uuid" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}-[0-9]{2}$ ]] || \
    fail "Archiso UUID marker has an unexpected format: ${iso_uuid}"
grep -a -m 1 -F "${iso_uuid}.uuid" "$iso_path" >/dev/null 2>&1 || \
    fail 'ISO UUID marker is not discoverable by the initramfs ISO-file fallback scan'

tmp_dir="$(mktemp -d)"
cleanup() {
    [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]] || return 0
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

bsdtar -xOf "$iso_path" boot/grub/grubenv >"${tmp_dir}/grubenv" || \
    fail 'unable to extract boot/grub/grubenv'
grubenv_volume_id="$(awk -F '=' '$1 == "ARCHISO_LABEL" { print $2; exit }' "${tmp_dir}/grubenv")"
grubenv_install_dir="$(awk -F '=' '$1 == "INSTALL_DIR" { print $2; exit }' "${tmp_dir}/grubenv")"
grubenv_arch="$(awk -F '=' '$1 == "ARCH" { print $2; exit }' "${tmp_dir}/grubenv")"
grubenv_search_file="$(awk -F '=' '$1 == "ARCHISO_SEARCH_FILENAME" { print $2; exit }' "${tmp_dir}/grubenv")"
[[ "$grubenv_volume_id" == "$volume_id" ]] || \
    fail "grubenv ARCHISO_LABEL (${grubenv_volume_id}) does not match ISO volume ID (${volume_id})"
[[ "$grubenv_install_dir" == "$install_dir" ]] || \
    fail "grubenv INSTALL_DIR (${grubenv_install_dir}) does not match profile install_dir (${install_dir})"
[[ "$grubenv_arch" == "$arch" ]] || \
    fail "grubenv ARCH (${grubenv_arch}) does not match profile arch (${arch})"
[[ "$grubenv_search_file" == "/boot/${iso_uuid}.uuid" ]] || \
    fail "grubenv ARCHISO_SEARCH_FILENAME (${grubenv_search_file}) does not match ISO UUID marker (${iso_uuid})"

for entry_name in 01-schweisos-linux.conf 02-schweisos-linux-debug.conf; do
    entry_member="loader/entries/${entry_name}"
    entry_file="${tmp_dir}/${entry_name}"
    bsdtar -xOf "$iso_path" "$entry_member" >"$entry_file" || \
        fail "unable to extract ${entry_member}"
    entry_linux="$(awk '$1 == "linux" { print $2; exit }' "$entry_file")"
    entry_initrd="$(awk '$1 == "initrd" { print $2; exit }' "$entry_file")"
    entry_options="$(awk '$1 == "options" { $1 = ""; sub(/^[[:space:]]+/, ""); print; exit }' "$entry_file")"
    [[ "$entry_linux" == "/${install_dir}/boot/${arch}/vmlinuz-linux" ]] || \
        fail "${entry_name} uses an unexpected native kernel path"
    [[ "$entry_initrd" == "/${install_dir}/boot/${arch}/initramfs-linux.img" ]] || \
        fail "${entry_name} uses an unexpected native initramfs path"
    [[ " $entry_options " == *" archisobasedir=${install_dir} "* ]] || \
        fail "${entry_name} is missing the Archiso base directory"
    [[ " $entry_options " == *" archisosearchuuid=${iso_uuid} "* ]] || \
        fail "${entry_name} archisosearchuuid does not match the ISO UUID marker"
    [[ " $entry_options " != *' archisolabel='* ]] || \
        fail "${entry_name} must not mix archisolabel with the native archisosearchuuid contract"
    [[ " $entry_options " == *' systemd.firstboot=no '* ]] || \
        fail "${entry_name} must disable interactive systemd-firstboot"
    case "$entry_name" in
        01-schweisos-linux.conf)
            [[ " $entry_options " == *' quiet '* \
                && " $entry_options " == *' splash '* \
                && " $entry_options " == *' loglevel=3 '* \
                && " $entry_options " == *' systemd.show_status=auto '* \
                && " $entry_options " == *' vt.global_cursor_default=0 '* ]] || \
                fail 'normal native entry does not preserve the quiet graphical boot contract'
            ;;
        02-schweisos-linux-debug.conf)
            [[ " $entry_options " != *' quiet '* \
                && " $entry_options " != *' splash '* \
                && " $entry_options " == *' loglevel=7 '* \
                && " $entry_options " == *' systemd.show_status=yes '* \
                && " $entry_options " == *' vt.global_cursor_default=1 '* ]] || \
                fail 'debug native entry does not preserve the visible diagnostic contract'
            ;;
    esac
done

bsdtar -xOf "$iso_path" boot/grub/loopback.cfg >"${tmp_dir}/loopback.cfg" || \
    fail 'unable to extract boot/grub/loopback.cfg'
sed "s|%INSTALL_DIR%|${install_dir}|g; s|%ARCH%|${arch}|g" \
    "$loopback_source" >"${tmp_dir}/expected-loopback.cfg"
cmp -s "${tmp_dir}/expected-loopback.cfg" "${tmp_dir}/loopback.cfg" || \
    fail 'built loopback.cfg differs from the validated profile source'
if grep -Eq '%[A-Z][A-Z0-9_]*%' "${tmp_dir}/loopback.cfg"; then
    fail 'built loopback.cfg still contains unresolved Archiso template tokens'
fi

normal_linux="$(
    awk "/--id 'schweisos'/,/^}/ { if (\$1 == \"linux\") { \$1 = \"\"; sub(/^[[:space:]]+/, \"\"); print; exit } }" \
        "${tmp_dir}/loopback.cfg"
)"
debug_linux="$(
    awk "/--id 'schweisos-debug'/,/^}/ { if (\$1 == \"linux\") { \$1 = \"\"; sub(/^[[:space:]]+/, \"\"); print; exit } }" \
        "${tmp_dir}/loopback.cfg"
)"
normal_initrd="$(
    awk "/--id 'schweisos'/,/^}/ { if (\$1 == \"initrd\") { print \$2; exit } }" \
        "${tmp_dir}/loopback.cfg"
)"
debug_initrd="$(
    awk "/--id 'schweisos-debug'/,/^}/ { if (\$1 == \"initrd\") { print \$2; exit } }" \
        "${tmp_dir}/loopback.cfg"
)"
[[ "$normal_linux" == "/${install_dir}/boot/${arch}/vmlinuz-linux "* ]] || \
    fail 'normal loopback entry uses an unexpected kernel path'
[[ "$debug_linux" == "/${install_dir}/boot/${arch}/vmlinuz-linux "* ]] || \
    fail 'debug loopback entry uses an unexpected kernel path'
[[ "$normal_initrd" == "/${install_dir}/boot/${arch}/initramfs-linux.img" ]] || \
    fail 'normal loopback entry uses an unexpected initramfs path'
[[ "$debug_initrd" == "/${install_dir}/boot/${arch}/initramfs-linux.img" ]] || \
    fail 'debug loopback entry uses an unexpected initramfs path'

for linux_line in "$normal_linux" "$debug_linux"; do
    [[ " $linux_line " == *" archisobasedir=${install_dir} "* ]] || \
        fail 'loopback entry is missing archisobasedir'
    [[ " $linux_line " == *' img_dev=UUID=${archiso_img_dev_uuid} '* ]] || \
        fail 'loopback entry is missing the img_dev UUID handoff'
    [[ " $linux_line " == *' img_loop="${iso_path}" '* ]] || \
        fail 'loopback entry is missing the img_loop handoff'
    [[ " $linux_line " == *' systemd.firstboot=no '* ]] || \
        fail 'loopback entry must disable interactive systemd-firstboot'
done

[[ " $normal_linux " == *' quiet '* \
    && " $normal_linux " == *' splash '* \
    && " $normal_linux " == *' loglevel=3 '* \
    && " $normal_linux " == *' systemd.show_status=auto '* \
    && " $normal_linux " == *' vt.global_cursor_default=0 '* ]] || \
    fail 'normal loopback entry does not preserve the quiet graphical boot contract'
[[ " $debug_linux " != *' quiet '* \
    && " $debug_linux " != *' splash '* \
    && " $debug_linux " == *' loglevel=7 '* \
    && " $debug_linux " == *' systemd.show_status=yes '* \
    && " $debug_linux " == *' vt.global_cursor_default=1 '* ]] || \
    fail 'debug loopback entry does not preserve the visible diagnostic contract'

bsdtar -xOf "$iso_path" "${install_dir}/boot/${arch}/initramfs-linux.img" \
    >"${tmp_dir}/initramfs-linux.img" || \
    fail 'unable to extract the live initramfs'
initramfs_config="$(lsinitcpio --config "${tmp_dir}/initramfs-linux.img")" || \
    fail 'unable to read the live initramfs configuration'
grep -Fxq 'HOOKS=(base udev modconf kms plymouth archiso archiso_loop_mnt schweisos_iso_file_fallback block filesystems)' \
    <<<"$initramfs_config" || \
    fail 'live initramfs is missing the approved loopback and ISO-file fallback hook order'

printf 'ISO loopback boot validation passed.\n'
printf '  ISO: %s\n' "$iso_path"
printf '  volume label: %s\n' "$volume_id"
printf '  Archiso UUID marker: %s\n' "$iso_uuid"
printf '  ISO-file marker scan: raw marker discoverable\n'
printf '  kernel: /%s/boot/%s/vmlinuz-linux\n' "$install_dir" "$arch"
printf '  initramfs: /%s/boot/%s/initramfs-linux.img\n' "$install_dir" "$arch"
printf '  native boot: archisosearchuuid matches the ISO UUID marker\n'
printf '  loopback: /boot/grub/loopback.cfg with img_dev/img_loop handoff\n'
printf '  initramfs: archiso_loop_mnt plus SchweisOS ISO-file fallback verified\n'
