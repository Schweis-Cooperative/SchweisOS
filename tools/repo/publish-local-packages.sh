#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

repo_root="${SCHWEISOS_LOCAL_REPO_ROOT:-out/local-repo}"
build_packages=true
database_name='local-bootstrap'

identity_packages=(
  schweisos-release
  schweisos-keyring
  schweisos-mirrorlist
  schweisos-pacman-config
)

usage() {
  cat <<'EOF'
Usage: publish-local-packages.sh [options]

Build and add the SchweisOS identity packages to the local-only bootstrap
repository database.

Options:
  --repo-root PATH   Repository root. Default: out/local-repo
  --no-build         Use existing artifacts in the packages directory.
  -h, --help         Show this help.

Environment override:
  SCHWEISOS_LOCAL_REPO_ROOT

This workflow does not sign or publish artifacts and must not be used as a
production repository workflow.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo-root)
      [[ $# -ge 2 ]] || { printf 'Missing value for --repo-root\n' >&2; exit 2; }
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
  command -v "$1" >/dev/null 2>&1 || {
    printf 'Required tool not found: %s\n' "$1" >&2
    exit 1
  }
}

for tool in cp git makepkg mktemp repo-add; do
  require_tool "${tool}"
done

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(git -C "${script_dir}" rev-parse --show-toplevel)"

case "${repo_root}" in
  /*) repo_base="${repo_root}" ;;
  *) repo_base="${project_root}/${repo_root}" ;;
esac

"${script_dir}/bootstrap-local-repo.sh" --repo-root "${repo_base}"

package_store="${repo_base}/packages"
database_dir="${repo_base}/database"
build_root="$(mktemp -d)"
trap 'rm -rf -- "${build_root}"' EXIT

published_packages=()

for package_name in "${identity_packages[@]}"; do
  package_dir="${project_root}/packages/${package_name}"

  [[ -f "${package_dir}/PKGBUILD" ]] || {
    printf 'Missing PKGBUILD for %s: %s\n' "${package_name}" "${package_dir}" >&2
    exit 1
  }

  if [[ "${build_packages}" == true ]]; then
    printf 'Building local artifact: %s\n' "${package_name}"
    mkdir -p \
      "${build_root}/build/${package_name}" \
      "${build_root}/sources/${package_name}"

    (
      cd "${package_dir}"
      BUILDDIR="${build_root}/build/${package_name}" \
      SRCDEST="${build_root}/sources/${package_name}" \
      PKGDEST="${package_store}" \
        makepkg --force --nodeps --cleanbuild --clean --noconfirm
    )
  fi

  mapfile -t package_artifacts < <(
    cd "${package_dir}"
    PKGDEST="${package_store}" makepkg --packagelist | sed '/^$/d'
  )

  [[ "${#package_artifacts[@]}" -gt 0 ]] || {
    printf 'No package artifact declared for %s\n' "${package_name}" >&2
    exit 1
  }

  for package_artifact in "${package_artifacts[@]}"; do
    [[ -f "${package_artifact}" ]] || {
      printf 'Expected local artifact is missing: %s\n' "${package_artifact}" >&2
      printf 'Run without --no-build to create it.\n' >&2
      exit 1
    }

    destination="${database_dir}/$(basename -- "${package_artifact}")"
    cp -f -- "${package_artifact}" "${destination}"
    published_packages+=("${destination}")
  done
done

[[ "${#published_packages[@]}" -gt 0 ]] || {
  printf 'No local packages were selected for repo-add.\n' >&2
  exit 1
}

repository_database="${database_dir}/${database_name}.db.tar.gz"
repo-add -R "${repository_database}" "${published_packages[@]}"

printf '\nLocal bootstrap repository created:\n'
printf '  packages: %s\n' "${package_store}"
printf '  database: %s\n' "${repository_database}"
printf '\nThis output is unsigned, local-only, and not publishable.\n'
