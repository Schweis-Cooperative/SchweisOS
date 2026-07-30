#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ISO test: FAIL (%s)\n' "$*" >&2
    exit 1
}

(( $# == 1 )) || fail 'usage: test-iso.sh ISO_PATH'
iso_path=$1
script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd -- "${script_dir}/.." && pwd -P)"

[[ -f "$iso_path" && ! -L "$iso_path" && -s "$iso_path" ]] || \
    fail 'ISO path is missing, empty, or unsafe'
iso_path="$(readlink -f -- "$iso_path")"

"${repo_root}/tests/validate-iso-loopback-boot.sh" "$iso_path"
"${repo_root}/tests/validate-built-iso-identity.sh" "$iso_path"
"${repo_root}/tests/validate-built-iso-boot.sh" "$iso_path"
"${repo_root}/scripts/schweisos-doctor" --iso "$iso_path"

printf 'ISO test: PASS\n'
printf '  ISO: %s\n' "$iso_path"
