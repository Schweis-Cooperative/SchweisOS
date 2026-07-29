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

for tool in awk bash find git grep makepkg readlink sed sha256sum sort stat uniq; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
package_dir="${project_root}/packages/schweisos-calamares-config"
release_package_dir="${project_root}/packages/schweisos-release"
profile_packages="${project_root}/iso/profiles/kde/packages.x86_64"
adr="${project_root}/docs/adr/ADR-016-installer-architecture.md"
add_doc="${project_root}/docs/architecture/ADD.md"
installer_docs="${project_root}/docs/installer"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -rf -- "$tmp_dir"
}
trap cleanup EXIT

required_files=(
  "${package_dir}/PKGBUILD"
  "${package_dir}/README.md"
  "${package_dir}/settings.conf"
  "${package_dir}/branding.desc"
  "${package_dir}/finished.conf"
  "${package_dir}/fstab.conf"
  "${package_dir}/locale.conf"
  "${package_dir}/partition.conf"
  "${package_dir}/users.conf"
  "${package_dir}/welcome.conf"
  "${package_dir}/shellprocess-preflight.conf"
  "${package_dir}/shellprocess-pacstrap.conf"
  "${package_dir}/shellprocess-pacman.conf"
  "${package_dir}/shellprocess-systemd-boot.conf"
  "${package_dir}/shellprocess-services.conf"
  "${package_dir}/target-packages.x86_64"
  "${package_dir}/pacman.conf"
  "${package_dir}/schweisos-installer.desktop"
  "$adr"
  "${installer_docs}/README.md"
  "${installer_docs}/manual-installation-runbook.md"
  "${installer_docs}/recovery-runbook.md"
)

helper_sources=(
  "${package_dir}/schweisos-installer"
  "${package_dir}/schweisos-calamares-preflight"
  "${package_dir}/schweisos-calamares-pacstrap"
  "${package_dir}/schweisos-calamares-configure-pacman"
  "${package_dir}/schweisos-calamares-install-systemd-boot"
  "${package_dir}/schweisos-calamares-enable-services"
)

for required_file in "${required_files[@]}"; do
  [[ -f "$required_file" && ! -L "$required_file" ]] || \
    fail "missing or unsafe installer source: ${required_file}"
done
for helper_source in "${helper_sources[@]}"; do
  [[ -f "$helper_source" && ! -L "$helper_source" ]] || \
    fail "missing installer helper source: ${helper_source}"
  helper_mode="$(stat -c '%a' -- "$helper_source")"
  [[ "$helper_mode" == 644 ]] || \
    fail "installer helper sources must remain non-executable repository inputs: ${helper_source}:${helper_mode}"
done

bash -n "${helper_sources[@]}" "${package_dir}/PKGBUILD" "${BASH_SOURCE[0]}"

srcinfo="$(cd -- "$package_dir" && makepkg --printsrcinfo)"
release_srcinfo="$(cd -- "$release_package_dir" && makepkg --printsrcinfo)"
release_pkgver="$(awk -F ' = ' '$1 == "\tpkgver" { print $2; exit }' <<<"$release_srcinfo")"
[[ -n "$release_pkgver" ]] || fail 'schweisos-release package version is unreadable'

grep -Fxq 'pkgname = schweisos-calamares-config' <<<"$srcinfo" || \
  fail 'unexpected installer config package name'
grep -Fxq $'\tarch = any' <<<"$srcinfo" || \
  fail 'installer config package must be architecture independent'
grep -Fxq $'\turl = https://schweisos.org' <<<"$srcinfo" || \
  fail 'installer config package URL is not canonical'
for dependency in \
  arch-install-scripts bash calamares dosfstools efibootmgr e2fsprogs pacman \
  polkit schweisos-branding schweisos-keyring schweisos-mirrorlist \
  schweisos-pacman-config schweisos-release systemd; do
  grep -Fxq $'\tdepends = '"$dependency" <<<"$srcinfo" || \
    fail "installer config package dependency is missing: ${dependency}"
done
grep -Fxq $'\toptdepends = btrfs-progs: optional Btrfs target filesystem support' <<<"$srcinfo" || \
  fail 'installer config package must document optional Btrfs support'
grep -Fxq $'\toptdepends = schweisos-grub-theme: future installer-owned GRUB alternative theme' <<<"$srcinfo" || \
  fail 'installer config package must document future GRUB theme relationship'
! grep -Fq "'SKIP'" "${package_dir}/PKGBUILD" || \
  fail 'installer config package source checksums must not be skipped'
for helper_name in \
  schweisos-installer schweisos-calamares-preflight schweisos-calamares-pacstrap \
  schweisos-calamares-configure-pacman schweisos-calamares-install-systemd-boot \
  schweisos-calamares-enable-services; do
  grep -Fq "install -Dm755 \"\${srcdir}/${helper_name}\"" "${package_dir}/PKGBUILD" || \
    fail "installer helper must be installed executable by PKGBUILD: ${helper_name}"
done
! grep -Eq '(^|[[:space:]])(grub-install|grub-mkconfig)([[:space:]]|$)' \
  "${package_dir}/"*.conf "${package_dir}/schweisos-calamares-"* || \
  fail 'installer MVP must not activate GRUB'

grep -Fq 'branding: schweisos' "${package_dir}/settings.conf" || \
  fail 'Calamares settings must select SchweisOS branding'
grep -Fq "  version: \"${release_pkgver}\"" "${package_dir}/branding.desc" || \
  fail 'Calamares branding version must match schweisos-release pkgver'
grep -Fq "  shortVersion: \"${release_pkgver}\"" "${package_dir}/branding.desc" || \
  fail 'Calamares branding shortVersion must match schweisos-release pkgver'
grep -Fq "  versionedName: \"SchweisOS ${release_pkgver}\"" "${package_dir}/branding.desc" || \
  fail 'Calamares branding versionedName must match schweisos-release pkgver'
grep -Fq 'shellprocess@preflight' "${package_dir}/settings.conf" || \
  fail 'Calamares sequence must include preflight'
grep -Fq 'shellprocess@pacstrap' "${package_dir}/settings.conf" || \
  fail 'Calamares sequence must install packages through pacstrap'
grep -Fq 'shellprocess@systemd-boot' "${package_dir}/settings.conf" || \
  fail 'Calamares sequence must install systemd-boot'
! grep -Eq '^[[:space:]]*-[[:space:]]*(displaymanager|networkcfg)[[:space:]]*$' \
  "${package_dir}/settings.conf" || \
  fail 'SDDM and NetworkManager enablement must stay in the audited SchweisOS helper'
grep -Fq 'defaultFileSystemType: "ext4"' "${package_dir}/partition.conf" || \
  fail 'installer MVP must default to ext4'
grep -Fq '  - "btrfs"' "${package_dir}/partition.conf" || \
  fail 'installer MVP must expose Btrfs only as documented optional support'
grep -Fq 'efiSystemPartition: "/boot"' "${package_dir}/partition.conf" || \
  fail 'installer MVP must mount the EFI system partition at /boot'
grep -Fq 'efiSystemPartitionSize: 512MiB' "${package_dir}/partition.conf" || \
  fail 'installer MVP must use the documented ESP size'
grep -Fq 'region: "Etc"' "${package_dir}/locale.conf" || \
  fail 'installer locale baseline must remain neutral'
grep -Fq 'zone: "UTC"' "${package_dir}/locale.conf" || \
  fail 'installer timezone baseline must remain UTC'
grep -Fq '  style: none' "${package_dir}/locale.conf" || \
  fail 'installer must not use GeoIP timezone lookup in the MVP'

grep -R --line-number '@@ROOT@@' "$package_dir" && \
  fail 'Calamares configuration must use ${ROOT}, not legacy @@ROOT@@'
grep -R --line-number '\${ROOT}' "${package_dir}"/shellprocess-*.conf >/dev/null || \
  fail 'shellprocess modules must pass the Calamares target root'

grep -Fq 'pacstrap -K -C "$pacman_config" "$target_root"' \
  "${package_dir}/schweisos-calamares-pacstrap" || \
  fail 'installer must use pacstrap with the packaged pacman config'
grep -Fq 'Include = /etc/pacman.d/schweisos.conf' "${package_dir}/pacman.conf" || \
  fail 'installer pacstrap config must include SchweisOS repository snippet'
grep -Fq 'LocalFileSigLevel = Required' "${package_dir}/pacman.conf" || \
  fail 'installer pacstrap config must require signatures for local package files'
! grep -Eq 'SigLevel[[:space:]]*=[^#]*(Never|TrustAll)' "${package_dir}/pacman.conf" || \
  fail 'installer pacstrap config must not weaken signature trust'
grep -Fq "include_line='Include = /etc/pacman.d/schweisos.conf'" \
  "${package_dir}/schweisos-calamares-configure-pacman" || \
  fail 'installer must enable the SchweisOS repository in target pacman.conf'
grep -Fq 'bootctl install' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'installer MVP must install systemd-boot through bootctl'
grep -Fq 'root=UUID=${root_uuid}' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'systemd-boot entry must bind to the installed root UUID'
grep -Fq 'mkinitcpio -P' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'installer must regenerate target initramfs'
grep -Fq 'systemctl enable NetworkManager.service' "${package_dir}/schweisos-calamares-enable-services" || \
  fail 'installer must enable NetworkManager in the target'
grep -Fq 'systemctl enable sddm.service' "${package_dir}/schweisos-calamares-enable-services" || \
  fail 'installer must enable SDDM in the target'
grep -Fq 'Exec=schweisos-installer' "${package_dir}/schweisos-installer.desktop" || \
  fail 'desktop launcher must use the packaged installer wrapper'

sed 's/[[:space:]]*#.*$//' "${package_dir}/target-packages.x86_64" \
  | awk 'NF { print }' >"${tmp_dir}/target-packages.normalized"
sort "${tmp_dir}/target-packages.normalized" >"${tmp_dir}/target-packages.sorted"
duplicates="$(uniq -d "${tmp_dir}/target-packages.sorted")"
[[ -z "$duplicates" ]] || fail "duplicate target package entries: ${duplicates}"
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
' "${package_dir}/target-packages.x86_64"; then
  fail 'target package entries must be sorted within each documented group'
fi

for target_package in \
  base btrfs-progs dosfstools e2fsprogs efibootmgr linux linux-firmware \
  networkmanager plasma-desktop sddm sudo \
  schweisos-branding schweisos-keyring schweisos-mirrorlist \
  schweisos-pacman-config schweisos-release; do
  grep -Fxq "$target_package" "${tmp_dir}/target-packages.normalized" || \
    fail "required target package is missing: ${target_package}"
done
for forbidden_target_package in calamares schweisos-calamares-config mkinitcpio-archiso plymouth; do
  ! grep -Fxq "$forbidden_target_package" "${tmp_dir}/target-packages.normalized" || \
    fail "live-only package must not be installed to target: ${forbidden_target_package}"
done

for live_package in \
  arch-install-scripts btrfs-progs calamares dosfstools efibootmgr \
  schweisos-calamares-config; do
  grep -Fxq "$live_package" "$profile_packages" || \
    fail "installer live package is missing from ISO profile: ${live_package}"
done

grep -Fq 'ADR-016 Installer Architecture' "${project_root}/docs/adr/README.md" || \
  fail 'ADR index must reference ADR-016'
grep -Fq 'schweisos-calamares-config' "$add_doc" || \
  fail 'ADD must document installer package ownership'
grep -Fq 'Manual Installation Runbook' "${installer_docs}/README.md" || \
  fail 'installer README must link the manual installation runbook'
grep -Fq 'Recovery Runbook' "${installer_docs}/README.md" || \
  fail 'installer README must link the recovery runbook'

private_key_armored_marker='BEGIN PGP'' PRIVATE KEY BLOCK'
if grep -RInE "private-keys-v1.d|openpgp-revocs.d|${private_key_armored_marker}|passphrase|password[[:space:]]*=" "$package_dir" "$installer_docs" "$adr"; then
  fail 'installer sources must not contain private key material or credential patterns'
fi

git -C "$project_root" diff --check -- \
  docs/adr/ADR-016-installer-architecture.md \
  docs/architecture/ADD.md \
  docs/installer \
  iso/profiles/kde \
  packages/schweisos-calamares-config \
  tests/validate-installer-config.sh

printf 'Installer configuration validation passed.\n'
printf '  package: schweisos-calamares-config\n'
printf '  installer: Calamares configuration packaged separately\n'
printf '  target install: pacstrap from signed Arch and SchweisOS repositories\n'
printf '  bootloader: UEFI systemd-boot MVP\n'
