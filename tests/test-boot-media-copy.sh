#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
validator="${project_root}/tests/validate-boot-media-copy.sh"
test_root="$(mktemp -d)"
cleanup() {
    rm -rf -- "$test_root"
}
trap cleanup EXIT

source_iso="${test_root}/source/schweisos-2026.07.30-x86_64.iso"
build_manifest="${test_root}/build-manifest.json"
media_root="${test_root}/media"
media_iso="${media_root}/schweisos-2026.07.30-x86_64.iso"
mkdir -p -- "${source_iso%/*}" "$media_root"
printf 'SchweisOS exact boot-media copy test\n' >"$source_iso"
cp -- "$source_iso" "$media_iso"

source_size="$(stat -c %s -- "$source_iso")"
source_sha256="$(sha256sum -- "$source_iso" | awk 'NR == 1 { print $1 }')"
jq -n \
  --arg artifact_name "${source_iso##*/}" \
  --arg artifact_sha256 "$source_sha256" \
  --argjson artifact_size "$source_size" \
  '{
    schema: "schweisos.iso-build-manifest.v2",
    build_id: "boot-media-test",
    build_timestamp_utc: "2026-07-30T00:00:00Z",
    finished_at_utc: "2026-07-30T00:01:00Z",
    status: "success",
    stage: "complete",
    exit_code: 0,
    git: {
      commit: "0000000000000000000000000000000000000000",
      dirty_at_start: false,
      dirty_at_finish: false
    },
    host: {id: "arch", architecture: "x86_64"},
    archiso_version: "89-1",
    source_date_epoch: 1785369600,
    epoch_origin: "development_default",
    build_mode: "development",
    profile: "kde",
    expected_iso_name: $artifact_name,
    validation: {
      build_environment: "pass",
      installer_config: "pass",
      iso_profile: "pass",
      built_iso_identity: "pass",
      built_iso_boot: "pass",
      artifact: "pass"
    },
    mkarchiso_exit_code: 0,
    artifact_candidate_count: 1,
    artifact: {
      name: $artifact_name,
      size_bytes: $artifact_size,
      sha256: $artifact_sha256,
      blake2b_512: null,
      sha256_file: ($artifact_name + ".sha256")
    },
    build_log: "build-boot-media-test.log",
    failure_code: null
  }' >"$build_manifest"

source "$validator"
media_mount_target() {
  printf '%s\n' "$media_root"
}
media_mount_source() {
  printf '/dev/test-media\n'
}
media_mount_options() {
  printf 'ro,nosuid,nodev\n'
}
root_mount_source() {
  printf '/dev/test-root\n'
}
mount_source_is_block_device() {
  return 0
}
validate_source_iso() {
  return 0
}
validate_current_source_state() {
  return 0
}

( main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null || \
  fail 'validator rejected an exact sole media copy'

rm -- "$media_iso"
ln -- "$source_iso" "$media_iso"
if ( main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted a hard link to the source as a copied ISO'
fi
rm -- "$media_iso"
cp -- "$source_iso" "$media_iso"

printf 'different bytes\n' >"$media_iso"
if ( main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
    fail 'validator accepted a media copy with different bytes'
fi
cp -- "$source_iso" "$media_iso"

cp -- "$source_iso" "${media_root}/schweisos-2026.07.29-x86_64.iso"
if ( main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
    fail 'validator accepted multiple SchweisOS ISOs on one medium'
fi
rm -- "${media_root}/schweisos-2026.07.29-x86_64.iso"

if ( media_mount_target() { printf '/\n'; }; \
    main "$build_manifest" "$source_iso" "$media_iso" ) \
    >/dev/null 2>&1; then
  fail 'validator accepted a destination on the host root filesystem'
fi

if ( media_mount_source() { printf '/dev/test-root\n'; }; \
    main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted the host root filesystem device as boot media'
fi

if ( mount_source_is_block_device() { return 1; }; \
    main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted a destination without an available block device'
fi

if ( media_mount_options() { printf 'rw,nosuid,nodev\n'; }; \
    main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted media that was not remounted read-only'
fi

if ( validate_source_iso() { return 1; }; \
    main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted a source outside the completed-ISO boot contract'
fi

if ( validate_current_source_state() { return 1; }; \
    main "$build_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted a manifest from a different repository state'
fi

invalid_manifest="${test_root}/invalid-build-manifest.json"
jq '.artifact.sha256 = "ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff"' \
  "$build_manifest" >"$invalid_manifest"
if ( main "$invalid_manifest" "$source_iso" "$media_iso" ) >/dev/null 2>&1; then
  fail 'validator accepted a source not bound to its build manifest'
fi

cp -- "$source_iso" "${media_root}/renamed.iso"
if ( main "$build_manifest" "$source_iso" "${media_root}/renamed.iso" ) \
    >/dev/null 2>&1; then
    fail 'validator accepted a renamed non-canonical media copy'
fi

printf 'Boot media copy tests passed.\n'
