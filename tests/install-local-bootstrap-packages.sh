#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"
repo_arch="${SCHWEISOS_LOCAL_REPO_ARCH:-x86_64}"
database_name='schweisos'

expected_packages=(
  schweisos-keyring
  schweisos-mirrorlist
  schweisos-pacman-config
  schweisos-release
)

usage() {
  cat <<'EOF'
Usage: install-local-bootstrap-packages.sh [options]

Install the four locally published bootstrap package files together inside a
disposable pacman root.

Options:
  --repo-root PATH   Repository root. Default: out/local-repo
  -h, --help         Show this help.

Environment override:
  SCHWEISOS_LOCAL_REPO_ARCH

The test never edits host pacman configuration or keyrings and never installs
to /. It does not claim to validate the future signed repository trust path.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || { printf 'Missing value for --repo-root\n' >&2; exit 2; }
      repo_root="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'Unknown option: %s\n' "$1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

for tool in awk bsdtar cmp git mktemp pacman pacman-conf sed sort; do
  require_tool "${tool}"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(git -C "${script_dir}" rev-parse --show-toplevel)"

case "${repo_root}" in
  /*) repo_base="${repo_root}" ;;
  *) repo_base="${project_root}/${repo_root}" ;;
esac

database_dir="${repo_base}/${database_name}/os/${repo_arch}"
repository_database="${database_dir}/${database_name}.db"

[[ -e "${repository_database}" ]] || {
  printf 'ERROR: local repository publication is missing: %s\n' \
    "${repository_database}" >&2
  printf 'Run tools/repo/publish-local-packages.sh before this test.\n' >&2
  exit 1
}

"${project_root}/tools/repo/validate-local-repo.sh" --repo-root "${repo_base}"

package_artifacts=()
while IFS= read -r descriptor; do
  package_filename="$(
    bsdtar -xOf "${repository_database}" "${descriptor}" | awk '
      $0 == "%FILENAME%" { getline; print; exit }
    '
  )"
  [[ -n "${package_filename}" ]] || fail "missing FILENAME in ${descriptor}"
  [[ -f "${database_dir}/${package_filename}" ]] || \
    fail "published package is missing: ${database_dir}/${package_filename}"
  package_artifacts+=("${database_dir}/${package_filename}")
done < <(bsdtar -tf "${repository_database}" | sed -n '/\/desc$/p')

[[ "${#package_artifacts[@]}" -eq 4 ]] || \
  fail "expected four published package artifacts, found ${#package_artifacts[@]}"

tmp_dir="$(mktemp -d)"
case "${tmp_dir}" in
  /tmp/*) ;;
  *) fail "refusing non-/tmp disposable root: ${tmp_dir}" ;;
esac
trap 'rm -rf -- "${tmp_dir}"' EXIT

root_dir="${tmp_dir}/root"
db_dir="${tmp_dir}/db"
cache_dir="${tmp_dir}/cache"
gpg_dir="${tmp_dir}/gnupg"
hook_dir="${tmp_dir}/hooks"
log_file="${tmp_dir}/pacman.log"
pacman_config="${tmp_dir}/pacman.conf"

[[ "${root_dir}" != '/' ]] || fail 'refusing to use / as the pacman root'
mkdir -p \
  "${root_dir}" \
  "${db_dir}/local" \
  "${cache_dir}" \
  "${gpg_dir}" \
  "${hook_dir}"

{
  printf '[options]\n'
  printf 'RootDir = %s\n' "${root_dir}"
  printf 'DBPath = %s\n' "${db_dir}"
  printf 'CacheDir = %s\n' "${cache_dir}"
  printf 'GPGDir = %s\n' "${gpg_dir}"
  printf 'HookDir = %s\n' "${hook_dir}"
  printf 'LogFile = %s\n' "${log_file}"
  printf 'Architecture = auto\n'
  printf 'SigLevel = Required TrustedOnly\n'
  printf 'LocalFileSigLevel = Optional\n'
} > "${pacman_config}"

if [[ "${EUID}" -eq 0 ]]; then
  pacman_runner=(pacman)
else
  require_tool fakeroot
  pacman_runner=(fakeroot pacman)
fi

"${pacman_runner[@]}" \
  --config "${pacman_config}" \
  --noconfirm \
  --assume-installed filesystem=1 \
  --assume-installed pacman=1 \
  -U "${package_artifacts[@]}"

pacman --config "${pacman_config}" -Qq | sort > "${tmp_dir}/installed.sorted"
printf '%s\n' "${expected_packages[@]}" | sort > "${tmp_dir}/expected.sorted"

cmp -s "${tmp_dir}/expected.sorted" "${tmp_dir}/installed.sorted" || {
  printf 'ERROR: disposable pacman root contains an unexpected package set.\n' >&2
  printf 'Expected:\n' >&2
  sed 's/^/  /' "${tmp_dir}/expected.sorted" >&2
  printf 'Installed:\n' >&2
  sed 's/^/  /' "${tmp_dir}/installed.sorted" >&2
  exit 1
}

expected_payload=(
  usr/lib/schweisos-release/os-release
  usr/lib/schweisos-release/release.json
  usr/share/doc/schweisos-keyring/future-keys.md
  usr/share/doc/schweisos-keyring/keyring-policy.md
  usr/share/pacman/keyrings
  etc/pacman.d/schweisos-mirrorlist
  etc/pacman.d/schweisos.conf
)

for payload_path in "${expected_payload[@]}"; do
  [[ -e "${root_dir}/${payload_path}" ]] || \
    fail "expected installed payload is missing: ${payload_path}"
done

{
  printf '[options]\n'
  printf 'Architecture = auto\n'
  printf 'SigLevel = Required TrustedOnly\n'
  printf 'Include = /etc/pacman.d/schweisos.conf\n'
} > "${root_dir}/etc/pacman.conf"

mapfile -t parsed_repositories < <(
  pacman-conf --sysroot "${root_dir}" --config /etc/pacman.conf --repo-list
)
[[ "${parsed_repositories[*]}" == 'schweisos' ]] || \
  fail "installed pacman snippet did not define exactly [schweisos]"

mapfile -t parsed_siglevel < <(
  pacman-conf --sysroot "${root_dir}" --config /etc/pacman.conf --repo schweisos SigLevel
)
parsed_siglevel_text=" ${parsed_siglevel[*]} "
for required_policy in PackageRequired PackageTrustedOnly DatabaseRequired DatabaseTrustedOnly; do
  [[ "${parsed_siglevel_text}" == *" ${required_policy} "* ]] || \
    fail "installed SchweisOS repository policy is missing ${required_policy}"
done
if [[ "${parsed_siglevel_text}" == *' Never '* \
  || "${parsed_siglevel_text}" == *' TrustAll '* ]]; then
  fail 'installed SchweisOS repository policy weakens signature verification'
fi

mapfile -t parsed_servers < <(
  pacman-conf --sysroot "${root_dir}" --config /etc/pacman.conf --repo schweisos Server
)
expected_server="file://${root_dir}/var/lib/schweisos/local-repo/schweisos/os/x86_64"
[[ "${#parsed_servers[@]}" -eq 1 \
  && "${parsed_servers[0]}" == "${expected_server}" ]] || \
  fail 'installed SchweisOS repository endpoint did not resolve as expected'

printf 'Disposable bootstrap package installation passed.\n'
printf '  root: %s (removed automatically)\n' "${root_dir}"
printf '  packages: %s\n' "${expected_packages[*]}"
printf '  repository endpoint: %s\n' "${parsed_servers[0]}"
printf '  host pacman configuration and keyrings were not used.\n'
printf '  signed repository installation remains a future release gate.\n'
