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

for tool in b2sum chmod cp date find git ln mkdir mktemp rm sed sha256sum stat; do
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
zero_blake2b="$(printf '%0128d' 0)"

current_commit="$(git -C "$project_root" rev-parse --verify HEAD)"
release_id='2026.07.27'
iso_name="schweisos-${release_id}-x86_64.iso"

write_fixture() {
    local case_dir=$1
    local fixture_size
    local fixture_sha256
    local fixture_blake2b
    mkdir -p -- "${case_dir}/out" "${case_dir}/logs" "${case_dir}/release"
    printf 'SchweisOS disposable ISO fixture\n' >"${case_dir}/out/${iso_name}"
    fixture_size="$(stat -c %s -- "${case_dir}/out/${iso_name}")"
    fixture_sha256="$(sha256sum -- "${case_dir}/out/${iso_name}" | sed -nE 's/^([0-9a-f]{64})[[:space:]].*/\1/p')"
    fixture_blake2b="$(b2sum -- "${case_dir}/out/${iso_name}" | sed -nE 's/^([0-9a-f]{128})[[:space:]].*/\1/p')"
    cat >"${case_dir}/logs/build-manifest.json" <<EOF
{
  "schema": "schweisos.iso-build-manifest.v2",
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
  "host": {
    "id": "arch",
    "architecture": "x86_64"
  },
  "archiso_version": "test",
  "source_date_epoch": 1784937600,
  "epoch_origin": "environment",
  "build_mode": "release",
  "profile": "kde",
  "expected_iso_name": "${iso_name}",
  "validation": {
    "build_environment": "pass",
    "installer_config": "pass",
    "iso_profile": "pass",
    "built_iso_identity": "pass",
    "built_iso_boot": "pass",
    "built_iso_forensics": "pass",
    "artifact": "pass"
  },
  "mkarchiso_exit_code": 0,
  "artifact_candidate_count": 1,
  "artifact": {
    "name": "${iso_name}",
    "size_bytes": ${fixture_size},
    "sha256": "${fixture_sha256}",
    "blake2b_512": "${fixture_blake2b}",
    "sha256_file": "${iso_name}.sha256"
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
        --release-id "$release_id" \
        --iso "${case_dir}/out/${iso_name}" \
        --build-manifest "${case_dir}/logs/build-manifest.json" \
        --output-root "${case_dir}/release" \
        >/dev/null
    printf '%s\n' "${case_dir}/release/${release_id}"
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
cp -- "${release_dir}/iso/${iso_name}" "${release_dir}/iso/schweisos-2026.07.28-x86_64.iso"
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
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/symlink-iso-input"
write_fixture "$case_dir"
ln -s -- "${case_dir}/out/${iso_name}" "${case_dir}/out/symlink.iso"
expect_failure 'creator rejects symlink ISO input' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/symlink.iso" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/symlink-build-manifest-input"
write_fixture "$case_dir"
ln -s -- "${case_dir}/logs/build-manifest.json" "${case_dir}/logs/symlink-build-manifest.json"
expect_failure 'creator rejects symlink build manifest input' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/symlink-build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/legacy-build-manifest"
write_fixture "$case_dir"
sed -i 's/schweisos\.iso-build-manifest\.v2/schweisos.iso-build-manifest.v1/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects legacy build manifest' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/ambiguous-build-manifest"
write_fixture "$case_dir"
sed -i '/"status": "success",/a\\  "status": "success",' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects duplicate build manifest key' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/extra-build-manifest-field"
write_fixture "$case_dir"
sed -i '1a\\  "unexpected": "value",' "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects extra build manifest field' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/development-build-manifest"
write_fixture "$case_dir"
sed -i 's/"build_mode": "release"/"build_mode": "development"/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects development build manifest' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/failed-built-identity"
write_fixture "$case_dir"
sed -i 's/"built_iso_identity": "pass"/"built_iso_identity": "fail"/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects failed built ISO identity validation' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/failed-built-boot"
write_fixture "$case_dir"
sed -i 's/"built_iso_boot": "pass"/"built_iso_boot": "fail"/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects failed built ISO boot validation' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/failed-built-forensics"
write_fixture "$case_dir"
sed -i 's/"built_iso_forensics": "pass"/"built_iso_forensics": "fail"/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects failed built ISO forensic diagnostics' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/build-size-mismatch"
write_fixture "$case_dir"
sed -i 's/"size_bytes": [0-9]*/"size_bytes": 1/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects build manifest size mismatch' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/build-sha256-mismatch"
write_fixture "$case_dir"
sed -i 's/"sha256": "[0-9a-f]\{64\}"/"sha256": "0000000000000000000000000000000000000000000000000000000000000000"/' \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects build manifest SHA256 mismatch' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/build-blake2b-mismatch"
write_fixture "$case_dir"
sed -i "s/\"blake2b_512\": \"[0-9a-f]\\{128\\}\"/\"blake2b_512\": \"${zero_blake2b}\"/" \
    "${case_dir}/logs/build-manifest.json"
expect_failure 'creator rejects build manifest BLAKE2b mismatch' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/same-size-iso-mismatch"
write_fixture "$case_dir"
sed -i '1s/^S/X/' "${case_dir}/out/${iso_name}"
expect_failure 'creator rejects same-size changed ISO' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/release-id-mismatch"
write_fixture "$case_dir"
expect_failure 'creator rejects ISO release identifier mismatch' "$creator" \
    --release-id 2026.07.28 \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

case_dir="${tmp_root}/profile-mismatch"
write_fixture "$case_dir"
expect_failure 'creator rejects profile provenance mismatch' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --profile other \
    --output-root "${case_dir}/release"

release_dir="$(prepare_release copied-build-manifest-tamper)"
sed -i 's/"built_iso_forensics": "pass"/"built_iso_forensics": "fail"/' \
    "${release_dir}/manifests/build-manifest.json"
expect_failure 'validator rejects copied build manifest tamper' "$validator" "$release_dir"

release_dir="$(prepare_release copied-build-sha256-tamper)"
sed -i 's/"sha256": "[0-9a-f]\{64\}"/"sha256": "0000000000000000000000000000000000000000000000000000000000000000"/' \
    "${release_dir}/manifests/build-manifest.json"
expect_failure 'validator rejects copied build manifest SHA256 tamper' "$validator" "$release_dir"

release_dir="$(prepare_release copied-build-blake2b-tamper)"
sed -i "s/\"blake2b_512\": \"[0-9a-f]\\{128\\}\"/\"blake2b_512\": \"${zero_blake2b}\"/" \
    "${release_dir}/manifests/build-manifest.json"
expect_failure 'validator rejects copied build manifest BLAKE2b tamper' "$validator" "$release_dir"

release_dir="$(prepare_release release-manifest-cross-field-tamper)"
sed -i 's/"git_commit": "[0-9a-f]\{40,64\}"/"git_commit": "0000000000000000000000000000000000000000"/' \
    "${release_dir}/manifests/release-manifest.json"
expect_failure 'validator rejects release/build manifest mismatch' "$validator" "$release_dir"

release_dir="$(prepare_release release-validator-version-tamper)"
sed -i 's/"release_artifact_validator": "2"/"release_artifact_validator": "1"/' \
    "${release_dir}/manifests/release-manifest.json"
expect_failure 'validator rejects release validator version mismatch' "$validator" "$release_dir"

release_dir="$(prepare_release release-notes-tamper)"
printf 'tampered\n' >"${release_dir}/RELEASE_NOTES.md"
expect_failure 'validator rejects release notes tamper' "$validator" "$release_dir"

release_dir="$(prepare_release release-log-tamper)"
printf 'tampered\n' >"${release_dir}/logs/release-artifacts.log"
expect_failure 'validator rejects release log tamper' "$validator" "$release_dir"

case_dir="${tmp_root}/duplicate-output"
write_fixture "$case_dir"
"$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release" \
    >/dev/null
expect_failure 'creator refuses existing release' "$creator" \
    --release-id "$release_id" \
    --iso "${case_dir}/out/${iso_name}" \
    --build-manifest "${case_dir}/logs/build-manifest.json" \
    --output-root "${case_dir}/release"

printf 'Release artifact tests: PASS (%d checks)\n' "$pass_count"
