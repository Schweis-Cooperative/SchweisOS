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

for tool in awk bash cmp comm date find git grep install mkdir mktemp pacman-conf \
  readlink rm sed sort stat uniq wc; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
profile_dir="${project_root}/iso/profiles/kde"
airootfs_dir="${profile_dir}/airootfs"
entry_dir="${profile_dir}/efiboot/loader/entries"
profiledef="${profile_dir}/profiledef.sh"
package_list="${profile_dir}/packages.x86_64"
pacman_config="${profile_dir}/pacman.conf"
schweis_pacman_config="${project_root}/packages/schweisos-pacman-config/schweisos.conf"
mirrorlist="${project_root}/packages/schweisos-mirrorlist/schweisos-mirrorlist"

required_directories=(
  "$profile_dir"
  "$airootfs_dir"
  "${profile_dir}/efiboot/loader"
  "$entry_dir"
)

required_files=(
  "${profile_dir}/README.md"
  "$profiledef"
  "$package_list"
  "$pacman_config"
  "${profile_dir}/efiboot/loader/loader.conf"
  "${entry_dir}/01-schweisos-linux.conf"
  "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf"
  "${airootfs_dir}/etc/mkinitcpio.d/linux.preset"
  "${airootfs_dir}/etc/sddm.conf.d/10-schweisos-live.conf"
  "${airootfs_dir}/etc/sysusers.d/schweisos-live.conf"
  "${airootfs_dir}/etc/tmpfiles.d/schweisos-live.conf"
  "$schweis_pacman_config"
  "$mirrorlist"
)

for directory in "${required_directories[@]}"; do
  [[ -d "$directory" ]] || fail "missing required directory: ${directory}"
done

for file in "${required_files[@]}"; do
  [[ -f "$file" ]] || fail "missing required file: ${file}"
done

tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

unexpected_type="$(find "$profile_dir" -mindepth 1 \
  ! -type d ! -type f ! -type l -print -quit)"
[[ -z "$unexpected_type" ]] || fail "unexpected special file in profile: ${unexpected_type}"

while IFS= read -r -d '' directory; do
  mode="$(stat -c '%a' -- "$directory")"
  [[ "$mode" == '755' ]] || fail "directory must be mode 0755: ${directory} (${mode})"
done < <(find "$profile_dir" -type d -print0 | sort -z)

while IFS= read -r -d '' file; do
  mode="$(stat -c '%a' -- "$file")"
  [[ "$mode" == '644' ]] || fail "regular file must be mode 0644: ${file} (${mode})"
done < <(find "$profile_dir" -type f -print0 | sort -z)

world_writable="$(find "$profile_dir" \( -type d -o -type f \) -perm -0002 -print -quit)"
[[ -z "$world_writable" ]] || fail "world-writable profile path found: ${world_writable}"

unexpected_executable="$(find "$profile_dir" -type f -perm /111 -print -quit)"
[[ -z "$unexpected_executable" ]] || fail "unexpected executable profile file: ${unexpected_executable}"

bash -n \
  "$profiledef" \
  "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf" \
  "${airootfs_dir}/etc/mkinitcpio.d/linux.preset" \
  "${BASH_SOURCE[0]}"

profile_snapshot() {
  local timezone="$1"

  TZ="$timezone" SOURCE_DATE_EPOCH=0 bash -c '
    set -euo pipefail
    source "$1"

    required_variables=(
      iso_name iso_label iso_publisher iso_application iso_version install_dir
      buildmodes bootmodes arch pacman_conf airootfs_image_type
      airootfs_image_tool_options
    )
    for variable in "${required_variables[@]}"; do
      [[ -v "$variable" ]] || exit 1
    done

    [[ "$iso_name" == schweisos ]]
    [[ "$iso_label" == SCHWEIS_197001 ]]
    [[ "$iso_label" =~ ^[A-Z0-9_]{1,32}$ ]]
    [[ "$iso_publisher" == "Schweis Project <https://schweisos.org>" ]]
    [[ "$iso_version" == 1970.01.01 ]]
    [[ "$install_dir" =~ ^[a-z0-9]{1,8}$ ]]
    [[ "${#buildmodes[@]}" -eq 1 && "${buildmodes[0]}" == iso ]]
    [[ "${#bootmodes[@]}" -eq 1 && "${bootmodes[0]}" == uefi.systemd-boot ]]
    [[ "$arch" == x86_64 ]]
    [[ "$pacman_conf" == pacman.conf ]]
    [[ "$airootfs_image_type" == squashfs ]]
    [[ "${airootfs_image_tool_options[*]}" == "-comp xz -Xbcj x86 -b 1M -Xdict-size 1M" ]]

    declare -p iso_name iso_label iso_publisher iso_application iso_version
    declare -p install_dir buildmodes bootmodes arch pacman_conf
    declare -p airootfs_image_type airootfs_image_tool_options
  ' _ "$profiledef"
}

profile_snapshot UTC >"${tmp_dir}/profile.utc"
profile_snapshot Europe/Istanbul >"${tmp_dir}/profile.istanbul"
profile_snapshot Pacific/Honolulu >"${tmp_dir}/profile.honolulu"
cmp -s "${tmp_dir}/profile.utc" "${tmp_dir}/profile.istanbul" || \
  fail 'profile metadata changes with the host timezone'
cmp -s "${tmp_dir}/profile.utc" "${tmp_dir}/profile.honolulu" || \
  fail 'profile metadata changes with the host timezone'

if ! awk '
  /^[[:space:]]*$/ { next }
  /^[[:space:]]*#/ { next }
  /^[a-z0-9][a-z0-9@._+-]*$/ { print; next }
  { print FNR ":" $0 > "/dev/stderr"; invalid = 1 }
  END { exit invalid }
' "$package_list" >"${tmp_dir}/packages.normalized"; then
  fail 'packages.x86_64 contains an invalid package entry'
fi

[[ -s "${tmp_dir}/packages.normalized" ]] || fail 'packages.x86_64 contains no packages'

sort "${tmp_dir}/packages.normalized" >"${tmp_dir}/packages.sorted"
duplicate_packages="$(uniq -d "${tmp_dir}/packages.sorted")"
[[ -z "$duplicate_packages" ]] || fail "duplicate package entries: ${duplicate_packages}"

if ! awk '
  /^[[:space:]]*$/ { previous = ""; next }
  /^[[:space:]]*#/ { next }
  {
    if (previous != "" && $0 < previous) {
      print FNR ":" $0 " sorts before " previous > "/dev/stderr"
      invalid = 1
    }
    previous = $0
  }
  END { exit invalid }
' "$package_list"; then
  fail 'package entries must be sorted within each documented group'
fi

required_packages=(
  base
  linux
  linux-firmware
  mkinitcpio
  mkinitcpio-archiso
  networkmanager
  plasma-desktop
  plasma-nm
  schweisos-keyring
  schweisos-mirrorlist
  schweisos-pacman-config
  schweisos-release
  sddm
  ttf-dejavu
)

for package in "${required_packages[@]}"; do
  grep -Fxq -- "$package" "${tmp_dir}/packages.normalized" || \
    fail "required ISO package is missing: ${package}"
done

sed 's/[[:space:]]*#.*$//' "$pacman_config" >"${tmp_dir}/pacman.uncommented"

if grep -Eq '^[[:space:]]*Server[[:space:]]*=|https?://|file://' \
  "${tmp_dir}/pacman.uncommented"; then
  fail 'profile pacman.conf contains a hardcoded repository endpoint'
fi

if grep -rIEq --exclude='profiledef.sh' \
  '^[[:space:]]*Server[[:space:]]*=|https?://|file://' "$profile_dir"; then
  fail 'hardcoded repository endpoint found outside profile metadata'
fi
if sed '/^iso_publisher="Schweis Project <https:\/\/schweisos\.org>"$/d' "$profiledef" \
  | grep -Eq '^[[:space:]]*Server[[:space:]]*=|https?://|file://'; then
  fail 'unexpected endpoint found in profiledef.sh'
fi

if grep -Eq 'SigLevel[[:space:]]*=[^#]*(Never|TrustAll)' "${tmp_dir}/pacman.uncommented"; then
  fail 'profile pacman.conf weakens signature verification'
fi

mapfile -t source_repositories < <(
  sed -n 's/^[[:space:]]*\[\([^]]*\)\][[:space:]]*$/\1/p' "$pacman_config" \
    | sed '/^options$/d'
)
[[ "${source_repositories[*]}" == 'core extra' ]] || \
  fail 'profile pacman.conf must directly define only [core] and [extra]'

arch_include_count="$(grep -Ec \
  '^[[:space:]]*Include[[:space:]]*=[[:space:]]*/etc/pacman\.d/mirrorlist[[:space:]]*$' \
  "$pacman_config" || true)"
schweis_include_count="$(grep -Ec \
  '^[[:space:]]*Include[[:space:]]*=[[:space:]]*/etc/pacman\.d/schweisos\.conf[[:space:]]*$' \
  "$pacman_config" || true)"
[[ "$arch_include_count" -eq 2 ]] || fail 'profile must include the Arch mirrorlist exactly twice'
[[ "$schweis_include_count" -eq 1 ]] || fail 'profile must include schweisos.conf exactly once'

pacman_root="${tmp_dir}/pacman-root"
mkdir -p "${pacman_root}/etc/pacman.d"
install -m 0644 "$pacman_config" "${pacman_root}/etc/pacman.conf"
install -m 0644 "$schweis_pacman_config" "${pacman_root}/etc/pacman.d/schweisos.conf"
install -m 0644 "$mirrorlist" "${pacman_root}/etc/pacman.d/schweisos-mirrorlist"
: >"${pacman_root}/etc/pacman.d/mirrorlist"

mapfile -t parsed_repositories < <(
  pacman-conf --sysroot "$pacman_root" --config /etc/pacman.conf --repo-list
)
[[ "${parsed_repositories[*]}" == 'core extra schweisos' ]] || \
  fail 'pacman-conf did not parse the expected repository set'

mapfile -t global_siglevel < <(
  pacman-conf --sysroot "$pacman_root" --config /etc/pacman.conf SigLevel
)
mapfile -t schweis_siglevel < <(
  pacman-conf --sysroot "$pacman_root" --config /etc/pacman.conf \
    --repo schweisos SigLevel
)

for required_policy in PackageRequired PackageTrustedOnly DatabaseOptional DatabaseTrustedOnly; do
  [[ " ${global_siglevel[*]} " == *" ${required_policy} "* ]] || \
    fail "global pacman policy is missing ${required_policy}"
done
for required_policy in PackageRequired PackageTrustedOnly DatabaseRequired DatabaseTrustedOnly; do
  [[ " ${schweis_siglevel[*]} " == *" ${required_policy} "* ]] || \
    fail "SchweisOS repository policy is missing ${required_policy}"
done

loader_config="${profile_dir}/efiboot/loader/loader.conf"
mapfile -t default_entries < <(
  awk '$1 == "default" { print $2 }' "$loader_config"
)
[[ "${#default_entries[@]}" -eq 1 ]] || fail 'loader.conf must define exactly one default entry'
default_entry="${default_entries[0]}"
[[ "$default_entry" =~ ^[a-zA-Z0-9._+-]+\.conf$ ]] || fail 'loader default entry name is invalid'
[[ -f "${entry_dir}/${default_entry}" ]] || fail "loader default entry is missing: ${default_entry}"

mapfile -t efi_entries < <(
  find "$entry_dir" -maxdepth 1 -type f -name '*.conf' -printf '%f\n' | sort
)
(( ${#efi_entries[@]} > 0 )) || fail 'no UEFI loader entries found'

for entry_name in "${efi_entries[@]}"; do
  entry="${entry_dir}/${entry_name}"
  [[ "$entry_name" =~ ^([0-9]{2})-[a-z0-9._+-]+\.conf$ ]] || \
    fail "UEFI entry name must begin with a two-digit order: ${entry_name}"
  filename_order="${BASH_REMATCH[1]}"

  for directive in title sort-key linux initrd options; do
    directive_count="$(awk -v directive="$directive" '$1 == directive { count++ } END { print count + 0 }' "$entry")"
    [[ "$directive_count" -eq 1 ]] || \
      fail "${entry_name} must contain exactly one ${directive} directive"
  done

  kernel_path="$(awk '$1 == "linux" { print $2 }' "$entry")"
  initramfs_path="$(awk '$1 == "initrd" { print $2 }' "$entry")"
  entry_order="$(awk '$1 == "sort-key" { print $2 }' "$entry")"
  options="$(awk '$1 == "options" { $1 = ""; sub(/^[[:space:]]+/, ""); print }' "$entry")"
  [[ "$entry_order" == "$filename_order" ]] || fail "sort-key does not match ${entry_name}"
  [[ "$kernel_path" == '/%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux' ]] || \
    fail "unexpected kernel path in ${entry_name}"
  [[ "$initramfs_path" == '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img' ]] || \
    fail "unexpected initramfs path in ${entry_name}"
  [[ " $options " == *' archisobasedir=%INSTALL_DIR% '* ]] || \
    fail "${entry_name} is missing archisobasedir"
  [[ " $options " == *' archisosearchuuid=%ARCHISO_UUID% '* ]] || \
    fail "${entry_name} is missing archisosearchuuid"
done

printf '%s\n' '%ARCH%' '%ARCHISO_UUID%' '%INSTALL_DIR%' | sort >"${tmp_dir}/allowed.tokens"
grep -Eho '%[A-Z][A-Z0-9_]*%' "$loader_config" "${entry_dir}"/*.conf \
  | sort -u >"${tmp_dir}/actual.tokens" || true
unexpected_tokens="$(comm -13 "${tmp_dir}/allowed.tokens" "${tmp_dir}/actual.tokens")"
[[ -z "$unexpected_tokens" ]] || fail "unsupported Archiso template token: ${unexpected_tokens}"

[[ ! -e "${profile_dir}/syslinux" ]] || fail 'syslinux is not allowed by the selected UEFI-only boot contract'
[[ ! -e "${profile_dir}/grub" ]] || fail 'GRUB profile files are not allowed by the selected boot contract'

bash -c '
  set -euo pipefail
  source "$1"
  [[ "${HOOKS[*]}" == "base udev modconf archiso block filesystems" ]]
' _ "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf" || \
  fail 'mkinitcpio hook list does not match the Archiso baseline contract'

bash -c '
  set -euo pipefail
  source "$1"
  [[ "${PRESETS[*]}" == archiso ]]
  [[ "$ALL_kver" == /boot/vmlinuz-linux ]]
  [[ "$archiso_config" == /etc/mkinitcpio.conf.d/archiso.conf ]]
  [[ "$archiso_image" == /boot/initramfs-linux.img ]]
' _ "${airootfs_dir}/etc/mkinitcpio.d/linux.preset" || \
  fail 'linux preset does not match the Archiso baseline contract'

expected_overlay_paths=(
  etc
  etc/mkinitcpio.conf.d
  etc/mkinitcpio.conf.d/archiso.conf
  etc/mkinitcpio.d
  etc/mkinitcpio.d/linux.preset
  etc/sddm.conf.d
  etc/sddm.conf.d/10-schweisos-live.conf
  etc/systemd
  etc/systemd/system
  etc/systemd/system/display-manager.service
  etc/systemd/system/multi-user.target.wants
  etc/systemd/system/multi-user.target.wants/NetworkManager.service
  etc/sysusers.d
  etc/sysusers.d/schweisos-live.conf
  etc/tmpfiles.d
  etc/tmpfiles.d/schweisos-live.conf
)
printf '%s\n' "${expected_overlay_paths[@]}" | sort >"${tmp_dir}/overlay.expected"
find "$airootfs_dir" -mindepth 1 -printf '%P\n' | sort >"${tmp_dir}/overlay.actual"
overlay_difference="$(comm -3 "${tmp_dir}/overlay.expected" "${tmp_dir}/overlay.actual")"
[[ -z "$overlay_difference" ]] || fail "unexpected airootfs layout difference: ${overlay_difference}"

display_manager_link="${airootfs_dir}/etc/systemd/system/display-manager.service"
network_manager_link="${airootfs_dir}/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
[[ -L "$display_manager_link" ]] || fail 'display-manager.service must be a symlink'
[[ "$(readlink -- "$display_manager_link")" == '/usr/lib/systemd/system/sddm.service' ]] || \
  fail 'display-manager.service has an unexpected target'
[[ -L "$network_manager_link" ]] || fail 'NetworkManager.service must be a symlink'
[[ "$(readlink -- "$network_manager_link")" == '/usr/lib/systemd/system/NetworkManager.service' ]] || \
  fail 'NetworkManager.service has an unexpected target'
[[ "$(find "$airootfs_dir" -type l | wc -l)" -eq 2 ]] || fail 'airootfs must contain exactly two symlinks'

sysusers_line="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/sysusers.d/schweisos-live.conf")"
tmpfiles_line="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/tmpfiles.d/schweisos-live.conf")"
sddm_config="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/sddm.conf.d/10-schweisos-live.conf")"
[[ "$sysusers_line" == 'u live 1000 "SchweisOS Live User" /home/live /usr/bin/bash' ]] || \
  fail 'unexpected live sysusers declaration'
[[ "$tmpfiles_line" == 'd /home/live 0750 live live -' ]] || fail 'unexpected live home declaration'
[[ "$sddm_config" == $'[Autologin]\nUser=live\nSession=plasma.desktop' ]] || \
  fail 'unexpected SDDM live-session configuration'

for forbidden_path in \
  "${airootfs_dir}/usr" \
  "${airootfs_dir}/etc/passwd" \
  "${airootfs_dir}/etc/shadow"; do
  [[ ! -e "$forbidden_path" ]] || fail "forbidden airootfs payload found: ${forbidden_path}"
done

key_material="$(find "$profile_dir" -type f \
  \( -name '*.asc' -o -name '*.gpg' -o -name '*.key' -o -name '*.pem' \
     -o -name '*.p12' -o -name '*.pfx' -o -name '*.kbx' -o -name '*.sig' \) \
  -print -quit)"
[[ -z "$key_material" ]] || fail "embedded signing material found: ${key_material}"

package_payload="$(find "$airootfs_dir" -type f -name '*.pkg.tar*' -print -quit)"
[[ -z "$package_payload" ]] || fail "package payload found in airootfs: ${package_payload}"

if grep -rIEq --exclude='*.pkg.tar.*' \
  'BEGIN (PGP |OPENSSH |RSA |DSA |EC |ENCRYPTED )?(PUBLIC|PRIVATE) KEY( BLOCK)?' \
  "$profile_dir"; then
  fail 'embedded public or private key armor found in ISO profile'
fi

if grep -rIEq --exclude='*.pkg.tar.*' \
  '(^|[^A-Za-z])(PASSWORD|TOKEN|SECRET|PRIVATE_KEY)[[:space:]]*=' "$profile_dir"; then
  fail 'hardcoded credential or secret assignment found in ISO profile'
fi

upstream_status='Archiso 88 static contract target; installed baseline unavailable'
upstream_baseline='/usr/share/archiso/configs/baseline/airootfs/etc'
if [[ -f "${upstream_baseline}/mkinitcpio.conf.d/archiso.conf" \
      && -f "${upstream_baseline}/mkinitcpio.d/linux.preset" ]]; then
  cmp -s "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf" \
    "${upstream_baseline}/mkinitcpio.conf.d/archiso.conf" || \
    fail 'archiso.conf differs from the installed Archiso baseline'
  cmp -s "${airootfs_dir}/etc/mkinitcpio.d/linux.preset" \
    "${upstream_baseline}/mkinitcpio.d/linux.preset" || \
    fail 'linux.preset differs from the installed Archiso baseline'
  upstream_status='installed baseline matched'
fi

git -C "$project_root" diff --check -- \
  iso/profiles/kde \
  iso/README.md \
  scripts/build-iso.sh \
  tests/validate-iso-profile.sh \
  tests/README.md \
  docs/build/README.md

printf 'ISO profile validation passed.\n'
printf '  profile: %s\n' "$profile_dir"
printf '  packages: %s (group-sorted and unique)\n' "$(wc -l <"${tmp_dir}/packages.normalized")"
printf '  UEFI entries: %s\n' "${#efi_entries[@]}"
printf '  airootfs nodes: %s (allowlisted)\n' "${#expected_overlay_paths[@]}"
printf '  pacman repositories: %s\n' "${parsed_repositories[*]}"
printf '  upstream: %s\n' "$upstream_status"
