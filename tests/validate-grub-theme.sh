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

for tool in awk bash file find git grep makepkg readlink sha256sum stat; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
package_dir="${project_root}/packages/schweisos-grub-theme"
branding_package_dir="${project_root}/packages/schweisos-branding"
canonical_logo="${project_root}/branding/assets/logo/schweisos.png"
legacy_logo="${project_root}/branding/assets/logo/schweisos-logo.png"
branding_source="${branding_package_dir}/schweisos.png"
branding_legacy_source="${branding_package_dir}/schweisos-logo.png"
theme_file="${package_dir}/theme.txt"
profile_packages="${project_root}/iso/profiles/kde/packages.x86_64"

required_files=(
  "${package_dir}/PKGBUILD"
  "${package_dir}/README.md"
  "${package_dir}/selection.svg"
  "$theme_file"
  "$canonical_logo"
  "$profile_packages"
)

for required_file in "${required_files[@]}"; do
  [[ -f "$required_file" ]] || fail "missing GRUB theme input: ${required_file}"
done

bash -n "${package_dir}/PKGBUILD" "${BASH_SOURCE[0]}"

[[ -L "$legacy_logo" ]] || fail 'legacy canonical-logo path must be a symlink'
[[ "$(readlink -- "$legacy_logo")" == schweisos.png ]] || \
  fail 'legacy canonical-logo symlink has an unexpected target'
[[ "$(readlink -f -- "$legacy_logo")" == "$(readlink -f -- "$canonical_logo")" ]] || \
  fail 'legacy canonical-logo symlink does not resolve to the canonical logo'

[[ -L "$branding_source" ]] || fail 'branding package logo source must be a symlink'
[[ "$(readlink -- "$branding_source")" == ../../branding/assets/logo/schweisos.png ]] || \
  fail 'branding package source does not target the canonical logo'
[[ "$(readlink -f -- "$branding_source")" == "$(readlink -f -- "$canonical_logo")" ]] || \
  fail 'branding package source does not resolve to the canonical logo'

[[ -L "$branding_legacy_source" ]] || \
  fail 'legacy branding package logo source must be a symlink'
[[ "$(readlink -- "$branding_legacy_source")" == ../../branding/assets/logo/schweisos.png ]] || \
  fail 'legacy branding package source does not target the canonical logo'
[[ "$(readlink -f -- "$branding_legacy_source")" == "$(readlink -f -- "$canonical_logo")" ]] || \
  fail 'legacy branding package source does not resolve to the canonical logo'

canonical_hash="$(sha256sum -- "$canonical_logo" | awk '{ print $1 }')"
matching_logo_files=0
while IFS= read -r image_file; do
  image_hash="$(sha256sum -- "$image_file" | awk '{ print $1 }')"
  if [[ "$image_hash" == "$canonical_hash" ]]; then
    ((matching_logo_files += 1))
  fi
done < <(find "${project_root}/branding" "${project_root}/packages" \
  "${project_root}/iso" -type f -name '*.png' -print)
(( matching_logo_files == 1 )) || \
  fail "canonical logo content must exist as exactly one regular repository file (found ${matching_logo_files})"

srcinfo="$(cd -- "$package_dir" && makepkg --printsrcinfo)"
grep -Fxq 'pkgname = schweisos-grub-theme' <<<"$srcinfo" || \
  fail 'unexpected GRUB theme package name'
grep -Fxq $'\tarch = any' <<<"$srcinfo" || fail 'GRUB theme package must be architecture independent'
grep -Fxq $'\turl = https://schweisos.org' <<<"$srcinfo" || \
  fail 'GRUB theme package URL is not canonical'
grep -Fxq $'\tdepends = grub' <<<"$srcinfo" || fail 'GRUB theme package must depend on upstream grub'
grep -Fxq $'\tdepends = schweisos-branding' <<<"$srcinfo" || \
  fail 'GRUB theme package must consume schweisos-branding'

grep -Fq "ln -s ../../../schweisos/branding/schweisos.png" \
  "${package_dir}/PKGBUILD" || \
  fail 'GRUB theme package must link to the schweisos-branding runtime payload'
! grep -Eq '(^|[[:space:]])(grub-install|grub-mkconfig)([[:space:]]|$)' \
  "${package_dir}/PKGBUILD" || \
  fail 'GRUB theme package must not install or configure GRUB'
! grep -Eq '^[[:space:]]*install=' "${package_dir}/PKGBUILD" || \
  fail 'GRUB theme package must not have an install hook'
! grep -Fq "'SKIP'" "${package_dir}/PKGBUILD" || \
  fail 'GRUB theme source checksums must not be skipped'
! grep -Eq 'schweisos(-logo)?\\.png' <<<"$srcinfo" || \
  fail 'GRUB theme package must not embed a logo source'

grep -Fq 'desktop-color: "#061123"' "$theme_file" || \
  fail 'GRUB theme does not use the documented SchweisOS background'
grep -Fq 'file = "schweisos.png"' "$theme_file" || \
  fail 'GRUB theme does not consume its canonical runtime logo alias'
grep -Fq '+ boot_menu {' "$theme_file" || fail 'GRUB theme has no boot menu'
grep -Fq 'selected_item_pixmap_style = "select_*.png"' "$theme_file" || \
  fail 'GRUB theme has no selected-entry highlight'
grep -Fq '+ progress_bar {' "$theme_file" || fail 'GRUB theme has no timeout indicator'
grep -Fq 'id = "__timeout__"' "$theme_file" || \
  fail 'GRUB timeout indicator does not use the upstream reserved id'

selection_slices=(c e n ne nw s se sw w)
for slice in "${selection_slices[@]}"; do
  slice_file="${package_dir}/select_${slice}.png"
  [[ -f "$slice_file" ]] || fail "missing GRUB selection slice: ${slice_file}"
  [[ "$(stat -c '%a' -- "$slice_file")" == 644 ]] || \
    fail "GRUB selection slice must be mode 0644: ${slice_file}"
  file --brief -- "$slice_file" | grep -Eq '^PNG image data, 12 x 12,' || \
    fail "GRUB selection slice is not a 12x12 PNG: ${slice_file}"
done

if grep -Fxq 'schweisos-grub-theme' "$profile_packages"; then
  fail 'GRUB theme package must not enter the current systemd-boot live ISO'
fi
[[ ! -e "${project_root}/iso/profiles/kde/grub" ]] || \
  fail 'current live ISO must not acquire a GRUB profile area'

git -C "$project_root" diff --check -- \
  branding \
  docs/adr/ADR-015-grub-theme-architecture.md \
  docs/boot \
  packages/schweisos-branding \
  packages/schweisos-grub-theme \
  tests/validate-grub-theme.sh

printf 'GRUB theme validation passed.\n'
printf '  canonical logo regular files: %s\n' "$matching_logo_files"
printf '  selection slices: %s (12x12 PNG)\n' "${#selection_slices[@]}"
printf '  activation: inert; installer-owned\n'
printf '  live ISO integration: absent by design\n'
