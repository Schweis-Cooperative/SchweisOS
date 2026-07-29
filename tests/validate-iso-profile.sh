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
  readlink rm sed sort stat uniq visudo wc; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
profile_dir="${project_root}/iso/profiles/kde"
release_package_dir="${project_root}/packages/schweisos-release"
branding_package_dir="${project_root}/packages/schweisos-branding"
canonical_logo="${project_root}/branding/assets/logo/schweisos.png"
branding_package_source="${branding_package_dir}/schweisos.png"
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
  "${profile_dir}/grub"
)

required_files=(
  "${profile_dir}/README.md"
  "$profiledef"
  "$package_list"
  "$pacman_config"
  "${profile_dir}/efiboot/loader/loader.conf"
  "${entry_dir}/01-schweisos-linux.conf"
  "${entry_dir}/02-schweisos-linux-debug.conf"
  "${profile_dir}/grub/loopback.cfg"
  "${airootfs_dir}/etc/hostname"
  "${airootfs_dir}/etc/locale.conf"
  "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf"
  "${airootfs_dir}/etc/mkinitcpio.d/linux.preset"
  "${airootfs_dir}/etc/plymouth/plymouthd.conf"
  "${airootfs_dir}/etc/polkit-1/rules.d/49-schweisos-live-admin.rules"
  "${airootfs_dir}/etc/sddm.conf.d/10-schweisos-live.conf"
  "${airootfs_dir}/etc/systemd/system/emergency.target.d/10-schweisos-debug-fallback.conf"
  "${airootfs_dir}/etc/systemd/system/plymouth-quit.service.d/10-schweisos-debug-fallback.conf"
  "${airootfs_dir}/etc/systemd/system/plymouth-quit-wait.service.d/10-schweisos-debug-fallback.conf"
  "${airootfs_dir}/etc/systemd/system/plymouth-start.service.d/10-schweisos-debug-fallback.conf"
  "${airootfs_dir}/etc/systemd/system/schweisos-plymouth-exit-fallback.service"
  "${airootfs_dir}/etc/systemd/system/schweisos-plymouth-exit-watch.path"
  "${airootfs_dir}/etc/systemd/system/schweisos-plymouth-watchdog.service"
  "${airootfs_dir}/etc/systemd/system/sddm.service.d/10-schweisos-debug-fallback.conf"
  "${airootfs_dir}/etc/systemd/system/schweisos-boot-debug-fallback.service"
  "${airootfs_dir}/etc/systemd/system/sysinit.target.d/10-schweisos-plymouth-watch.conf"
  "${airootfs_dir}/etc/sysusers.d/schweisos-live.conf"
  "${airootfs_dir}/etc/sudoers.d/10-schweisos-live"
  "${airootfs_dir}/etc/tmpfiles.d/schweisos-live.conf"
  "${airootfs_dir}/usr/lib/schweisos-live/plymouth-is-stopped"
  "${airootfs_dir}/usr/lib/schweisos-live/plymouth-quit-guarded"
  "${airootfs_dir}/usr/lib/schweisos-live/plymouth-watchdog"
  "${airootfs_dir}/usr/share/plymouth/themes/schweisos/schweisos.plymouth"
  "${airootfs_dir}/usr/share/plymouth/themes/schweisos/schweisos.script"
  "$schweis_pacman_config"
  "$mirrorlist"
  "$canonical_logo"
  "$branding_package_source"
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

release_srcinfo="$(cd -- "$release_package_dir" && makepkg --printsrcinfo)"
release_pkgver="$(awk -F ' = ' '$1 == "\tpkgver" { print $2; exit }' <<<"$release_srcinfo")"
[[ -n "$release_pkgver" ]] || fail 'source schweisos-release pkgver is unreadable'

unexpected_type="$(find "$profile_dir" -mindepth 1 \
  ! -type d ! -type f ! -type l -print -quit)"
[[ -z "$unexpected_type" ]] || fail "unexpected special file in profile: ${unexpected_type}"

while IFS= read -r -d '' directory; do
  mode="$(stat -c '%a' -- "$directory")"
  [[ "$mode" == '755' ]] || fail "directory must be mode 0755: ${directory} (${mode})"
done < <(find "$profile_dir" -type d -print0 | sort -z)

while IFS= read -r -d '' file; do
  mode="$(stat -c '%a' -- "$file")"
  case "$file" in
    "${airootfs_dir}/usr/lib/schweisos-live/plymouth-is-stopped" | \
    "${airootfs_dir}/usr/lib/schweisos-live/plymouth-quit-guarded" | \
    "${airootfs_dir}/usr/lib/schweisos-live/plymouth-watchdog")
      [[ "$mode" == '755' ]] || fail "live helper must be mode 0755: ${file} (${mode})"
      ;;
    *)
      [[ "$mode" == '644' ]] || fail "regular file must be mode 0644: ${file} (${mode})"
      ;;
  esac
done < <(find "$profile_dir" -type f -print0 | sort -z)

world_writable="$(find "$profile_dir" \( -type d -o -type f \) -perm -0002 -print -quit)"
[[ -z "$world_writable" ]] || fail "world-writable profile path found: ${world_writable}"

unexpected_executable="$(find "$profile_dir" -type f -perm /111 \
  ! -path "${airootfs_dir}/usr/lib/schweisos-live/plymouth-is-stopped" \
  ! -path "${airootfs_dir}/usr/lib/schweisos-live/plymouth-quit-guarded" \
  ! -path "${airootfs_dir}/usr/lib/schweisos-live/plymouth-watchdog" \
  -print -quit)"
[[ -z "$unexpected_executable" ]] || fail "unexpected executable profile file: ${unexpected_executable}"

bash -n \
  "$profiledef" \
  "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf" \
  "${airootfs_dir}/etc/mkinitcpio.d/linux.preset" \
  "${airootfs_dir}/usr/lib/schweisos-live/plymouth-is-stopped" \
  "${airootfs_dir}/usr/lib/schweisos-live/plymouth-quit-guarded" \
  "${airootfs_dir}/usr/lib/schweisos-live/plymouth-watchdog" \
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
    [[ "$iso_version" == "$2" ]]
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
  ' _ "$profiledef" "$release_pkgver"
}

profile_snapshot UTC >"${tmp_dir}/profile.utc"
profile_snapshot Europe/Istanbul >"${tmp_dir}/profile.istanbul"
profile_snapshot Pacific/Honolulu >"${tmp_dir}/profile.honolulu"
cmp -s "${tmp_dir}/profile.utc" "${tmp_dir}/profile.istanbul" || \
  fail 'profile metadata changes with the host timezone'
cmp -s "${tmp_dir}/profile.utc" "${tmp_dir}/profile.honolulu" || \
  fail 'profile metadata changes with the host timezone'
TZ=UTC SOURCE_DATE_EPOCH=0 bash -c '
  set -euo pipefail
  source "$1"
  [[ "${file_permissions["/etc/sudoers.d/10-schweisos-live"]-}" == "0:0:440" ]]
' _ "$profiledef" || fail 'profiledef must install the live sudoers drop-in as root-owned mode 0440'

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
  arch-install-scripts
  base
  btrfs-progs
  calamares
  dosfstools
  dolphin
  efibootmgr
  firefox
  kate
  konsole
  linux
  linux-firmware
  mkinitcpio
  mkinitcpio-archiso
  networkmanager
  plasma-desktop
  plasma-nm
  plasma-systemmonitor
  plymouth
  schweisos-branding
  schweisos-calamares-config
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
loader_timeout="$(awk '$1 == "timeout" { print $2 }' "$loader_config")"
loader_console_mode="$(awk '$1 == "console-mode" { print $2 }' "$loader_config")"
loader_editor="$(awk '$1 == "editor" { print $2 }' "$loader_config")"
loader_auto_entries="$(awk '$1 == "auto-entries" { print $2 }' "$loader_config")"
loader_auto_firmware="$(awk '$1 == "auto-firmware" { print $2 }' "$loader_config")"
[[ "$loader_timeout" == 3 ]] || fail 'loader.conf must use a short three-second timeout'
[[ "$loader_console_mode" == keep ]] || fail 'loader.conf must preserve the firmware console mode'
[[ "$loader_editor" == no ]] || fail 'loader.conf must disable interactive command-line editing'
[[ "$loader_auto_entries" == no ]] || fail 'loader.conf must suppress automatic operating-system entries'
[[ "$loader_auto_firmware" == no ]] || fail 'loader.conf must suppress the automatic firmware entry'

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
[[ "${efi_entries[*]}" == '01-schweisos-linux.conf 02-schweisos-linux-debug.conf' ]] || \
  fail 'UEFI loader entries must provide exactly normal and debug boot paths'

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
  entry_title="$(awk '$1 == "title" { $1 = ""; sub(/^[[:space:]]+/, ""); print }' "$entry")"
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
  firstboot_options="$(tr ' ' '\n' <<<"$options" | grep '^systemd\.firstboot=' || true)"
  [[ "$firstboot_options" == 'systemd.firstboot=no' ]] || \
    fail "${entry_name} must disable interactive systemd-firstboot exactly once"
  case "$entry_name" in
    01-schweisos-linux.conf)
      [[ "$entry_title" == 'SchweisOS Live' ]] || fail 'normal boot entry title is unexpected'
      [[ " $options " == *' quiet '* ]] || fail 'normal boot entry must be quiet'
      [[ " $options " == *' splash '* ]] || fail 'normal boot entry must enable Plymouth splash'
      [[ " $options " == *' loglevel=3 '* ]] || fail 'normal boot entry must reduce kernel log verbosity'
      [[ " $options " == *' systemd.show_status=auto '* ]] || \
        fail 'normal boot entry must show systemd status automatically on failure'
      [[ " $options " == *' vt.global_cursor_default=0 '* ]] || \
        fail 'normal boot entry must hide the text cursor during graphical boot'
      ;;
    02-schweisos-linux-debug.conf)
      [[ "$entry_title" == 'SchweisOS Live (Debug)' ]] || fail 'debug boot entry title is unexpected'
      [[ " $options " != *' quiet '* ]] || fail 'debug boot entry must not be quiet'
      [[ " $options " != *' splash '* ]] || fail 'debug boot entry must not enable Plymouth splash'
      [[ " $options " == *' loglevel=7 '* ]] || fail 'debug boot entry must keep verbose kernel logs'
      [[ " $options " == *' systemd.show_status=yes '* ]] || \
        fail 'debug boot entry must force visible systemd status'
      [[ " $options " == *' vt.global_cursor_default=1 '* ]] || \
        fail 'debug boot entry must keep the text cursor visible'
      ;;
  esac
done

printf '%s\n' '%ARCH%' '%ARCHISO_UUID%' '%INSTALL_DIR%' | sort >"${tmp_dir}/allowed.tokens"
grep -Eho '%[A-Z][A-Z0-9_]*%' "$loader_config" "${entry_dir}"/*.conf \
  "${profile_dir}/grub/"*.cfg \
  | sort -u >"${tmp_dir}/actual.tokens" || true
unexpected_tokens="$(comm -13 "${tmp_dir}/allowed.tokens" "${tmp_dir}/actual.tokens")"
[[ -z "$unexpected_tokens" ]] || fail "unsupported Archiso template token: ${unexpected_tokens}"

[[ ! -e "${profile_dir}/syslinux" ]] || fail 'syslinux is not allowed by the selected UEFI-only boot contract'
mapfile -t grub_profile_files < <(
  find "${profile_dir}/grub" -mindepth 1 -maxdepth 1 -type f -printf '%f\n' | sort
)
[[ "${grub_profile_files[*]}" == 'loopback.cfg' ]] || \
  fail 'GRUB profile area may contain only loopback.cfg for Ventoy/loopback compatibility'
[[ ! -e "${profile_dir}/grub/grub.cfg" ]] || \
  fail 'full GRUB boot configuration is not allowed by the selected systemd-boot live contract'

loopback_config="${profile_dir}/grub/loopback.cfg"
grep -Fxq 'search --no-floppy --set=archiso_img_dev --file "${iso_path}"' "$loopback_config" || \
  fail 'loopback.cfg must locate the filesystem containing the ISO file'
grep -Fxq 'probe --set archiso_img_dev_uuid --fs-uuid "${archiso_img_dev}"' "$loopback_config" || \
  fail 'loopback.cfg must derive img_dev from the ISO filesystem UUID'
grep -Fxq 'default=schweisos' "$loopback_config" || \
  fail 'loopback.cfg must default to the normal SchweisOS entry'
grep -Fxq 'timeout=3' "$loopback_config" || \
  fail 'loopback.cfg timeout must match the live systemd-boot timeout'

mapfile -t loopback_menu_ids < <(
  sed -n "s/.*--id '\\([^']*\\)'.*/\\1/p" "$loopback_config" | sort
)
[[ "${loopback_menu_ids[*]}" == 'schweisos schweisos-debug uefi-firmware' ]] || \
  fail 'loopback.cfg must expose normal/debug entries plus UEFI firmware utility only'

normal_loopback_linux="$(
  awk "/--id 'schweisos'/,/^}/ { if (\$1 == \"linux\") { \$1 = \"\"; sub(/^[[:space:]]+/, \"\"); print; exit } }" \
    "$loopback_config"
)"
normal_loopback_initrd="$(
  awk "/--id 'schweisos'/,/^}/ { if (\$1 == \"initrd\") { print \$2; exit } }" \
    "$loopback_config"
)"
debug_loopback_linux="$(
  awk "/--id 'schweisos-debug'/,/^}/ { if (\$1 == \"linux\") { \$1 = \"\"; sub(/^[[:space:]]+/, \"\"); print; exit } }" \
    "$loopback_config"
)"
debug_loopback_initrd="$(
  awk "/--id 'schweisos-debug'/,/^}/ { if (\$1 == \"initrd\") { print \$2; exit } }" \
    "$loopback_config"
)"
[[ "$normal_loopback_linux" == /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux* ]] || \
  fail 'loopback normal entry uses an unexpected kernel path'
[[ "$debug_loopback_linux" == /%INSTALL_DIR%/boot/%ARCH%/vmlinuz-linux* ]] || \
  fail 'loopback debug entry uses an unexpected kernel path'
[[ "$normal_loopback_initrd" == '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img' ]] || \
  fail 'loopback normal entry uses an unexpected initramfs path'
[[ "$debug_loopback_initrd" == '/%INSTALL_DIR%/boot/%ARCH%/initramfs-linux.img' ]] || \
  fail 'loopback debug entry uses an unexpected initramfs path'
for loopback_line in "$normal_loopback_linux" "$debug_loopback_linux"; do
  [[ " $loopback_line " == *' archisobasedir=%INSTALL_DIR% '* ]] || \
    fail 'loopback entry is missing archisobasedir'
  [[ " $loopback_line " == *' img_dev=UUID=${archiso_img_dev_uuid} '* ]] || \
    fail 'loopback entry is missing img_dev UUID handoff'
  [[ " $loopback_line " == *' img_loop="${iso_path}" '* ]] || \
    fail 'loopback entry is missing img_loop handoff'
  [[ " $loopback_line " == *' systemd.firstboot=no '* ]] || \
    fail 'loopback entry must disable interactive systemd-firstboot'
done
[[ " $normal_loopback_linux " == *' quiet '* \
  && " $normal_loopback_linux " == *' splash '* \
  && " $normal_loopback_linux " == *' loglevel=3 '* \
  && " $normal_loopback_linux " == *' systemd.show_status=auto '* \
  && " $normal_loopback_linux " == *' vt.global_cursor_default=0 '* ]] || \
  fail 'loopback normal entry does not match the quiet graphical boot contract'
[[ " $debug_loopback_linux " != *' quiet '* \
  && " $debug_loopback_linux " != *' splash '* \
  && " $debug_loopback_linux " == *' loglevel=7 '* \
  && " $debug_loopback_linux " == *' systemd.show_status=yes '* \
  && " $debug_loopback_linux " == *' vt.global_cursor_default=1 '* ]] || \
  fail 'loopback debug entry does not match the visible diagnostic contract'

bash -c '
  set -euo pipefail
  source "$1"
  [[ "${HOOKS[*]}" == "base udev modconf kms plymouth archiso block filesystems" ]]
' _ "${airootfs_dir}/etc/mkinitcpio.conf.d/archiso.conf" || \
  fail 'mkinitcpio hook list does not match the approved Plymouth live-boot contract'

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
  etc/hostname
  etc/locale.conf
  etc/localtime
  etc/mkinitcpio.conf.d
  etc/mkinitcpio.conf.d/archiso.conf
  etc/mkinitcpio.d
  etc/mkinitcpio.d/linux.preset
  etc/plymouth
  etc/plymouth/plymouthd.conf
  etc/polkit-1
  etc/polkit-1/rules.d
  etc/polkit-1/rules.d/49-schweisos-live-admin.rules
  etc/sddm.conf.d
  etc/sddm.conf.d/10-schweisos-live.conf
  etc/systemd
  etc/systemd/system
  etc/systemd/system/display-manager.service
  etc/systemd/system/emergency.target.d
  etc/systemd/system/emergency.target.d/10-schweisos-debug-fallback.conf
  etc/systemd/system/multi-user.target.wants
  etc/systemd/system/multi-user.target.wants/NetworkManager.service
  etc/systemd/system/plymouth-quit.service.d
  etc/systemd/system/plymouth-quit.service.d/10-schweisos-debug-fallback.conf
  etc/systemd/system/plymouth-quit-wait.service.d
  etc/systemd/system/plymouth-quit-wait.service.d/10-schweisos-debug-fallback.conf
  etc/systemd/system/plymouth-start.service.d
  etc/systemd/system/plymouth-start.service.d/10-schweisos-debug-fallback.conf
  etc/systemd/system/schweisos-plymouth-exit-fallback.service
  etc/systemd/system/schweisos-plymouth-exit-watch.path
  etc/systemd/system/schweisos-plymouth-watchdog.service
  etc/systemd/system/sddm.service.d
  etc/systemd/system/sddm.service.d/10-schweisos-debug-fallback.conf
  etc/systemd/system/schweisos-boot-debug-fallback.service
  etc/systemd/system/sysinit.target.d
  etc/systemd/system/sysinit.target.d/10-schweisos-plymouth-watch.conf
  etc/sysusers.d
  etc/sysusers.d/schweisos-live.conf
  etc/sudoers.d
  etc/sudoers.d/10-schweisos-live
  etc/tmpfiles.d
  etc/tmpfiles.d/schweisos-live.conf
  usr
  usr/lib
  usr/lib/schweisos-live
  usr/lib/schweisos-live/plymouth-is-stopped
  usr/lib/schweisos-live/plymouth-quit-guarded
  usr/lib/schweisos-live/plymouth-watchdog
  usr/share
  usr/share/plymouth
  usr/share/plymouth/themes
  usr/share/plymouth/themes/schweisos
  usr/share/plymouth/themes/schweisos/schweisos.plymouth
  usr/share/plymouth/themes/schweisos/schweisos.script
)
printf '%s\n' "${expected_overlay_paths[@]}" | sort >"${tmp_dir}/overlay.expected"
find "$airootfs_dir" -mindepth 1 -printf '%P\n' | sort >"${tmp_dir}/overlay.actual"
overlay_difference="$(comm -3 "${tmp_dir}/overlay.expected" "${tmp_dir}/overlay.actual")"
[[ -z "$overlay_difference" ]] || fail "unexpected airootfs layout difference: ${overlay_difference}"

display_manager_link="${airootfs_dir}/etc/systemd/system/display-manager.service"
network_manager_link="${airootfs_dir}/etc/systemd/system/multi-user.target.wants/NetworkManager.service"
localtime_link="${airootfs_dir}/etc/localtime"
[[ -L "$display_manager_link" ]] || fail 'display-manager.service must be a symlink'
[[ "$(readlink -- "$display_manager_link")" == '/usr/lib/systemd/system/sddm.service' ]] || \
  fail 'display-manager.service has an unexpected target'
[[ -L "$network_manager_link" ]] || fail 'NetworkManager.service must be a symlink'
[[ "$(readlink -- "$network_manager_link")" == '/usr/lib/systemd/system/NetworkManager.service' ]] || \
  fail 'NetworkManager.service has an unexpected target'
[[ -L "$localtime_link" ]] || fail '/etc/localtime must be a symlink'
[[ "$(readlink -- "$localtime_link")" == '/usr/share/zoneinfo/UTC' ]] || \
  fail '/etc/localtime must select the neutral live-media UTC baseline'
[[ "$(find "$airootfs_dir" -type l | wc -l)" -eq 3 ]] || fail 'airootfs must contain exactly three symlinks'

sysusers_line="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/sysusers.d/schweisos-live.conf")"
tmpfiles_line="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/tmpfiles.d/schweisos-live.conf")"
sddm_config="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/sddm.conf.d/10-schweisos-live.conf")"
sudoers_file="${airootfs_dir}/etc/sudoers.d/10-schweisos-live"
polkit_rule="${airootfs_dir}/etc/polkit-1/rules.d/49-schweisos-live-admin.rules"
live_hostname="$(<"${airootfs_dir}/etc/hostname")"
live_locale="$(<"${airootfs_dir}/etc/locale.conf")"
[[ "$live_hostname" == schweisos ]] || fail 'unexpected live hostname'
[[ "$live_locale" == 'LANG=C.UTF-8' ]] || fail 'live locale must match the Archiso C.UTF-8 baseline'
[[ "$sysusers_line" == $'u live 1000 "SchweisOS Live User" /home/live /usr/bin/bash\nm live wheel' ]] || \
  fail 'unexpected live sysusers declaration'
[[ "$tmpfiles_line" == 'd /home/live 0750 live live -' ]] || fail 'unexpected live home declaration'
[[ "$sddm_config" == $'[Autologin]\nUser=live\nSession=plasma.desktop' ]] || \
  fail 'unexpected SDDM live-session configuration'
visudo -cf "$sudoers_file" >/dev/null 2>&1 || fail 'live sudoers drop-in is invalid'
grep -Fxq 'live ALL=(ALL:ALL) NOPASSWD: ALL' "$sudoers_file" || \
  fail 'live sudoers drop-in must grant passwordless sudo only to the live user'
for required_polkit_fragment in \
  'subject.user == "live"' \
  'subject.local' \
  'subject.active' \
  'polkit.Result.YES'; do
  grep -Fq "$required_polkit_fragment" "$polkit_rule" || \
    fail "live polkit rule is missing: ${required_polkit_fragment}"
done
[[ ! -e "${airootfs_dir}/usr/local/share/applications/calamares.desktop" \
    && ! -L "${airootfs_dir}/usr/local/share/applications/calamares.desktop" ]] || \
  fail 'installer launcher policy must remain package-owned, not profile-overlaid'

plymouth_config="$(grep -Ev '^[[:space:]]*($|#)' "${airootfs_dir}/etc/plymouth/plymouthd.conf")"
[[ "$plymouth_config" == $'[Daemon]\nTheme=schweisos\nShowDelay=0' ]] || \
  fail 'unexpected Plymouth daemon configuration'

plymouth_theme="${airootfs_dir}/usr/share/plymouth/themes/schweisos/schweisos.plymouth"
plymouth_script="${airootfs_dir}/usr/share/plymouth/themes/schweisos/schweisos.script"
grep -Fxq 'ModuleName=script' "$plymouth_theme" || fail 'Plymouth theme must use the upstream script plugin'
grep -Fxq 'ImageDir=/usr/share/schweisos/branding' "$plymouth_theme" || \
  fail 'Plymouth theme must consume the packaged SchweisOS branding directory'
grep -Fxq 'ScriptFile=/usr/share/plymouth/themes/schweisos/schweisos.script' "$plymouth_theme" || \
  fail 'Plymouth theme script path is unexpected'
grep -Fq 'Image("schweisos.png")' "$plymouth_script" || \
  fail 'Plymouth script must use the canonical packaged SchweisOS logo'
mapfile -t plymouth_images < <(
  grep -Eo 'Image\("[^"]+"\)' "$plymouth_script" | sort -u
)
[[ "${plymouth_images[*]}" == 'Image("schweisos.png")' ]] || \
  fail 'Plymouth script must not introduce another image dependency'
for animation_primitive in \
  'SetRefreshFunction(refresh_callback)' \
  'SetBootProgressFunction(boot_progress_callback)' \
  'SetQuitFunction(quit_callback)' \
  'Math.Cos' \
  'Math.Sin' \
  '.Scale(' \
  '.Crop(' \
  'SetOpacity(' \
  'logo.delay_frames' \
  'spinner.delay_frames' \
  'spinner.count = 5' \
  'spinner.angle_gap' \
  'spinner.phase' \
  'handoff'; do
  grep -Fq "$animation_primitive" "$plymouth_script" || \
    fail "Plymouth animation primitive is missing: ${animation_primitive}"
done
grep -Fq 'usr/share/schweisos/branding/schweisos.png' \
  "${project_root}/packages/schweisos-branding/PKGBUILD" || \
  fail 'schweisos-branding must install the logo path consumed by Plymouth'
[[ -L "$branding_package_source" ]] || \
  fail 'schweisos-branding source must be a symlink to the canonical logo'
[[ "$(readlink -- "$branding_package_source")" == '../../branding/assets/logo/schweisos.png' ]] || \
  fail 'schweisos-branding source symlink does not target the canonical logo'
[[ "$(readlink -f -- "$branding_package_source")" == "$canonical_logo" ]] || \
  fail 'schweisos-branding source symlink does not resolve to the canonical logo'

debug_fallback_service="${airootfs_dir}/etc/systemd/system/schweisos-boot-debug-fallback.service"
plymouth_start_dropin="${airootfs_dir}/etc/systemd/system/plymouth-start.service.d/10-schweisos-debug-fallback.conf"
plymouth_quit_dropin="${airootfs_dir}/etc/systemd/system/plymouth-quit.service.d/10-schweisos-debug-fallback.conf"
plymouth_quit_wait_dropin="${airootfs_dir}/etc/systemd/system/plymouth-quit-wait.service.d/10-schweisos-debug-fallback.conf"
plymouth_quit_guard="${airootfs_dir}/usr/lib/schweisos-live/plymouth-quit-guarded"
plymouth_stopped_check="${airootfs_dir}/usr/lib/schweisos-live/plymouth-is-stopped"
plymouth_watchdog="${airootfs_dir}/usr/lib/schweisos-live/plymouth-watchdog"
plymouth_watchdog_service="${airootfs_dir}/etc/systemd/system/schweisos-plymouth-watchdog.service"
grep -Fxq 'ExecStart=-/usr/bin/plymouth quit' "$debug_fallback_service" || \
  fail 'debug fallback must reveal logs by quitting Plymouth'
grep -Fxq 'ExecStart=-/usr/bin/setterm -cursor on' "$debug_fallback_service" || \
  fail 'debug fallback must restore the text cursor'
grep -Fxq 'Wants=schweisos-boot-debug-fallback.service' \
  "${airootfs_dir}/etc/systemd/system/emergency.target.d/10-schweisos-debug-fallback.conf" || \
  fail 'emergency.target must pull in the debug fallback'
grep -Fxq 'Wants=schweisos-plymouth-exit-watch.path schweisos-plymouth-watchdog.service' \
  "${airootfs_dir}/etc/systemd/system/sysinit.target.d/10-schweisos-plymouth-watch.conf" || \
  fail 'sysinit.target must start both Plymouth unexpected-exit detectors'
for plymouth_dropin in "$plymouth_start_dropin" "$plymouth_quit_dropin" "$plymouth_quit_wait_dropin"; do
  grep -Fxq 'OnFailure=schweisos-boot-debug-fallback.service' "$plymouth_dropin" || \
    fail "Plymouth failure drop-in is missing OnFailure fallback: ${plymouth_dropin}"
done
[[ "$(grep -Fxc 'ExecStartPost=' "$plymouth_start_dropin")" -eq 1 ]] || \
  fail 'Plymouth start drop-in must clear the vendor error-ignoring post-start command'
grep -Fxq 'ExecStartPost=/usr/bin/plymouth show-splash' "$plymouth_start_dropin" || \
  fail 'Plymouth show-splash failure must propagate to systemd'
[[ "$(grep -Fxc 'ExecStart=' "$plymouth_quit_dropin")" -eq 1 ]] || \
  fail 'Plymouth quit drop-in must clear the vendor error-ignoring command'
grep -Fxq 'ExecStart=/usr/lib/schweisos-live/plymouth-quit-guarded' "$plymouth_quit_dropin" || \
  fail 'Plymouth quit must use the guarded normal-handoff helper'
grep -Fxq 'TimeoutStartSec=20s' "$plymouth_quit_dropin" || \
  fail 'guarded Plymouth quit must have a finite timeout'
[[ "$(grep -Fxc 'ExecStart=' "$plymouth_quit_wait_dropin")" -eq 1 ]] || \
  fail 'Plymouth quit-wait drop-in must clear the vendor error-ignoring command'
grep -Fxq 'ExecStart=/usr/bin/plymouth --wait' "$plymouth_quit_wait_dropin" || \
  fail 'Plymouth quit-wait failure must propagate to systemd'
grep -Fxq 'TimeoutStartSec=20s' "$plymouth_quit_wait_dropin" || \
  fail 'Plymouth quit-wait must have a finite timeout'
grep -Fq 'marker=/run/schweisos-plymouth-normal-quit' "$plymouth_quit_guard" || \
  fail 'guarded Plymouth quit must own the normal-handoff marker'
grep -Fxq 'trap remove_marker EXIT' "$plymouth_quit_guard" || \
  fail 'guarded Plymouth quit must remove its marker on failure or interruption'
grep -Fxq "trap 'exit 1' HUP INT TERM" "$plymouth_quit_guard" || \
  fail 'guarded Plymouth quit must convert interruption into failure'
grep -Fxq '/usr/bin/plymouth quit --retain-splash' "$plymouth_quit_guard" || \
  fail 'guarded Plymouth quit must retain the splash during normal SDDM handoff'
grep -Fxq 'trap - EXIT HUP INT TERM' "$plymouth_quit_guard" || \
  fail 'guarded Plymouth quit must retain its marker only after success'
grep -Fxq 'OnFailure=schweisos-boot-debug-fallback.service' \
  "${airootfs_dir}/etc/systemd/system/sddm.service.d/10-schweisos-debug-fallback.conf" || \
  fail 'SDDM failure must reveal boot diagnostics'

plymouth_exit_watch="${airootfs_dir}/etc/systemd/system/schweisos-plymouth-exit-watch.path"
plymouth_exit_fallback="${airootfs_dir}/etc/systemd/system/schweisos-plymouth-exit-fallback.service"
grep -Fxq 'PathChanged=/run/plymouth' "$plymouth_exit_watch" || \
  fail 'Plymouth unexpected-exit watcher must observe the runtime directory'
grep -Fxq 'Unit=schweisos-plymouth-exit-fallback.service' "$plymouth_exit_watch" || \
  fail 'Plymouth unexpected-exit watcher must start the fallback service'
grep -Fxq 'ConditionPathExists=!/run/schweisos-plymouth-normal-quit' "$plymouth_exit_fallback" || \
  fail 'Plymouth unexpected-exit fallback must ignore normal quit handoff'
grep -Fxq 'ExecCondition=/usr/lib/schweisos-live/plymouth-is-stopped' "$plymouth_exit_fallback" || \
  fail 'Plymouth unexpected-exit fallback must reject a live daemon and stale PID files safely'
grep -Fq '[[ "$comm" == plymouthd ]] || exit 0' "$plymouth_stopped_check" || \
  fail 'Plymouth health check must identify the live daemon process'
grep -Fxq 'ExecStart=/usr/bin/systemctl --no-block start schweisos-boot-debug-fallback.service' \
  "$plymouth_exit_fallback" || \
  fail 'Plymouth unexpected-exit fallback must start the diagnostic fallback'
for watchdog_contract in \
  'DefaultDependencies=no' \
  'After=plymouth-start.service' \
  'Before=display-manager.service' \
  'Conflicts=shutdown.target' \
  'OnFailure=schweisos-boot-debug-fallback.service' \
  'Type=exec' \
  'ExecStart=/usr/lib/schweisos-live/plymouth-watchdog'; do
  grep -Fxq "$watchdog_contract" "$plymouth_watchdog_service" || \
    fail "Plymouth watchdog service contract is missing: ${watchdog_contract}"
done
grep -Fq 'marker=/run/schweisos-plymouth-normal-quit' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must honor the normal-handoff marker'
grep -Fq '/usr/bin/systemctl show \' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must query the quit handoff service'
grep -Fq '                --property=ActiveState \' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must inspect the quit service active state'
grep -Fq '                --property=Result \' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must inspect the quit service result'
grep -Fq '                --property=ExecMainStatus \' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must inspect the quit helper exit status'
grep -Fq '[[ "$quit_result" == success && "$quit_exit_status" == 0 ]]' \
  "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must accept only a successful normal quit handoff'
grep -Fq '[[ -e "$marker" ]] && continue' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must recheck an in-progress handoff after sleeping'
grep -Fxq '    /usr/bin/sleep 1' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must use the bounded one-second liveness interval'
grep -Fxq '    "$health"' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must invoke the daemon-health helper'
grep -Fq 'health_status=$?' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must preserve health-helper error status'
grep -Fxq '            exit "$health_status"' "$plymouth_watchdog" || \
  fail 'Plymouth watchdog must propagate unexpected health-helper errors'
[[ "$(grep -Fc 'exec /usr/bin/systemctl --no-block start schweisos-boot-debug-fallback.service' \
  "$plymouth_watchdog")" -eq 3 ]] || \
  fail 'Plymouth watchdog must reveal diagnostics after failed handoff states and a stopped daemon'

copied_brand_asset="$(find "$airootfs_dir" -type f \
  \( -name '*.png' -o -name '*.svg' -o -name '*.jpg' -o -name '*.jpeg' \) \
  -print -quit)"
[[ -z "$copied_brand_asset" ]] || \
  fail "branding asset copied into ISO profile instead of referenced from package: ${copied_brand_asset}"

for forbidden_path in \
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

watchdog_behavior_test="${project_root}/tests/test-plymouth-watchdog.sh"
[[ -x "$watchdog_behavior_test" && ! -L "$watchdog_behavior_test" ]] || \
  fail 'Plymouth watchdog behavior test is missing or unsafe'
"$watchdog_behavior_test" >/dev/null || \
  fail 'Plymouth watchdog behavior tests failed'

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
      && -f "${upstream_baseline}/mkinitcpio.d/linux.preset" \
      && -f "${upstream_baseline}/locale.conf" \
      && -L "${upstream_baseline}/localtime" ]]; then
  cmp -s "${airootfs_dir}/etc/mkinitcpio.d/linux.preset" \
    "${upstream_baseline}/mkinitcpio.d/linux.preset" || \
    fail 'linux.preset differs from the installed Archiso baseline'
  cmp -s "${airootfs_dir}/etc/locale.conf" "${upstream_baseline}/locale.conf" || \
    fail 'locale.conf differs from the installed Archiso baseline'
  [[ "$(readlink -- "${upstream_baseline}/localtime")" == "$(readlink -- "$localtime_link")" ]] || \
    fail 'localtime differs from the installed Archiso baseline'
  upstream_status='installed baseline matched except approved live boot and Plymouth extensions'
fi

git -C "$project_root" diff --check -- \
  docs/adr \
  docs/architecture/ADD.md \
  docs/ddr \
  docs/README.md \
  iso/profiles/kde \
  iso/README.md \
  packages/schweisos-branding/README.md \
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
