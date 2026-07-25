#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

require_tool() {
  command -v "$1" >/dev/null 2>&1 || fail "required tool not found: $1"
}

for tool in awk bash bsdtar comm find git grep makepkg mktemp pacman-conf sed sort; do
  require_tool "${tool}"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
mirror_dir="${project_root}/packages/schweisos-mirrorlist"
pacman_dir="${project_root}/packages/schweisos-pacman-config"
mirror_file="${mirror_dir}/schweisos-mirrorlist"
pacman_file="${pacman_dir}/schweisos.conf"

for required_file in \
  "${mirror_dir}/PKGBUILD" \
  "${mirror_dir}/README.md" \
  "${mirror_file}" \
  "${pacman_dir}/PKGBUILD" \
  "${pacman_dir}/README.md" \
  "${pacman_file}"; do
  [[ -f "${required_file}" ]] || fail "missing required file: ${required_file}"
done

bash -n \
  "${mirror_dir}/PKGBUILD" \
  "${pacman_dir}/PKGBUILD" \
  "${BASH_SOURCE[0]}"

expected_development_endpoint='Server = file:///var/lib/schweisos/local-repo/$repo/os/$arch'
mapfile -t active_servers < <(
  sed -n 's/^[[:space:]]*\(Server[[:space:]]*=[[:space:]]*.*\)$/\1/p' \
    "${mirror_file}"
)
[[ "${#active_servers[@]}" -eq 1 ]] || \
  fail 'bootstrap mirrorlist must contain exactly one active Server entry'
[[ "${active_servers[0]}" == "${expected_development_endpoint}" ]] || \
  fail 'bootstrap mirrorlist must use the canonical local development endpoint'

if grep -Eq 'https?://' "${mirror_file}"; then
  fail 'bootstrap mirrorlist must not contain a network endpoint URL'
fi

if grep -Evq '^[[:space:]]*($|#|Server[[:space:]]*=[[:space:]]*file:///var/lib/schweisos/local-repo/\$repo/os/\$arch[[:space:]]*$)' \
    "${mirror_file}"; then
  fail 'bootstrap mirrorlist contains unsupported active content'
fi

if grep -Eq '^[[:space:]]*Server[[:space:]]*=' "${pacman_file}"; then
  fail 'repository endpoints belong in schweisos-mirrorlist, not pacman-config'
fi

if grep -Eq '^[[:space:]]*\[(core|extra|multilib)\]' \
  "${mirror_file}" "${pacman_file}"; then
  fail 'Arch repository definitions must remain upstream-owned'
fi

if grep -Eq '(Never|Optional|TrustAll)' \
  <(sed 's/[[:space:]]*#.*$//' "${pacman_file}"); then
  fail 'pacman snippet contains a weakened signature policy'
fi

[[ "$(grep -Ec '^[[:space:]]*SigLevel[[:space:]]*=[[:space:]]*Required[[:space:]]+TrustedOnly[[:space:]]*$' "${pacman_file}")" -eq 1 ]] || \
  fail 'pacman snippet must set exactly one Required TrustedOnly policy'

[[ "$(grep -Ec '^[[:space:]]*Include[[:space:]]*=[[:space:]]*/etc/pacman\.d/schweisos-mirrorlist[[:space:]]*$' "${pacman_file}")" -eq 1 ]] || \
  fail 'pacman snippet must include the SchweisOS-owned mirrorlist exactly once'

mapfile -t repository_sections < <(
  sed -n 's/^[[:space:]]*\[\([^]]*\)\][[:space:]]*$/\1/p' "${pacman_file}"
)

[[ "${#repository_sections[@]}" -eq 1 && "${repository_sections[0]}" == 'schweisos' ]] || \
  fail 'pacman snippet must define only one [schweisos] repository'

if [[ "$(printf '%s\n' "${repository_sections[@]}" | sort | uniq -d)" != '' ]]; then
  fail 'duplicate repository definitions found'
fi

if find "${mirror_dir}" "${pacman_dir}" -type f \
  \( -name '*.asc' -o -name '*.gpg' -o -name '*.key' -o -name '*.pem' -o -name '*.sig' \) \
  -print -quit | grep -q .; then
  fail 'embedded signing or key material found'
fi

if grep -RIEiq \
  --exclude='*.pkg.tar.*' \
  'BEGIN (PGP |OPENSSH |RSA |EC )?(PUBLIC|PRIVATE) KEY|(^|[^A-Za-z])(PASSWORD|TOKEN|SECRET)[[:space:]]*=' \
  "${mirror_dir}" "${pacman_dir}"; then
  fail 'embedded key block or hardcoded secret found'
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf -- "${tmp_dir}"' EXIT
mkdir -p \
  "${tmp_dir}/artifacts" \
  "${tmp_dir}/build" \
  "${tmp_dir}/sources"

build_package() {
  local package_dir="$1"
  local package_name="${package_dir##*/}"

  mkdir -p \
    "${tmp_dir}/build/${package_name}" \
    "${tmp_dir}/sources/${package_name}"

  (
    cd "${package_dir}"
    BUILDDIR="${tmp_dir}/build/${package_name}" \
    SRCDEST="${tmp_dir}/sources/${package_name}" \
    PKGDEST="${tmp_dir}/artifacts" \
      makepkg --nodeps --cleanbuild --clean --force --noconfirm
  )
}

build_package "${mirror_dir}"
build_package "${pacman_dir}"

shopt -s nullglob
mirror_packages=("${tmp_dir}/artifacts"/schweisos-mirrorlist-*.pkg.tar.*)
pacman_packages=("${tmp_dir}/artifacts"/schweisos-pacman-config-*.pkg.tar.*)
shopt -u nullglob

[[ "${#mirror_packages[@]}" -eq 1 ]] || fail 'expected one mirrorlist package artifact'
[[ "${#pacman_packages[@]}" -eq 1 ]] || fail 'expected one pacman-config package artifact'

payload_files() {
  bsdtar -tf "$1" | sed \
    -e '/^\.BUILDINFO$/d' \
    -e '/^\.MTREE$/d' \
    -e '/^\.PKGINFO$/d' \
    -e '/^\.INSTALL$/d' \
    -e '/\/$/d' | sort -u
}

payload_files "${mirror_packages[0]}" > "${tmp_dir}/mirror.payload"
payload_files "${pacman_packages[0]}" > "${tmp_dir}/pacman.payload"

[[ "$(<"${tmp_dir}/mirror.payload")" == 'etc/pacman.d/schweisos-mirrorlist' ]] || \
  fail 'mirrorlist package owns files outside its mirror configuration boundary'

[[ "$(<"${tmp_dir}/pacman.payload")" == 'etc/pacman.d/schweisos.conf' ]] || \
  fail 'pacman-config package owns files outside its snippet boundary'

[[ -z "$(comm -12 "${tmp_dir}/mirror.payload" "${tmp_dir}/pacman.payload")" ]] || \
  fail 'package payload ownership overlaps'

if bsdtar -tf "${mirror_packages[0]}" | grep -qx '.INSTALL' || \
  bsdtar -tf "${pacman_packages[0]}" | grep -qx '.INSTALL'; then
  fail 'bootstrap packages must not contain install scripts'
fi

mkdir -p "${tmp_dir}/pacman.d"
cp "${mirror_file}" "${tmp_dir}/pacman.d/schweisos-mirrorlist"
sed "s|/etc/pacman.d/schweisos-mirrorlist|${tmp_dir}/pacman.d/schweisos-mirrorlist|" \
  "${pacman_file}" > "${tmp_dir}/pacman.d/schweisos.conf"

{
  printf '[options]\n'
  printf 'Architecture = auto\n'
  printf 'SigLevel = Required TrustedOnly\n'
  printf 'Include = %s\n' "${tmp_dir}/pacman.d/schweisos.conf"
} > "${tmp_dir}/pacman.conf"

[[ "$(pacman-conf -c "${tmp_dir}/pacman.conf" --repo-list)" == 'schweisos' ]] || \
  fail 'pacman-conf did not recognize exactly the [schweisos] repository'

mapfile -t parsed_servers < <(
  pacman-conf -c "${tmp_dir}/pacman.conf" --repo schweisos Server
)

[[ "${#parsed_servers[@]}" -eq 1 \
  && "${parsed_servers[0]}" == 'file:///var/lib/schweisos/local-repo/schweisos/os/x86_64' ]] || \
  fail 'pacman-conf did not resolve the canonical local development endpoint'

mapfile -t parsed_siglevel < <(
  pacman-conf -c "${tmp_dir}/pacman.conf" --repo schweisos SigLevel
)

[[ " ${parsed_siglevel[*]} " == *' PackageRequired '* ]] || \
  fail 'pacman-conf did not require package signatures'
[[ " ${parsed_siglevel[*]} " == *' DatabaseRequired '* ]] || \
  fail 'pacman-conf did not require repository database signatures'
[[ " ${parsed_siglevel[*]} " == *' PackageTrustedOnly '* ]] || \
  fail 'pacman-conf did not require trusted package signing keys'
[[ " ${parsed_siglevel[*]} " == *' DatabaseTrustedOnly '* ]] || \
  fail 'pacman-conf did not require trusted database signing keys'

git -C "${project_root}" diff --check

printf 'Repository Bootstrap Sprint A validation passed.\n'
printf '  mirrorlist payload: %s\n' "$(<"${tmp_dir}/mirror.payload")"
printf '  pacman-config payload: %s\n' "$(<"${tmp_dir}/pacman.payload")"
printf '  repository: schweisos (local development endpoint)\n'
printf '  signature policy: Required TrustedOnly\n'
