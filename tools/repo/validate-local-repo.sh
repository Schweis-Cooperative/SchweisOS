#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_name="${SCHWEISOS_REPO_NAME:-schweisos}"
repo_arch="${SCHWEISOS_REPO_ARCH:-x86_64}"
repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"

usage() {
  cat <<'EOF'
Usage: validate-local-repo.sh [options]

Validate that pacman can recognize the local SchweisOS development repository.

Options:
  --repo-name NAME   Repository name. Default: schweisos
  --arch ARCH        Repository architecture. Default: x86_64
  --repo-root PATH   Repository root. Default: out/local-repo
  -h, --help         Show this help.
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

require_tool() {
  if ! command -v "$1" >/dev/null 2>&1; then
    printf 'Required tool not found: %s\n' "$1" >&2
    exit 1
  fi
}

require_tool pacman
require_tool pacman-conf
require_tool bsdtar

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
repo_db="${repo_dir}/${repo_name}.db"

if [[ ! -d "${repo_dir}" ]]; then
  printf 'Repository directory does not exist: %s\n' "${repo_dir}" >&2
  exit 1
fi

if [[ ! -e "${repo_db}" && ! -e "${repo_db}.tar.gz" ]]; then
  printf 'Repository database does not exist under: %s\n' "${repo_dir}" >&2
  exit 1
fi

repo_dir="$(cd -- "${repo_dir}" && pwd)"
tmpdir="$(mktemp -d)"
trap 'rm -rf -- "${tmpdir}"' EXIT

mkdir -p "${tmpdir}/root" "${tmpdir}/db" "${tmpdir}/cache"

pacman_config="${tmpdir}/pacman.conf"
cat > "${pacman_config}" <<EOF
[options]
RootDir = ${tmpdir}/root
DBPath = ${tmpdir}/db
CacheDir = ${tmpdir}/cache
LogFile = ${tmpdir}/pacman.log
Architecture = auto
SigLevel = Never

[${repo_name}]
Server = file://${repo_dir}
EOF

repo_list="$(pacman-conf -c "${pacman_config}" --repo-list)"
if [[ "${repo_list}" != "${repo_name}" ]]; then
  printf 'Unexpected pacman repository list:\n%s\n' "${repo_list}" >&2
  exit 1
fi

if [[ "${EUID}" -eq 0 ]]; then
  pacman_runner=(pacman)
elif command -v fakeroot >/dev/null 2>&1; then
  pacman_runner=(fakeroot pacman)
else
  printf 'fakeroot is not available; skipping pacman database sync.\n'
  printf 'Repository database entries:\n'
  bsdtar -tf "${repo_dir}/${repo_name}.db" | sed -n 's|/desc$||p' | sort
  exit 0
fi

"${pacman_runner[@]}" -Sy --config "${pacman_config}" --noconfirm
"${pacman_runner[@]}" -Sl --config "${pacman_config}" "${repo_name}"

printf '\nLocal repository validation passed:\n'
printf '  %s\n' "${repo_dir}"
