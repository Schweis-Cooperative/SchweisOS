#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_name="${SCHWEISOS_REPO_NAME:-schweisos}"
repo_arch="${SCHWEISOS_REPO_ARCH:-x86_64}"
repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"

usage() {
  cat <<'EOF'
Usage: bootstrap-local-repo.sh [options]

Create the local SchweisOS development repository directory.

Options:
  --repo-name NAME   Repository name. Default: schweisos
  --arch ARCH        Repository architecture. Default: x86_64
  --repo-root PATH   Repository root. Default: out/local-repo
  -h, --help         Show this help.

Environment overrides:
  SCHWEISOS_REPO_NAME
  SCHWEISOS_REPO_ARCH
  SCHWEISOS_LOCAL_REPO_ROOT
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-name)
      repo_name="$2"
      shift 2
      ;;
    --arch)
      repo_arch="$2"
      shift 2
      ;;
    --repo-root)
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

project_root="$(git rev-parse --show-toplevel 2>/dev/null || true)"
if [[ -z "${project_root}" ]]; then
  script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
  project_root="$(cd -- "${script_dir}/../.." && pwd)"
fi

case "${repo_root}" in
  /*) repo_base="${repo_root}" ;;
  *) repo_base="${project_root}/${repo_root}" ;;
esac

repo_dir="${repo_base}/${repo_arch}/${repo_name}"

mkdir -p "${repo_dir}"

printf 'Local SchweisOS repository directory ready:\n'
printf '  %s\n' "${repo_dir}"
printf '\nExpected database path after publication:\n'
printf '  %s/%s.db.tar.gz\n' "${repo_dir}" "${repo_name}"
