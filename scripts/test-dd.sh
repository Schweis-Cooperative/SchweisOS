#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Read-only verification for a raw-written USB device. It compares the first
# ISO-size bytes of a block device with the source ISO. It does not write,
# partition, format, mount, unmount, or repair the device.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'Raw media test: FAIL (%s)\n' "$*" >&2
    exit 1
}

(( $# == 2 )) || fail 'usage: test-dd.sh SOURCE_ISO BLOCK_DEVICE'

source_iso=$1
block_device=$2

for tool in findmnt head lsblk readlink sha256sum stat; do
    type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done
[[ -f "$source_iso" && ! -L "$source_iso" && -s "$source_iso" ]] || \
    fail 'source ISO is missing, empty, or unsafe'
[[ -b "$block_device" ]] || fail 'target is not a block device'

source_iso="$(readlink -f -- "$source_iso")"
source_size="$(stat -c %s -- "$source_iso")"
source_sha256="$(sha256sum -- "$source_iso")"
source_sha256="${source_sha256%% *}"

root_source="$(findmnt -rn -T / -o SOURCE)"
root_source="${root_source%%\[*}"
[[ "$block_device" != "$root_source" ]] || \
    fail 'refusing to read-validate the host root filesystem device'
if findmnt -rn -S "$block_device" >/dev/null 2>&1; then
    fail 'raw-written block device must not be mounted during readback validation'
fi
mounted_children="$(
    lsblk -nrpo MOUNTPOINTS "$block_device" 2>/dev/null |
        awk 'NF { print; exit }'
)"
[[ -z "$mounted_children" ]] || \
    fail 'raw-written block device or one of its partitions is mounted'

device_sha256="$(head -c "$source_size" "$block_device" | sha256sum)"
device_sha256="${device_sha256%% *}"
[[ "$device_sha256" == "$source_sha256" ]] || \
    fail 'raw device prefix SHA256 does not match source ISO'

printf 'Raw media test: PASS\n'
printf '  source ISO: %s\n' "$source_iso"
printf '  block device: %s\n' "$block_device"
printf '  compared bytes: %s\n' "$source_size"
printf '  SHA256: %s\n' "$source_sha256"
