#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

require_tool() {
    type -P "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

for tool in chmod cp date find git mkdir mktemp rm sed sha256sum stat; do
    require_tool "$tool"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/.." && pwd -P)"
creator="${project_root}/scripts/create-release-artifacts.sh"
validator="${project_root}/tests/validate-release-artifacts.sh"

[[ -x "$creator" ]] || fail 'release artifact creator is not executable'
[[ -x "$validator" ]] || fail 'release artifact validator is not executable'

mkdir -p -- "${project_root}/release"
tmp_root="$(mktemp --directory --tmpdir="${project_root}/release" .release-tests.XXXXXX)"
cleanup() {
    find "$tmp_root" -type d -exec chmod u+rwx -- {} + 2>/dev/null || true
    rm -rf -- "$tmp_root"
}
trap cleanup EXIT

pass_count=0

current_commit="$(git -C "$project_root" rev-parse --verify HEAD)"
iso_name='schweisos-2026.07.25-x86_64.iso'

write_fixture() {
    local case_dir=$1
    mkdir -p -- "${case_dir}/out" "${case_dir}/logs" "${case_dir}/release"
    printf 'SchweisOS disposable ISO fixture\n' >"${case_dir}/out/${iso_name}"
    cat >"${case_dir}/logs/build-manifest.json" <<EOF
{
  "schema": "schweisos.iso-build-manifest.v1",
  "build_id": "test",
  "build_timestamp_utc": "2026-07-25T00:00:00Z",
  "finished_at_utc": "2026-07-25T00:01:00Z",
  "status": "success",
  "stage": "complete",
  "exit_code": 0,
  "git": {
    "commit": "${current_commit}",
    "dirty_at_start": false,
    "dirty_at_finish": false
  },
  "archiso_version": "test",
  "source_date_epoch": 1784937600,
  "expected_iso_name": "${iso_name}",
  "validation": {
    "build_environment": "pass",
    "iso_profile": "pass",
    "artifact": "pass"
  },
  "mkarchiso_exit_code": 0,
  "artifact": {
    "name": "${iso_name}"
  },
  "build_log": "build-test.log",
  "failure_code": null
}
EOF
    chmod 0644 -- "${case_dir}/out/${iso_name}" "${case_dir}/logs/build-manifest.json"
}

prepare_release() {
    local case_name=$1
    local case_dir="${tmp_root}/${case_name}"
    write_fixture "$case_dir"
    "$creator" \
        --release-id 2026.07 \
        --iso "${case_dir}/out/${iso_name}" \
        --build-manifest "${case_dir}/logs/build-manifest.json" \
        --output-root "${case_dir}/release" \
        >/dev/null
    printf '%s\n' "${case_dir}/release/2026.07"
}

expect_success() {
    local name=$1
    shift
    if "$@" >/dev/null 2>&1; then
        (( pass_count += 1 ))
        printf '[PASS] %s\n' "$name"
    else
        fail "expected success: ${name}"
    fi
}

expect_failure() {
    local name=$1
    shift
    if "$@" >/dev/null 2>&1; then
        fail "expected failure: ${name}"
    else
        (( pass_count += 1 ))
        printf '[PASS] %s\n' "$name"
    fi
}

release_dir="$(prepare_release success)"
expect_success 'successful artifact validation' "$validator" "$release_dir"

release_dir="$(prepare_release missing-checksum)"
rm -- "${release_dir}/checksum/${iso_name}.sha256"
expect_failure 'missing checksum' "$validator" "$release_dir"

release_dir="$(prepare_release invalid-checksum)"
printf '%064d  %s\n' 0 "$iso_name" >"${release_dir}/checksum/${iso_name}.sha256"
expect_failure 'invalid checksum' "$validator" "$release_dir"

release_dir="$(prepare_release empty-iso)"
: >"${release_dir}/iso/${iso_name}"
expect_failure 'empty ISO' "$validator" "$release_dir"

release_dir="$(prepare_release duplicate-iso)"
cp -- "${release_dir}/iso/${iso_name}" "${release_dir}/iso/schweisos-2026.07.26-x86_64.iso"
expect_failure 'duplicate ISO' "$validator" "$release_dir"

release_dir="$(prepare_release corrupt-manifest)"
printf '{\n' >"${release_dir}/manifests/release-manifest.json"
expect_failure 'corrupt manifest' "$validator" "$release_dir"

release_dir="$(prepare_release unexpected-files)"
printf 'unexpected\n' >"${release_dir}/unexpected.txt"
chmod 0644 -- "${release_dir}/unexpected.txt"
expect_failure 'unexpected files' "$validator" "$release_dir"

release_dir="$(prepare_release symlink-attack)"
rm -- "${release_dir}/logs/release-artifacts.log"
ln -s /etc/passwd "${release_dir}/logs/release-artifacts.log"
expect_failure 'symlink attack' "$validator" "$release_dir"

release_dir="$(prepare_release path-traversal)"
sed -i 's#"iso_filename": "[^"]*"#"iso_filename": "../evil.iso"#' \
    "${release_dir}/manifests/release-manifest.json"
expect_failure 'path traversal' "$validator" "$release_dir"

release_dir="$(prepare_release permission-violation)"
chmod 0666 -- "${release_dir}/RELEASE_NOTES.md"
expect_failure 'permission violation' "$validator" "$release_dir"

case_dir="${tmp_root}/empty-input"
write_fixture "$case_dir"
: >"${case_dir}/out/${iso_name}"
expect_failure 'creator rejects empty ISO' "$creator" \
    --release-id 2026.07 \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/duplicate-output"
write_fixture "$case_dir"
"$creator" \
    --release-id 2026.07 \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release" \
    >/dev/null
expect_failure 'creator refuses existing release' "$creator" \
    --release-id 2026.07 \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

printf 'Release artifact tests: PASS (%d checks)\n' "$pass_count"
