#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"
repo_name='schweisos'
repo_arch="${SCHWEISOS_LOCAL_REPO_ARCH:-x86_64}"

usage() {
  cat <<'EOF'
Usage: bootstrap-local-repo.sh [options]

Create the local-only SchweisOS repository bootstrap layout.

Options:
  --repo-root PATH   Repository root. Default: out/local-repo
  -h, --help         Show this help.

Environment override:
  SCHWEISOS_LOCAL_REPO_ROOT
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

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(git -C "${script_dir}" rev-parse --show-toplevel)"

case "${repo_name}" in
  *[!a-z0-9._-]*|'')
    printf 'Invalid repository name: %s\n' "${repo_name}" >&2
    exit 1
    ;;
esac

case "${repo_arch}" in
  *[!A-Za-z0-9._-]*|'')
    printf 'Invalid repository architecture: %s\n' "${repo_arch}" >&2
    exit 1
    ;;
esac

case "${repo_root}" in
  /*) repo_base="${repo_root}" ;;
  *) repo_base="${project_root}/${repo_root}" ;;
esac

if [[ -d "${repo_base}" ]]; then
  unexpected_entry="$(
    find "${repo_base}" -mindepth 1 -maxdepth 1 \
      ! -name README.md ! -name packages ! -name "${repo_name}" -print -quit
  )"
  if [[ -n "${unexpected_entry}" ]]; then
    printf 'Refusing mixed local repository layouts. Unexpected entry: %s\n' \
      "${unexpected_entry}" >&2
    printf 'Move or remove the legacy local output before continuing.\n' >&2
    exit 1
  fi
fi

repository_dir="${repo_base}/${repo_name}/os/${repo_arch}"

mkdir -p "${repo_base}/packages" "${repository_dir}"
install -Dm644 "${script_dir}/local-repo.README.md" "${repo_base}/README.md"

printf 'Local bootstrap repository layout ready:\n'
printf '  root:     %s\n' "${repo_base}"
printf '  packages: %s/packages\n' "${repo_base}"
printf '  database: %s\n' "${repository_dir}"
