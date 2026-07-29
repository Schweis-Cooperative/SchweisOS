#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"
repo_arch="${SCHWEISOS_LOCAL_REPO_ARCH:-x86_64}"
database_name='schweisos'

expected_packages=(
  calamares
  schweisos-branding
  schweisos-calamares-config
  schweisos-keyring
  schweisos-mirrorlist
  schweisos-pacman-config
  schweisos-release
)

usage() {
  cat <<'EOF'
Usage: validate-local-repo.sh [options]

Validate the local-only bootstrap repository layout, package artifacts, and
repo-add database without configuring pacman or contacting a network service.

Options:
  --repo-root PATH   Repository root. Default: out/local-repo
  -h, --help         Show this help.

Environment override:
  SCHWEISOS_LOCAL_REPO_ARCH
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

require_tool() {
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required tool not found: %s\n' "$1" >&2
    exit 1
  }
}

for tool in awk bsdtar cmp find git grep mktemp sed sort; do
  require_tool "${tool}"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(git -C "${script_dir}" rev-parse --show-toplevel)"

case "${repo_root}" in
  /*) repo_base="${repo_root}" ;;
  *) repo_base="${project_root}/${repo_root}" ;;
esac

package_store="${repo_base}/packages"
database_dir="${repo_base}/${database_name}/os/${repo_arch}"
repository_database="${database_dir}/${database_name}.db"

unexpected_entry="$(
  find "${repo_base}" -mindepth 1 -maxdepth 1 \
    ! -name README.md ! -name packages ! -name "${database_name}" -print -quit 2>/dev/null || true
)"
[[ -z "${unexpected_entry}" ]] || {
  printf 'Unexpected local repository entry: %s\n' "${unexpected_entry}" >&2
  exit 1
}

[[ -d "${package_store}" ]] || {
  printf 'Local package directory is missing: %s\n' "${package_store}" >&2
  printf 'Run tools/repo/bootstrap-local-repo.sh first.\n' >&2
  exit 1
}

[[ -d "${database_dir}" ]] || {
  printf 'Local database directory is missing: %s\n' "${database_dir}" >&2
  printf 'Run tools/repo/bootstrap-local-repo.sh first.\n' >&2
  exit 1
}

[[ -f "${repo_base}/README.md" ]] || {
  printf 'Local repository ownership README is missing: %s/README.md\n' "${repo_base}" >&2
  exit 1
}

cmp -s "${script_dir}/local-repo.README.md" "${repo_base}/README.md" || {
  printf 'Local repository README does not match the canonical template.\n' >&2
  exit 1
}

if grep -RIEq --exclude='validate-local-repo.sh' \
  'https?://|^[[:space:]]*Server[[:space:]]*=' "${script_dir}"; then
  printf 'Local repository tooling contains a network endpoint.\n' >&2
  exit 1
fi

if grep -RIEq --exclude='validate-local-repo.sh' \
  'SigLevel[[:space:]]*=[[:space:]]*Never|TrustAll' "${script_dir}"; then
  printf 'Local repository tooling contains a weakened repository policy.\n' >&2
  exit 1
fi

if grep -RIEiq \
  --exclude='validate-local-repo.sh' \
  'BEGIN (PGP |OPENSSH |RSA |EC )?(PUBLIC|PRIVATE) KEY|(^|[^A-Za-z])(PASSWORD|TOKEN|SECRET)[[:space:]]*=' \
  "${script_dir}"; then
  printf 'Local repository tooling contains embedded key material or a secret.\n' >&2
  exit 1
fi

[[ -e "${repository_database}" ]] || {
  printf 'Local repo-add database is missing: %s\n' "${repository_database}" >&2
  printf 'Run tools/repo/publish-local-packages.sh before validation.\n' >&2
  exit 1
}

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "${tmp_dir}"' EXIT

while IFS= read -r descriptor; do
  bsdtar -xOf "${repository_database}" "${descriptor}" | awk '
    $0 == "%NAME%" { getline; print >> names }
    $0 == "%FILENAME%" { getline; print >> filenames }
  ' names="${tmp_dir}/names" filenames="${tmp_dir}/filenames"
done < <(bsdtar -tf "${repository_database}" | sed -n '/\/desc$/p')

sort -u "${tmp_dir}/names" > "${tmp_dir}/names.sorted"
printf '%s\n' "${expected_packages[@]}" | sort > "${tmp_dir}/expected.sorted"

cmp -s "${tmp_dir}/expected.sorted" "${tmp_dir}/names.sorted" || {
  printf 'Local repository package set is incomplete or unexpected.\n' >&2
  printf 'Expected:\n' >&2
  sed 's/^/  /' "${tmp_dir}/expected.sorted" >&2
  printf 'Found:\n' >&2
  sed 's/^/  /' "${tmp_dir}/names.sorted" >&2
  exit 1
}

while IFS= read -r package_filename; do
  [[ -f "${database_dir}/${package_filename}" ]] || {
    printf 'Repository database references a missing package: %s\n' \
      "${database_dir}/${package_filename}" >&2
    exit 1
  }
done < "${tmp_dir}/filenames"

if find "${repo_base}" -type f \
  \( -name '*.sig' -o -name '*.asc' -o -name '*.gpg' -o -name '*.key' -o -name '*.pem' \) \
  -print -quit | grep -q .; then
  printf 'Unexpected signing material found in the unsigned local repository.\n' >&2
  exit 1
fi

if grep -RIEq 'https?://|^[[:space:]]*Server[[:space:]]*=' \
  "${repo_base}/README.md"; then
  printf 'Local repository metadata contains an endpoint URL.\n' >&2
  exit 1
fi

printf 'Local bootstrap repository validation passed:\n'
printf '  root: %s\n' "${repo_base}"
printf '  database: %s\n' "${repository_database}"
printf '  packages: %s\n' "${expected_packages[*]}"
