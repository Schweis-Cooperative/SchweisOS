#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_name="${SCHWEISOS_REPO_NAME:-schweisos}"
repo_arch="${SCHWEISOS_REPO_ARCH:-x86_64}"
repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"
build_packages=true

identity_packages=(
  schweisos-release
  schweisos-keyring
  schweisos-mirrorlist
  schweisos-pacman-config
)

usage() {
  cat <<'EOF'
Usage: publish-local-packages.sh [options]

Build and publish the SchweisOS identity packages into a local repo-add
development repository.

Options:
  --repo-name NAME     Repository name. Default: schweisos
  --arch ARCH          Repository architecture. Default: x86_64
  --repo-root PATH     Repository root. Default: out/local-repo
  --no-build           Publish existing package artifacts without running makepkg.
  -h, --help           Show this help.

Environment overrides:
  SCHWEISOS_REPO_NAME
  SCHWEISOS_REPO_ARCH
  SCHWEISOS_LOCAL_REPO_ROOT

Important:
  This is a local development workflow. It intentionally does not sign packages
  or repository databases.
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
    --no-build)
      build_packages=false
      shift
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

require_tool makepkg
require_tool repo-add

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

published_packages=()

for package_name in "${identity_packages[@]}"; do
  package_dir="${project_root}/packages/${package_name}"

  if [[ ! -f "${package_dir}/PKGBUILD" ]]; then
    printf 'Missing PKGBUILD for %s: %s\n' "${package_name}" "${package_dir}" >&2
    exit 1
  fi

  if [[ "${build_packages}" == true ]]; then
    printf 'Building %s\n' "${package_name}"
    (
      cd "${package_dir}"
      makepkg --force --nodeps --clean --noconfirm
    )
  fi

  mapfile -t package_artifacts < <(
    cd "${package_dir}"
    makepkg --packagelist | sed '/^$/d'
  )

  if [[ "${#package_artifacts[@]}" -eq 0 ]]; then
    printf 'No package artifact found for %s\n' "${package_name}" >&2
    exit 1
  fi

  for package_artifact in "${package_artifacts[@]}"; do
    if [[ ! -f "${package_artifact}" ]]; then
      printf 'Expected package artifact does not exist: %s\n' "${package_artifact}" >&2
      exit 1
    fi

    destination="${repo_dir}/$(basename -- "${package_artifact}")"
    cp -f -- "${package_artifact}" "${destination}"
    published_packages+=("${destination}")
  done
done

if [[ "${#published_packages[@]}" -eq 0 ]]; then
  printf 'No packages were published.\n' >&2
  exit 1
fi

repo_db="${repo_dir}/${repo_name}.db.tar.gz"
repo-add "${repo_db}" "${published_packages[@]}"

printf '\nPublished local repository:\n'
printf '  %s\n' "${repo_dir}"
printf '\nDeveloper pacman test snippet for this unsigned local repository:\n'
printf '[%s]\n' "${repo_name}"
printf 'SigLevel = Never\n'
printf 'Server = file://%s\n' "${repo_dir}"
