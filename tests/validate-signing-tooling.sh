#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

for tool in bash find git grep sed stat; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
signing_dir="${project_root}/tools/signing"
policy="${project_root}/docs/release/release-signing-workflow.md"
admission_policy="${project_root}/docs/release/keyring-admission.md"

required_files=(
  "${signing_dir}/README.md"
  "${signing_dir}/release-policy.tsv"
  "${signing_dir}/create-offline-release-key.sh"
  "${signing_dir}/export-operational-subkeys.sh"
  "${signing_dir}/admit-public-bundle.sh"
  "${signing_dir}/bootstrap-pacman-trust.sh"
  "${signing_dir}/import-operational-subkeys.sh"
  "${signing_dir}/sign-artifact.sh"
  "${signing_dir}/smoke-test-signing-home.sh"
  "${signing_dir}/validate-admitted-public-bundle.sh"
  "${signing_dir}/validate-public-bundle.sh"
  "${signing_dir}/validate-signing-home.sh"
  "${signing_dir}/verify-artifact-signature.sh"
  "${project_root}/tools/release/create-repository-candidate.sh"
  "${project_root}/tools/release/activate-build-repository.sh"
  "${project_root}/tools/release/sign-repository-metadata.sh"
  "${project_root}/tools/release/validate-release-repository.sh"
  "${project_root}/tools/release/README.md"
  "${project_root}/tests/validate-built-iso-identity.sh"
  "${project_root}/tests/validate-keyring-package.sh"
  "${project_root}/tests/validate-signed-repository-client.sh"
  "${project_root}/docs/release/offline-ceremony-checklist.md"
  "${project_root}/docs/release/production-trust-bootstrap.md"
  "$policy"
  "$admission_policy"
)
for required_file in "${required_files[@]}"; do
  [[ -f "$required_file" && ! -L "$required_file" ]] || \
    fail "missing or unsafe signing infrastructure file: $required_file"
done

[[ "$(stat -c '%a' "${signing_dir}/release-policy.tsv")" == 644 ]] || \
  fail 'release policy source mode must be 0644'
uid_literal_sources="$({
  grep -RIl -- 'SchweisOS Release Authority <' "$signing_dir" || true
})"
[[ "$uid_literal_sources" == "${signing_dir}/release-policy.tsv" ]] || \
  fail 'release UID must have exactly one machine-readable policy source'
for policy_consumer in \
  "${signing_dir}/create-offline-release-key.sh" \
  "${signing_dir}/validate-public-bundle.sh"; do
  grep -Fq -- 'release-policy.tsv' "$policy_consumer" || \
    fail "signing policy consumer does not use the shared source: $policy_consumer"
done

for admitted_bundle_consumer in \
  "${signing_dir}/bootstrap-pacman-trust.sh" \
  "${signing_dir}/import-operational-subkeys.sh" \
  "${signing_dir}/sign-artifact.sh" \
  "${signing_dir}/validate-signing-home.sh" \
  "${signing_dir}/verify-artifact-signature.sh" \
  "${project_root}/tools/release/create-repository-candidate.sh" \
  "${project_root}/tools/release/validate-release-repository.sh"; do
  grep -Fq -- 'validate-admitted-public-bundle.sh' "$admitted_bundle_consumer" || \
    fail "production consumer is not bound to the admitted trust root: $admitted_bundle_consumer"
done

for admission_text in \
  'pacman-key --populate schweisos' \
  'must not run `pacman-key --init`' \
  'Arch keyring files and trust remain unchanged' \
  'no secret-key packets'; do
  grep -Fqi -- "$admission_text" "$admission_policy" || \
    fail "keyring admission policy is missing: $admission_text"
done

bash -n \
  "${signing_dir}/admit-public-bundle.sh" \
  "${signing_dir}/bootstrap-pacman-trust.sh" \
  "${signing_dir}/create-offline-release-key.sh" \
  "${signing_dir}/export-operational-subkeys.sh" \
  "${signing_dir}/import-operational-subkeys.sh" \
  "${signing_dir}/sign-artifact.sh" \
  "${signing_dir}/smoke-test-signing-home.sh" \
  "${signing_dir}/validate-admitted-public-bundle.sh" \
  "${signing_dir}/validate-public-bundle.sh" \
  "${signing_dir}/validate-signing-home.sh" \
  "${signing_dir}/verify-artifact-signature.sh" \
  "${project_root}/tools/release/create-repository-candidate.sh" \
  "${project_root}/tools/release/activate-build-repository.sh" \
  "${project_root}/tools/release/sign-repository-metadata.sh" \
  "${project_root}/tools/release/validate-release-repository.sh" \
  "${project_root}/tests/validate-built-iso-identity.sh" \
  "${project_root}/tests/validate-keyring-package.sh" \
  "${project_root}/tests/validate-signed-repository-client.sh" \
  "${BASH_SOURCE[0]}"

for executable in \
  "${signing_dir}/admit-public-bundle.sh" \
  "${signing_dir}/bootstrap-pacman-trust.sh" \
  "${signing_dir}/create-offline-release-key.sh" \
  "${signing_dir}/export-operational-subkeys.sh" \
  "${signing_dir}/import-operational-subkeys.sh" \
  "${signing_dir}/sign-artifact.sh" \
  "${signing_dir}/smoke-test-signing-home.sh" \
  "${signing_dir}/validate-admitted-public-bundle.sh" \
  "${signing_dir}/validate-public-bundle.sh" \
  "${signing_dir}/validate-signing-home.sh" \
  "${signing_dir}/verify-artifact-signature.sh" \
  "${project_root}/tools/release/create-repository-candidate.sh" \
  "${project_root}/tools/release/activate-build-repository.sh" \
  "${project_root}/tools/release/sign-repository-metadata.sh" \
  "${project_root}/tools/release/validate-release-repository.sh" \
  "${project_root}/tests/validate-built-iso-identity.sh" \
  "${project_root}/tests/validate-keyring-package.sh" \
  "${project_root}/tests/validate-signed-repository-client.sh" \
  "${BASH_SOURCE[0]}"; do
  [[ -x "$executable" ]] || fail "signing script is not executable: $executable"
  [[ "$(stat -c '%a' "$executable")" == 755 ]] || \
    fail "signing script mode must be 0755: $executable"
done

if grep -RIEq --include='*.sh' \
    -- '--passphrase|pinentry-mode[[:space:]]+loopback|--no-protection|--quick-set-expire[[:space:]]+0' \
    "$signing_dir"; then
  fail 'signing tooling contains unattended or unprotected passphrase handling'
fi
if grep -RIEq --include='*.sh' \
    'SigLevel[[:space:]]*=[[:space:]]*Never|TrustAll' \
    "$signing_dir"; then
  fail 'signing tooling weakens pacman trust policy'
fi
if grep -RIEiq \
    'BEGIN (PGP |OPENSSH |RSA |EC )?(PUBLIC|PRIVATE) KEY|(^|[^A-Za-z])(PASSWORD|TOKEN|SECRET)[[:space:]]*=' \
    "$signing_dir"; then
  fail 'signing tooling contains embedded key material or a hardcoded secret'
fi

key_generation_hits="$({
  grep -RIl \
    --include='*.sh' \
    --exclude='validate-signing-tooling.sh' \
    -- '--quick-generate-key' \
    "${project_root}/iso" \
    "${project_root}/packages" \
    "${project_root}/scripts" \
    "${project_root}/tests" \
    "${project_root}/tools" || true
})"
[[ "$key_generation_hits" == "${signing_dir}/create-offline-release-key.sh" ]] || \
  fail 'production key generation must exist only in the offline ceremony entry point'

ceremony_script="${signing_dir}/create-offline-release-key.sh"
for required_guard in \
  'EUID != 0' \
  'SSH_CONNECTION' \
  'systemd-detect-virt --quiet' \
  'ip -o -4 route show default' \
  'ip -o address show scope global' \
  'networkctl --no-pager --no-legend list' \
  'degraded-carrier' \
  'acknowledge-airgapped' \
  'acknowledge-clock-verified' \
  'LUKS-backed filesystem' \
  'outside the repository'; do
  grep -Fq -- "$required_guard" "$ceremony_script" || \
    fail "offline ceremony guard is missing: $required_guard"
done

subkey_export_script="${signing_dir}/export-operational-subkeys.sh"
for required_guard in \
  'EUID != 0' \
  'SSH_CONNECTION' \
  'systemd-detect-virt --quiet' \
  'networkctl --no-pager --no-legend list' \
  'degraded-carrier' \
  'acknowledge-encrypted-media' \
  'require_luks_backing' \
  'outside the source repository' \
  '--export-secret-subkeys' \
  'operational export contains usable offline primary material'; do
  grep -Fq -- "$required_guard" "$subkey_export_script" || \
    fail "operational subkey export guard is missing: $required_guard"
done

sign_script="${signing_dir}/sign-artifact.sh"
grep -Fq -- '--local-user "${signing_fingerprint}!"' "$sign_script" || \
  fail 'signing entry point does not select the exact role subkey'
grep -Fq -- 'signature output already exists' "$sign_script" || \
  fail 'signing entry point does not fail closed on duplicate output'
grep -Fq -- '--expected-sha256' "$sign_script" || \
  fail 'signing entry point is not bound to an approved artifact digest'
grep -Fq -- 'artifact.snapshot' "$sign_script" || \
  fail 'signing entry point does not sign a private immutable snapshot'
grep -Fq -- 'verify-artifact-signature.sh' "$sign_script" || \
  fail 'signing entry point does not immediately verify its output'
grep -Fq -- 'validate-signing-home.sh' "$sign_script" || \
  fail 'signing entry point does not validate the restricted key inventory'

verification_script="${signing_dir}/verify-artifact-signature.sh"
for required_guard in \
  'EXPKEYSIG' \
  'REVKEYSIG' \
  'signature was created outside the authorized role validity window' \
  'signature creation time is unacceptably in the future'; do
  grep -Fq -- "$required_guard" "$verification_script" || \
    fail "signature validity guard is missing: $required_guard"
done
grep -Fq -- 'release signing key is no longer currently valid' \
  "${signing_dir}/validate-public-bundle.sh" || \
  fail 'public bundle validator does not reject expired release keys'

metadata_signing_script="${project_root}/tools/release/sign-repository-metadata.sh"
for required_guard in '--database-sha256' '--files-sha256'; do
  grep -Fq -- "$required_guard" "$metadata_signing_script" || \
    fail "repository metadata signing lacks an approved digest input: $required_guard"
done
for required_guard in \
  'repository metadata signing is already in progress' \
  'signature output appeared concurrently'; do
  grep -Fq -- "$required_guard" "$metadata_signing_script" || \
    fail "repository metadata concurrency guard is missing: $required_guard"
done

import_script="${signing_dir}/import-operational-subkeys.sh"
for required_guard in \
  'EUID != 0' \
  'acknowledge-restricted-host' \
  'operational secret export must be owned by the invoking signing user' \
  'signing GnuPG parent must be owned by the invoking signing user' \
  'gpgconf --homedir "$staged_home" --kill all' \
  'signing GnuPG home must remain outside the source repository' \
  'validate-signing-home.sh'; do
  grep -Fq -- "$required_guard" "$import_script" || \
    fail "operational signing-host import guard is missing: $required_guard"
done

bootstrap_script="${signing_dir}/bootstrap-pacman-trust.sh"
for required_guard in \
  'EUID == 0' \
  'acknowledge-initial-trust' \
  '--populate-from' \
  '--populate schweisos' \
  'another pacman trust bootstrap is already in progress' \
  'this command will not run pacman-key --init' \
  'Arch keyring source files changed'; do
  grep -Fq -- "$required_guard" "$bootstrap_script" || \
    fail "pacman trust bootstrap guard is missing: $required_guard"
done

grep -Fq -- 'supplied public bundle differs from the repository-admitted trust root' \
  "${signing_dir}/validate-admitted-public-bundle.sh" || \
  fail 'admitted public-bundle byte-comparison guard is missing'

repository_candidate_script="${project_root}/tools/release/create-repository-candidate.sh"
for required_guard in \
  '--baseline-dir' \
  '--initial-repository' \
  'candidate would remove baseline package' \
  'candidate would downgrade' \
  'without a version increment'; do
  grep -Fq -- "$required_guard" "$repository_candidate_script" || \
    fail "repository history guard is missing: $required_guard"
done

repository_validator="${project_root}/tools/release/validate-release-repository.sh"
for required_guard in \
  'SHA256SUM' \
  'CSIZE' \
  'PGPSIG does not match detached package signature' \
  'metadata regenerated from signed packages' \
  'group- or world-writable directory'; do
  grep -Fq -- "$required_guard" "$repository_validator" || \
    fail "repository binding guard is missing: $required_guard"
done

activation_script="${project_root}/tools/release/activate-build-repository.sh"
for required_guard in \
  'another repository activation is already in progress' \
  'target root contains a symlinked ancestor' \
  'activation would remove active package' \
  'activation would downgrade' \
  'without a version increment' \
  'must reside on the same filesystem'; do
  grep -Fq -- "$required_guard" "$activation_script" || \
    fail "repository activation guard is missing: $required_guard"
done

for policy_text in \
  'certification-only Ed25519 primary' \
  'Package signing subkey' \
  'Repository database signing subkey' \
  'LUKS2-encrypted' \
  'No temporary development key' \
  'No host pacman master key'; do
  grep -Fqi -- "$policy_text" "$policy" || fail "signing policy is missing: $policy_text"
done

private_material="$({
  find "$project_root" \
    \( -path "${project_root}/.git" \
      -o -path "${project_root}/cache" \
      -o -path "${project_root}/logs" \
      -o -path "${project_root}/out" \
      -o -path "${project_root}/release" \
      -o -path "${project_root}/work" \) -prune -o \
    -type f \
    \( -path '*/private-keys-v1.d/*' \
      -o -path '*/openpgp-revocs.d/*' \
      -o -name secring.gpg \
      -o -name '*.rev' \) -print -quit
})"
[[ -z "$private_material" ]] || fail "private signing material found: $private_material"

public_bundle="${project_root}/packages/schweisos-keyring/keys"
mapfile -t public_bundle_entries < <(
  find "$public_bundle" -mindepth 1 -maxdepth 1 -printf '%f\n' | sort
)
production_bundle_entries=(
  SHA256SUMS
  release-key-metadata.tsv
  schweisos-release.asc
  schweisos-revoked
  schweisos-trusted
  schweisos.gpg
)
if [[ "${public_bundle_entries[*]}" == README.md ]]; then
  keyring_state='offline ceremony pending; exact bootstrap sentinel present'
elif [[ "${public_bundle_entries[*]}" == "${production_bundle_entries[*]}" ]]; then
  "${signing_dir}/validate-public-bundle.sh" "$public_bundle"
  keyring_state='production public bundle present and valid'
else
  fail 'schweisos-keyring contains a forbidden partial public-bundle state'
fi

"${project_root}/tests/validate-keyring-package.sh"

git -C "$project_root" diff --check

printf 'SchweisOS signing tooling validation passed.\n'
printf '  keyring state: %s\n' "$keyring_state"
printf '  private material: absent\n'
printf '  signature policy: fail-closed and role-bound\n'
