#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Read-only Ventoy/file-based multiboot evidence. The destination ISO must be
# on media that has been synchronized, safely removed, reinserted, and mounted
# read-only before this script is run.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'Ventoy media test: FAIL (%s)\n' "$*" >&2
    exit 1
}

(( $# == 3 )) || \
    fail 'usage: test-ventoy.sh BUILD_MANIFEST SOURCE_ISO COPIED_ISO_ON_MEDIA'

build_manifest=$1
source_iso=$2
copied_iso=$3
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"

"${repo_root}/scripts/schweisos-doctor" --iso "$source_iso"
"${repo_root}/tests/validate-boot-media-copy.sh" \
    "$build_manifest" "$source_iso" "$copied_iso"

printf 'Ventoy media test: PASS\n'
printf '  copied ISO: %s\n' "$(readlink -f -- "$copied_iso")"
printf '  note: boot Normal Mode first; use GRUB2 Mode only as separate evidence, not as a workaround.\n'
