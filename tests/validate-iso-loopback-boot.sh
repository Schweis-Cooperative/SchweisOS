#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate the ISO-visible GRUB loopback contract used by multiboot tools such
# as Ventoy GRUB2 mode. This intentionally avoids extracting SquashFS: it only
# proves that the bootloader-visible ISO root contains the kernel, initramfs,
# systemd-boot entries, and upstream-Archiso-style loopback.cfg that can hand
# img_dev/img_loop to the Archiso initramfs.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

(( $# == 1 )) || fail 'usage: validate-iso-loopback-boot.sh ISO_PATH'
iso_path=$1

for tool in awk bash bsdtar cmp git grep mktemp readlink rm sed sort; do
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
    awk '$0 ~ /^boot\/[0-9-]+\\.uuid$/ { print }' <<<"$iso_listing" | sort
)
(( ${#uuid_members[@]} == 1 )) || \
    fail "ISO must contain exactly one Archiso UUID marker; found ${#uuid_members[@]}"

tmp_dir="$(mktemp -d)"
cleanup() {
    [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]] || return 0
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

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

printf 'ISO loopback boot validation passed.\n'
printf '  ISO: %s\n' "$iso_path"
printf '  kernel: /%s/boot/%s/vmlinuz-linux\n' "$install_dir" "$arch"
printf '  initramfs: /%s/boot/%s/initramfs-linux.img\n' "$install_dir" "$arch"
printf '  loopback: /boot/grub/loopback.cfg with img_dev/img_loop handoff\n'
