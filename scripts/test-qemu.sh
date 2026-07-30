#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Bounded QEMU smoke harness. This is useful engineering evidence, but it is
# not a substitute for Ventoy or physical hardware qualification.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

usage() {
    cat <<'EOF'
Usage: scripts/test-qemu.sh ISO_PATH [--timeout SECONDS]

Runs a bounded direct-kernel Archiso smoke test with the ISO attached as a
virtual CD-ROM and serial logging enabled. The script does not use KVM by
default and does not modify the ISO.
EOF
}

fail() {
    printf 'QEMU smoke test: FAIL (%s)\n' "$*" >&2
    exit 1
}

(( $# >= 1 )) || {
    usage >&2
    exit 2
}

iso_path=$1
shift
timeout_seconds=180
while (( $# > 0 )); do
    case "$1" in
        --timeout)
            shift
            (( $# > 0 )) || fail '--timeout requires seconds'
            timeout_seconds=$1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            fail "unknown argument: $1"
            ;;
    esac
    shift
done
[[ "$timeout_seconds" =~ ^[1-9][0-9]*$ ]] || fail 'timeout must be a positive integer'

for tool in awk bsdtar grep mkdir mktemp qemu-system-x86_64 readlink rm timeout; do
    type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
[[ -f "$iso_path" && ! -L "$iso_path" && -s "$iso_path" ]] || \
    fail 'ISO path is missing, empty, or unsafe'
iso_path="$(readlink -f -- "$iso_path")"
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"

tmp_dir="$(mktemp -d)"
cleanup() {
    [[ -n "${tmp_dir:-}" && -d "$tmp_dir" ]] || return 0
    rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

iso_listing="$(bsdtar -tf "$iso_path")" || fail 'ISO listing is unreadable'
squashfs_member="$(awk '$0 ~ /^[^/]+\/x86_64\/airootfs\.sfs$/ { print; exit }' <<<"$iso_listing")"
[[ -n "$squashfs_member" ]] || fail 'airootfs.sfs member is missing'
install_dir="${squashfs_member%%/*}"
uuid_member="$(awk '$0 ~ /^boot\/[0-9-]+\.uuid$/ { print; exit }' <<<"$iso_listing")"
[[ -n "$uuid_member" ]] || fail 'Archiso UUID marker is missing'
iso_uuid="${uuid_member#boot/}"
iso_uuid="${iso_uuid%.uuid}"

kernel_member="${install_dir}/boot/x86_64/vmlinuz-linux"
initramfs_member="${install_dir}/boot/x86_64/initramfs-linux.img"
bsdtar -xOf "$iso_path" "$kernel_member" >"${tmp_dir}/vmlinuz-linux" || \
    fail 'unable to extract kernel'
bsdtar -xOf "$iso_path" "$initramfs_member" >"${tmp_dir}/initramfs-linux.img" || \
    fail 'unable to extract initramfs'

log_dir="${repo_root}/logs/qemu"
mkdir -p -- "$log_dir"
log_file="$(mktemp --tmpdir="$log_dir" 'qemu-smoke-XXXXXXXX.log')"
set +e
timeout --foreground "$timeout_seconds" qemu-system-x86_64 \
    -machine q35,accel=tcg \
    -m 4096 \
    -smp 2 \
    -cdrom "$iso_path" \
    -kernel "${tmp_dir}/vmlinuz-linux" \
    -initrd "${tmp_dir}/initramfs-linux.img" \
    -append "archisobasedir=${install_dir} archisosearchuuid=${iso_uuid} checksum=y systemd.firstboot=no loglevel=7 systemd.show_status=yes console=ttyS0" \
    -display none \
    -serial "file:${log_file}" \
    -no-reboot
qemu_status=$?
set -e

if grep -Eq 'Checksum is OK|Reached target Graphical Interface|Started.*Display Manager|Starting.*Display Manager' \
    "$log_file"; then
    printf 'QEMU smoke test: PASS\n'
    printf '  ISO: %s\n' "$iso_path"
    printf '  serial log: %s\n' "$log_file"
    exit 0
fi

printf 'QEMU smoke test: FAIL\n' >&2
printf '  qemu exit status: %s\n' "$qemu_status" >&2
printf '  serial log: %s\n' "$log_file" >&2
sed -n '1,220p' "$log_file" >&2 || true
exit 1
