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
  "${signing_dir}/create-offline-release-key.sh"
  "${signing_dir}/export-operational-subkeys.sh"
  "${signing_dir}/sign-artifact.sh"
  "${signing_dir}/validate-public-bundle.sh"
  "$policy"
  "$admission_policy"
)
for required_file in "${required_files[@]}"; do
  [[ -f "$required_file" && ! -L "$required_file" ]] || \
    fail "missing or unsafe signing infrastructure file: $required_file"
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
  "${signing_dir}/create-offline-release-key.sh" \
  "${signing_dir}/export-operational-subkeys.sh" \
  "${signing_dir}/sign-artifact.sh" \
  "${signing_dir}/validate-public-bundle.sh" \
  "${BASH_SOURCE[0]}"

for executable in \
  "${signing_dir}/create-offline-release-key.sh" \
  "${signing_dir}/export-operational-subkeys.sh" \
  "${signing_dir}/sign-artifact.sh" \
  "${signing_dir}/validate-public-bundle.sh" \
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
  'acknowledge-airgapped' \
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
  'acknowledge-encrypted-media' \
  'require_luks_backing' \
  'outside the source repository' \
  '--export-secret-subkeys'; do
  grep -Fq -- "$required_guard" "$subkey_export_script" || \
    fail "operational subkey export guard is missing: $required_guard"
done

sign_script="${signing_dir}/sign-artifact.sh"
grep -Fq -- '--local-user "${signing_fingerprint}!"' "$sign_script" || \
  fail 'signing entry point does not select the exact role subkey'
grep -Fq -- 'signature output already exists' "$sign_script" || \
  fail 'signing entry point does not fail closed on duplicate output'
grep -Fq -- 'gpgv --status-fd 1' "$sign_script" || \
  fail 'signing entry point does not immediately verify its output'

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
if [[ -f "${public_bundle}/schweisos.gpg" ]]; then
  "${signing_dir}/validate-public-bundle.sh" "$public_bundle"
  keyring_state='production public bundle present and valid'
else
  keyring_state='offline ceremony pending; no production public bundle admitted'
fi

git -C "$project_root" diff --check

printf 'SchweisOS signing tooling validation passed.\n'
printf '  keyring state: %s\n' "$keyring_state"
printf '  private material: absent\n'
printf '  signature policy: fail-closed and role-bound\n'
