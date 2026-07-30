#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate a completed ISO build manifest as canonical, exact-schema JSON and
# optionally bind it to the exact ISO bytes it describes.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ISO build manifest validation: FAIL (%s)\n' "$*" >&2
    exit 1
}

for tool in awk b2sum basename cmp jq readlink sha256sum stat; do
    type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

release_required=false
if [[ "${1-}" == --release ]]; then
    release_required=true
    shift
fi

(( $# == 1 || $# == 2 )) || \
    fail 'usage: validate-iso-build-manifest.sh [--release] BUILD_MANIFEST [ISO_PATH]'

manifest_path=$1
[[ -f "$manifest_path" && ! -L "$manifest_path" && -s "$manifest_path" ]] || \
    fail 'build manifest must be a nonempty regular non-symlink file'
manifest_path="$(readlink -f -- "$manifest_path")"

if ! jq --indent 2 . "$manifest_path" | cmp -s -- "$manifest_path" -; then
    fail 'build manifest is not canonical unambiguous JSON'
fi

if ! jq -e '
    def exact_keys($expected):
        type == "object" and (keys == ($expected | sort));

    exact_keys([
        "schema", "build_id", "build_timestamp_utc", "finished_at_utc",
        "status", "stage", "exit_code", "git", "host", "archiso_version",
        "source_date_epoch", "epoch_origin", "build_mode", "profile",
        "expected_iso_name", "validation", "mkarchiso_exit_code",
        "artifact_candidate_count", "artifact", "build_log", "failure_code"
    ])
    and .schema == "schweisos.iso-build-manifest.v2"
    and (.build_id | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.build_timestamp_utc | type == "string"
        and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and (.finished_at_utc | type == "string"
        and test("^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$"))
    and .status == "success"
    and .stage == "complete"
    and .exit_code == 0
    and (.git | exact_keys(["commit", "dirty_at_start", "dirty_at_finish"]))
    and (.git.commit | type == "string" and test("^[0-9a-f]{40,64}$"))
    and .git.dirty_at_start == false
    and .git.dirty_at_finish == false
    and (.host | exact_keys(["id", "architecture"]))
    and (.host.id | type == "string" and test("^[a-z0-9._-]+$"))
    and (.host.architecture | type == "string" and test("^[A-Za-z0-9._-]+$"))
    and (.archiso_version | type == "string" and test("^[A-Za-z0-9.+_~:-]+$"))
    and (.source_date_epoch | type == "number" and . >= 0 and floor == .)
    and (.epoch_origin | type == "string"
        and (. == "environment" or . == "development_default"))
    and (.build_mode | type == "string"
        and (. == "development" or . == "release"))
    and (.profile | type == "string" and test("^[a-z0-9._+-]+$"))
    and (.expected_iso_name | type == "string"
        and test("^schweisos-[0-9]{4}\\.[0-9]{2}\\.[0-9]{2}-x86_64\\.iso$"))
    and (.validation | exact_keys([
        "build_environment", "installer_config", "iso_profile",
        "built_iso_identity", "built_iso_boot", "built_iso_forensics",
        "artifact"
    ]))
    and .validation.build_environment == "pass"
    and .validation.installer_config == "pass"
    and .validation.iso_profile == "pass"
    and .validation.built_iso_identity == "pass"
    and .validation.built_iso_boot == "pass"
    and .validation.built_iso_forensics == "pass"
    and .validation.artifact == "pass"
    and .mkarchiso_exit_code == 0
    and .artifact_candidate_count == 1
    and (.artifact | exact_keys([
        "name", "size_bytes", "sha256", "blake2b_512", "sha256_file"
    ]))
    and .artifact.name == .expected_iso_name
    and (.artifact.size_bytes | type == "number" and . > 0 and floor == .)
    and (.artifact.sha256 | type == "string" and test("^[0-9a-f]{64}$"))
    and ((.artifact.blake2b_512 == null)
        or (.artifact.blake2b_512 | type == "string" and test("^[0-9a-f]{128}$")))
    and .artifact.sha256_file == (.expected_iso_name + ".sha256")
    and (.build_log | type == "string" and test("^[A-Za-z0-9._-]+\\.log$"))
    and .failure_code == null
' "$manifest_path" >/dev/null; then
    fail 'build manifest schema, types, or success invariants are invalid'
fi

if [[ "$release_required" == true ]] && ! jq -e '
    .build_mode == "release"
    and .epoch_origin == "environment"
    and .host.id == "arch"
    and .host.architecture == "x86_64"
    and (.artifact.blake2b_512 | type == "string" and test("^[0-9a-f]{128}$"))
' "$manifest_path" >/dev/null; then
    fail 'build manifest is not eligible for release staging'
fi

if (( $# == 2 )); then
    iso_path=$2
    [[ -f "$iso_path" && ! -L "$iso_path" && -s "$iso_path" ]] || \
        fail 'ISO must be a nonempty regular non-symlink file'
    iso_path="$(readlink -f -- "$iso_path")"

    manifest_name="$(jq -r '.artifact.name' "$manifest_path")"
    manifest_size="$(jq -r '.artifact.size_bytes' "$manifest_path")"
    manifest_sha256="$(jq -r '.artifact.sha256' "$manifest_path")"
    manifest_blake2b="$(jq -r '.artifact.blake2b_512 // empty' "$manifest_path")"
    iso_name="$(basename -- "$iso_path")"
    iso_size="$(stat -c %s -- "$iso_path")"
    iso_sha256="$(sha256sum -- "$iso_path" | awk 'NR == 1 { print $1 }')"

    [[ "$manifest_name" == "$iso_name" ]] || fail 'ISO basename does not match manifest'
    [[ "$manifest_size" == "$iso_size" ]] || fail 'ISO size does not match manifest'
    [[ "$manifest_sha256" == "$iso_sha256" ]] || fail 'ISO SHA256 does not match manifest'
    if [[ -n "$manifest_blake2b" ]]; then
        iso_blake2b="$(b2sum -- "$iso_path" | awk 'NR == 1 { print $1 }')"
        [[ "$manifest_blake2b" == "$iso_blake2b" ]] || \
            fail 'ISO BLAKE2b-512 does not match manifest'
    fi
fi

printf 'ISO build manifest validation: PASS\n'
