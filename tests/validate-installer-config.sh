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

for tool in awk bash desktop-file-validate find git grep makepkg readlink sed \
  sha256sum sort stat uniq; do
  require_tool "$tool"
done

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
package_dir="${project_root}/packages/schweisos-calamares-config"
calamares_package_dir="${project_root}/packages/calamares"
calamares_live_media_patch="${calamares_package_dir}/schweisos-filter-live-media-devices.patch"
release_package_dir="${project_root}/packages/schweisos-release"
profile_packages="${project_root}/iso/profiles/kde/packages.x86_64"
profile_airootfs="${project_root}/iso/profiles/kde/airootfs"
live_profile_marker="${profile_airootfs}/usr/lib/schweisos-live/session"
adr="${project_root}/docs/adr/ADR-016-installer-architecture.md"
ddr="${project_root}/docs/ddr/DDR-002-installer-experience.md"
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
  "${package_dir}/show.qml"
  "${package_dir}/welcomeq.qml"
  "${package_dir}/finished.conf"
  "${package_dir}/fstab.conf"
  "${package_dir}/locale.conf"
  "${package_dir}/packagechooser-profile.conf"
  "${package_dir}/packagechooser-kernel.conf"
  "${package_dir}/packagechooser-extras.conf"
  "${package_dir}/partition.conf"
  "${package_dir}/unpackfs.conf"
  "${package_dir}/users.conf"
  "${package_dir}/welcomeq.conf"
  "${package_dir}/shellprocess-preflight.conf"
  "${package_dir}/shellprocess-reconcile.conf"
  "${package_dir}/shellprocess-pacman.conf"
  "${package_dir}/shellprocess-systemd-boot.conf"
  "${package_dir}/shellprocess-services.conf"
  "${package_dir}/target-packages.x86_64"
  "${package_dir}/schweisos-installer.desktop"
  "${package_dir}/schweisos-installer-autostart.desktop"
  "${package_dir}/org.schweisos.installer.policy"
  "$live_profile_marker"
  "${calamares_package_dir}/PKGBUILD"
  "$adr"
  "$ddr"
  "${installer_docs}/README.md"
  "${installer_docs}/manual-installation-runbook.md"
  "${installer_docs}/recovery-runbook.md"
  "$calamares_live_media_patch"
)

helper_sources=(
  "${package_dir}/schweisos-installer"
  "${package_dir}/schweisos-installer-root"
  "${package_dir}/schweisos-installer-autostart"
  "${package_dir}/schweisos-installer-live-session"
  "${package_dir}/schweisos-calamares-network-status"
  "${package_dir}/schweisos-calamares-preflight"
  "${package_dir}/schweisos-calamares-reconcile-target"
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
desktop-file-validate "${package_dir}/schweisos-installer.desktop"
desktop-file-validate "${package_dir}/schweisos-installer-autostart.desktop"

if ! (cd -- "$package_dir" && makepkg --verifysource >/dev/null); then
  fail 'installer config package source checksums do not verify'
fi
srcinfo="$(cd -- "$package_dir" && makepkg --printsrcinfo)"
calamares_srcinfo="$(cd -- "$calamares_package_dir" && makepkg --printsrcinfo)"
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
  arch-install-scripts bash calamares curl dosfstools efibootmgr e2fsprogs \
  iproute2 kdialog networkmanager pacman polkit schweisos-branding schweisos-keyring schweisos-mirrorlist \
  schweisos-pacman-config schweisos-release systemd tzdata util-linux xorg-xwayland; do
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
  schweisos-installer schweisos-calamares-preflight schweisos-calamares-reconcile-target \
  schweisos-calamares-configure-pacman schweisos-calamares-install-systemd-boot \
  schweisos-calamares-enable-services schweisos-calamares-network-status; do
  grep -Fq "install -Dm755 \"\${srcdir}/${helper_name}\"" "${package_dir}/PKGBUILD" || \
    fail "installer helper must be installed executable by PKGBUILD: ${helper_name}"
done
grep -Fq 'install -Dm755 "${srcdir}/schweisos-installer-root"' "${package_dir}/PKGBUILD" || \
  fail 'exact-path privileged installer helper must be installed executable'
grep -Fq '"${pkgdir}/usr/lib/schweisos-calamares/launch-root"' "${package_dir}/PKGBUILD" || \
  fail 'privileged installer helper must use its policy-bound runtime path'
grep -Fq 'install -Dm755 "${srcdir}/schweisos-installer-autostart"' "${package_dir}/PKGBUILD" || \
  fail 'installer autostart helper must be installed executable'
grep -Fq 'install -Dm755 "${srcdir}/schweisos-installer-live-session"' \
  "${package_dir}/PKGBUILD" || fail 'installer live-session helper must be installed executable'
grep -Fq '"${pkgdir}/usr/lib/schweisos-calamares/is-live-session"' \
  "${package_dir}/PKGBUILD" || fail 'installer live-session helper path is not packaged'
grep -Fq '"${pkgdir}/etc/xdg/autostart/schweisos-installer-autostart.desktop"' \
  "${package_dir}/PKGBUILD" || fail 'installer XDG autostart entry is not packaged'
grep -Fq '"${pkgdir}/usr/share/polkit-1/actions/org.schweisos.installer.policy"' \
  "${package_dir}/PKGBUILD" || fail 'installer Polkit action is not packaged'

grep -Fxq 'pkgname = calamares' <<<"$calamares_srcinfo" || \
  fail 'unexpected Calamares package source name'
grep -Fxq $'\tsource = calamares-3.4.2.tar.gz::https://codeberg.org/Calamares/calamares/releases/download/v3.4.2/calamares-3.4.2.tar.gz' \
  <<<"$calamares_srcinfo" || fail 'Calamares package must use the reviewed upstream release tarball'
grep -Fxq $'\tsource = schweisos-filter-live-media-devices.patch' <<<"$calamares_srcinfo" || \
  fail 'Calamares package must carry the SchweisOS live-media target filter patch'
grep -Fxq $'\tsha256sums = 733bbbb00dc9f84874bd5c22960952f317ea2537565431179fa2152b2fbfdccc' \
  <<<"$calamares_srcinfo" || fail 'Calamares upstream release tarball checksum changed unexpectedly'
calamares_patch_checksum_expected="$(
  awk -F ' = ' '$1 == "\tsha256sums" { count++; if (count == 2) { print $2; exit } }' \
    <<<"$calamares_srcinfo"
)"
calamares_patch_checksum_actual="$(sha256sum -- "$calamares_live_media_patch")"
calamares_patch_checksum_actual="${calamares_patch_checksum_actual%% *}"
[[ -n "$calamares_patch_checksum_expected" \
    && "$calamares_patch_checksum_expected" == "$calamares_patch_checksum_actual" ]] || \
  fail 'Calamares live-media target filter patch checksum does not match PKGBUILD'
grep -Fq 'patch -Np1 -i "${srcdir}/schweisos-filter-live-media-devices.patch"' \
  "${calamares_package_dir}/PKGBUILD" || \
  fail 'Calamares package must apply the live-media target filter patch in prepare()'
for patch_fragment in \
  'schweisosLiveMediaDevices' \
  '/usr/lib/schweisos-live/session' \
  'img_dev|archisodevice' \
  '/run/archiso/img_dev' \
  '/run/archiso/bootmnt' \
  'lsblk' \
  'Removing SchweisOS live boot media device'; do
  grep -Fq "$patch_fragment" "$calamares_live_media_patch" || \
    fail "Calamares live-media target filter patch is missing: ${patch_fragment}"
done
grep -Fq 'upstream_launcher="${pkgdir}/usr/share/applications/calamares.desktop"' \
  "${calamares_package_dir}/PKGBUILD" || \
  fail 'Calamares package must identify the generic launcher by exact path'
grep -Fq 'unlink -- "$upstream_launcher"' "${calamares_package_dir}/PKGBUILD" || \
  fail 'Calamares package must omit the generic Install System launcher'
! grep -Eq 'rm[[:space:]]+-[[:alnum:]]*f' "${calamares_package_dir}/PKGBUILD" || \
  fail 'Calamares launcher omission must not use a force flag'
if grep -E 'SKIP_MODULES=' "${calamares_package_dir}/PKGBUILD" | grep -Eq '(^|;)packagechooser(;|$)'; then
  fail 'Calamares package must build the upstream packagechooser module'
fi
if grep -E 'SKIP_MODULES=' "${calamares_package_dir}/PKGBUILD" | grep -Eq '(^|;)packagechooserq(;|$)'; then
  fail 'Calamares package must build the upstream packagechooserq module for SchweisOS QML selection pages'
fi
grep -Eq "^[[:space:]]*'rsync'[[:space:]]*$" "${calamares_package_dir}/PKGBUILD" || \
  fail 'Calamares package must declare rsync for the unpackfs file-copy path'
[[ ! -e "${profile_airootfs}/usr/local/share/applications/calamares.desktop" \
    && ! -L "${profile_airootfs}/usr/local/share/applications/calamares.desktop" ]] || \
  fail 'the ISO profile must not retain a second-layer Calamares launcher mask'
! grep -Eq '(^|[[:space:]])(grub-install|grub-mkconfig)([[:space:]]|$)' \
  "${package_dir}/"*.conf "${package_dir}/schweisos-calamares-"* || \
  fail 'installer MVP must not activate GRUB'

grep -Fq 'branding: schweisos' "${package_dir}/settings.conf" || \
  fail 'Calamares settings must select SchweisOS branding'
grep -Fq "'show.qml'" "${package_dir}/PKGBUILD" || \
  fail 'Calamares slideshow QML resource must be a package source'
grep -Fq 'install -Dm644 "${srcdir}/show.qml"' "${package_dir}/PKGBUILD" || \
  fail 'Calamares slideshow QML resource must be package-owned'
grep -Fq '"${pkgdir}/etc/calamares/branding/schweisos/show.qml"' \
  "${package_dir}/PKGBUILD" || fail 'Calamares slideshow QML resource must be installed beside branding.desc'
grep -Fq '"${pkgdir}/etc/calamares/branding/schweisos/welcomeq.qml"' \
  "${package_dir}/PKGBUILD" || fail 'custom welcome QML must be installed in the branding directory'
grep -Fq '"${pkgdir}/etc/calamares/modules/welcomeq.conf"' \
  "${package_dir}/PKGBUILD" || fail 'custom welcome configuration must be package-owned'
grep -Fq "  version: \"${release_pkgver}\"" "${package_dir}/branding.desc" || \
  fail 'Calamares branding version must match schweisos-release pkgver'
grep -Fq "  shortVersion: \"${release_pkgver}\"" "${package_dir}/branding.desc" || \
  fail 'Calamares branding shortVersion must match schweisos-release pkgver'
grep -Fq "  versionedName: \"SchweisOS ${release_pkgver}\"" "${package_dir}/branding.desc" || \
  fail 'Calamares branding versionedName must match schweisos-release pkgver'
grep -Fq 'shellprocess@preflight' "${package_dir}/settings.conf" || \
  fail 'Calamares sequence must include preflight'
for required_sequence in \
  welcomeq packagechooser@profile packagechooser@kernel packagechooser@extras \
  unpackfs shellprocess@reconcile; do
  grep -Fq -- "- ${required_sequence}" "${package_dir}/settings.conf" || \
    fail "Calamares sequence is missing: ${required_sequence}"
done
! grep -Fq 'packagechooser@browser' "${package_dir}/settings.conf" || \
  fail 'browser selection must not be a separate installer page in Phase 1'
! grep -Fq 'packagechooser@desktop' "${package_dir}/settings.conf" || \
  fail 'desktop-environment selection must not be exposed before non-KDE payloads are qualified'
grep -Fq 'shellprocess@systemd-boot' "${package_dir}/settings.conf" || \
  fail 'Calamares sequence must install systemd-boot'
! grep -Eq '^[[:space:]]*-[[:space:]]*(displaymanager|networkcfg)[[:space:]]*$' \
  "${package_dir}/settings.conf" || \
  fail 'SDDM and NetworkManager enablement must stay in the audited SchweisOS helper'
grep -Fq 'defaultFileSystemType: "ext4"' "${package_dir}/partition.conf" || \
  fail 'installer MVP must default to ext4'
grep -Fq '  - "btrfs"' "${package_dir}/partition.conf" || \
  fail 'installer MVP must expose Btrfs only as documented optional support'
grep -Fq '  mountPoint: "/boot"' "${package_dir}/partition.conf" || \
  fail 'installer MVP must mount the EFI system partition at /boot'
grep -Fq '  recommendedSize: 512MiB' "${package_dir}/partition.conf" || \
  fail 'installer MVP must use the documented ESP size'
grep -Fxq 'requiredPartitionTableType: gpt' "${package_dir}/partition.conf" || \
  fail 'installer MVP must constrain the target partition table to GPT'
grep -Fxq 'enableLuksAutomatedPartitioning: false' "${package_dir}/partition.conf" || \
  fail 'installer MVP must not expose unsupported automated encryption'
grep -A1 -Fxq 'lvm:' "${package_dir}/partition.conf" || \
  fail 'installer partition policy must explicitly configure LVM'
grep -A1 -Fx 'lvm:' "${package_dir}/partition.conf" | grep -Fxq '  enable: false' || \
  fail 'installer MVP must not expose unsupported LVM'
grep -Fq 'region: "Etc"' "${package_dir}/locale.conf" || \
  fail 'installer locale baseline must remain neutral'
grep -Fq 'zone: "UTC"' "${package_dir}/locale.conf" || \
  fail 'installer timezone baseline must remain UTC'
grep -Fq '  style: none' "${package_dir}/locale.conf" || \
  fail 'installer must not use GeoIP timezone lookup in the MVP'

grep -R --line-number '@@ROOT@@' "$package_dir" && \
  fail 'Calamares configuration must use ${ROOT}, not legacy @@ROOT@@'
! grep -Fq '${ROOT}' "${package_dir}/shellprocess-preflight.conf" || \
  fail 'pre-mount Calamares preflight must not consume ${ROOT}'
grep -Fq 'target root is not available before Calamares mount' \
  "${package_dir}/schweisos-calamares-preflight" || \
  fail 'preflight helper must reject accidental target-root arguments'
for mounted_shellprocess in reconcile pacman systemd-boot services; do
  grep -Fq '${ROOT}' "${package_dir}/shellprocess-${mounted_shellprocess}.conf" || \
    fail "post-mount shellprocess must pass the Calamares target root: ${mounted_shellprocess}"
done

for chooser in profile kernel extras; do
  grep -Fxq 'method: legacy' "${package_dir}/packagechooser-${chooser}.conf" || \
    fail "package chooser must use the audited legacy GlobalStorage contract: ${chooser}"
done
grep -Fxq 'mode: required' "${package_dir}/packagechooser-profile.conf" || \
  fail 'installation profile chooser must require exactly one selection'
grep -Fxq 'default: privacy' "${package_dir}/packagechooser-profile.conf" || \
  fail 'Privacy must remain the recommended Phase 1 installation profile'
for profile_id in privacy gaming developer creator office minimal; do
  grep -Fq "  - id: ${profile_id}" "${package_dir}/packagechooser-profile.conf" || \
    fail "installation profile chooser is missing: ${profile_id}"
done
grep -Fxq 'mode: required' "${package_dir}/packagechooser-kernel.conf" || \
  fail 'kernel chooser must require exactly one selection'
grep -Fxq 'default: linux-zen' "${package_dir}/packagechooser-kernel.conf" || \
  fail 'linux-zen must be the recommended default kernel'
grep -Fxq 'mode: optionalmultiple' "${package_dir}/packagechooser-extras.conf" || \
  fail 'optional feature chooser must allow zero or more selections'
for chooser in profile kernel extras; do
  if grep -Fq 'screenshot:' "${package_dir}/packagechooser-${chooser}.conf"; then
    fail "package chooser must not reuse the logo as generic selection artwork: ${chooser}"
  fi
done
for package_description in \
  'Packages: firewalld, plasma-firewall.' \
  'Packages: gamemode, mangohud, lutris.' \
  'Packages: git, cmake, ninja.' \
  'Packages: pacman-contrib, reflector.' \
  'Package: linux-zen.'; do
  grep -Fq "$package_description" \
    "${package_dir}/packagechooser-extras.conf" \
    "${package_dir}/packagechooser-kernel.conf" || \
    fail "installer package chooser omits package-level description: ${package_description}"
done
grep -Fq 'source: "/run/archiso/airootfs/"' "${package_dir}/unpackfs.conf" || \
  fail 'unpackfs must copy the mounted, validated Archiso root'
grep -Fq 'sourcefs: "file"' "${package_dir}/unpackfs.conf" || \
  fail 'unpackfs must treat the mounted Archiso root as a directory payload'
! grep -Fq '${gs[packagechooser_browser]}' "${package_dir}/shellprocess-reconcile.conf" || \
  fail 'reconciliation must not depend on a removed browser GlobalStorage key'
grep -Fq '/usr/lib/schweisos-calamares/reconcile-target ${ROOT} firefox ${gs[packagechooser_kernel]} ${gs[packagechooser_profile]} ${gs[packagechooser_extras]}' \
  "${package_dir}/shellprocess-reconcile.conf" || \
  fail 'reconciliation must pass the fixed Phase 1 Firefox browser contract'
for selection_key in packagechooser_profile packagechooser_kernel packagechooser_extras; do
  grep -Fq "\${gs[${selection_key}]}" "${package_dir}/shellprocess-reconcile.conf" || \
    fail "reconciliation shellprocess is missing GlobalStorage selection: ${selection_key}"
done
for reconciliation_fragment in \
  'firefox) ;;' \
  'linux|linux-lts|linux-zen|linux-hardened' \
  'declare -Ar profile_features=' \
  "[privacy]='security,maintenance,x11-compatibility'" \
  'PROFILE=%s' \
  'arch-install-scripts' \
  'schweisos-calamares-config' \
  'pacman -Rns --noconfirm' \
  "[x11-compatibility]='xorg-xwayland'" \
  'pacman -D --asexplicit' \
  '/usr/lib/schweisos-live' \
  'selection.conf' \
  'PAYLOAD=archiso-airootfs'; do
  grep -Fq "$reconciliation_fragment" \
    "${package_dir}/schweisos-calamares-reconcile-target" || \
    fail "target reconciliation contract is missing: ${reconciliation_fragment}"
done
grep -Fq "include_line='Include = /etc/pacman.d/schweisos.conf'" \
  "${package_dir}/schweisos-calamares-configure-pacman" || \
  fail 'installer must enable the SchweisOS repository in target pacman.conf'
grep -Fq 'bootctl install' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'installer MVP must install systemd-boot through bootctl'
grep -Fq 'root=UUID=${root_uuid}' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'systemd-boot entry must bind to the installed root UUID'
grep -Fq 'linux   /vmlinuz-${kernel}' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'systemd-boot entry must use the selected kernel'
grep -Fq 'initrd  /initramfs-${kernel}.img' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'systemd-boot entry must use the selected initramfs'
grep -Fq 'mkinitcpio -P' "${package_dir}/schweisos-calamares-install-systemd-boot" || \
  fail 'installer must regenerate target initramfs'
grep -Fq 'systemctl enable NetworkManager.service' "${package_dir}/schweisos-calamares-enable-services" || \
  fail 'installer must enable NetworkManager in the target'
grep -Fq 'systemctl enable sddm.service' "${package_dir}/schweisos-calamares-enable-services" || \
  fail 'installer must enable SDDM in the target'
grep -Fxq 'Name=Install SchweisOS' "${package_dir}/schweisos-installer.desktop" || \
  fail 'desktop launcher must use the SchweisOS product name'
grep -Fxq 'Exec=/usr/bin/schweisos-installer' "${package_dir}/schweisos-installer.desktop" || \
  fail 'desktop launcher must use the packaged installer wrapper'
grep -Fxq 'Icon=schweisos' "${package_dir}/schweisos-installer.desktop" || \
  fail 'desktop launcher must use the canonical SchweisOS icon name'
grep -Fxq 'StartupNotify=true' "${package_dir}/schweisos-installer.desktop" || \
  fail 'desktop launcher must expose startup feedback'

for autostart_fragment in \
  'Exec=/usr/lib/schweisos-calamares/autostart' \
  'NoDisplay=true' \
  'OnlyShowIn=KDE;'; do
  grep -Fxq "$autostart_fragment" "${package_dir}/schweisos-installer-autostart.desktop" || \
    fail "installer autostart entry is missing: ${autostart_fragment}"
done
for autostart_source_fragment in \
  '/usr/lib/schweisos-calamares/is-live-session' \
  '/usr/bin/sleep 3' \
  'autostart-attempted' \
  'report_autostart_failure' \
  '! -L "$autostart_marker"' \
  '"${installer_state}/launched"' \
  '/usr/bin/schweisos-installer'; do
  grep -Fq -- "$autostart_source_fragment" "${package_dir}/schweisos-installer-autostart" || \
    fail "installer once-only autostart contract is missing: ${autostart_source_fragment}"
done
for launcher_fragment in \
  '/usr/lib/schweisos-calamares/is-live-session' \
  '/sys/firmware/efi' \
  'XAUTHORITY' \
  '/usr/bin/flock -n' \
  '/usr/bin/chmod 0600' \
  'launch.log' \
  '/usr/bin/kdialog' \
  '/usr/bin/pkexec /usr/lib/schweisos-calamares/launch-root'; do
  grep -Fq "$launcher_fragment" "${package_dir}/schweisos-installer" || \
    fail "installer guarded launcher contract is missing: ${launcher_fragment}"
done
live_session_helper="${package_dir}/schweisos-installer-live-session"
for live_session_fragment in \
  '/usr/bin/id -un' \
  '/usr/lib/schweisos-live/session' \
  'SCHWEISOS_LIVE_SESSION=1' \
  '/usr/bin/stat -c %s' \
  '/usr/bin/mountpoint -q "$1"' \
  'mountpoint_is_mounted /run/archiso/airootfs' \
  '/proc/cmdline' \
  'archisobasedir=schweis'; do
  grep -Fq "$live_session_fragment" "$live_session_helper" || \
    fail "installer live-session predicate is missing: ${live_session_fragment}"
done
if grep -Fq '/run/archiso/bootmnt' \
    "${package_dir}/schweisos-installer" \
    "${package_dir}/schweisos-installer-autostart" \
    "$live_session_helper"; then
  fail 'installer launch policy must not depend on transient Archiso bootmnt'
fi
grep -Fxq 'SCHWEISOS_LIVE_SESSION=1' "$live_profile_marker" || \
  fail 'live profile marker does not match the installer predicate'
for autostart_failure_fragment in \
  'current_user 2>/dev/null' \
  'Automatic installer start was blocked.' \
  'report_autostart_failure'; do
  grep -Fq "$autostart_failure_fragment" \
    "${package_dir}/schweisos-installer-autostart" || \
    fail "installer autostart hides a live-session failure: ${autostart_failure_fragment}"
done
for privileged_fragment in \
  'if (( $# != 0 ))' \
  'unset LD_LIBRARY_PATH LD_PRELOAD' \
  'export QT_QPA_PLATFORM=xcb' \
  'exec /usr/bin/calamares -D6'; do
  grep -Fq "$privileged_fragment" "${package_dir}/schweisos-installer-root" || \
    fail "installer privileged bridge is missing: ${privileged_fragment}"
done
grep -Fq '/usr/lib/schweisos-calamares/network-status --watch 90 3' \
  "${package_dir}/schweisos-installer-root" || \
  fail 'privileged installer launcher does not refresh SchweisOS network status after Calamares starts'
for policy_fragment in \
  '<action id="org.schweisos.installer.launch">' \
  '<annotate key="org.freedesktop.policykit.exec.path">/usr/lib/schweisos-calamares/launch-root</annotate>' \
  '<annotate key="org.freedesktop.policykit.exec.allow_gui">true</annotate>'; do
  grep -Fq "$policy_fragment" "${package_dir}/org.schweisos.installer.policy" || \
    fail "installer Polkit policy is missing: ${policy_fragment}"
done
for branding_fragment in \
  'productLogo: "/usr/share/schweisos/branding/schweisos.png"' \
  'productIcon: "/usr/share/schweisos/branding/schweisos.png"' \
  'slideshow: "show.qml"' \
  'SidebarBackground: "#051022"' \
  'SidebarTextCurrent: "#ffffff"'; do
  grep -Fq "$branding_fragment" "${package_dir}/branding.desc" || \
    fail "Calamares branding contract is missing: ${branding_fragment}"
done
! grep -Fq 'productWelcome:' "${package_dir}/branding.desc" || \
  fail 'Calamares welcome page must not display the large centered productWelcome logo'
! grep -Fq 'productBanner:' "${package_dir}/branding.desc" || \
  fail 'text-first welcome must not render a product banner'
grep -Fq 'readonly property string maintainerName: "Marijua"' "${package_dir}/show.qml" || \
  fail 'Calamares slideshow must expose the project maintainer identity'
grep -Fq 'Project Maintainer' "${package_dir}/show.qml" || \
  fail 'Calamares slideshow must label Marijua as maintainer, not contributor'
! grep -Fq 'Contributor' "${package_dir}/show.qml" || \
  fail 'Calamares slideshow must not mislabel the maintainer as a contributor'
grep -Fq 'Welcome to SchweisOS' "${package_dir}/show.qml" || \
  fail 'Calamares slideshow must include the SchweisOS welcome message'
for welcome_fragment in \
  'Welcome to SchweisOS' \
  'Offline installation is fully available.' \
  'Maintained by Marijua' \
  'schweisosInternetAvailable' \
  'file:///run/schweisos-installer/network-state' \
  'Network.hasInternet' \
  'config.languagesModel'; do
  grep -Fq "$welcome_fragment" "${package_dir}/welcomeq.qml" || \
    fail "custom installer welcome is missing: ${welcome_fragment}"
done
for network_fragment in \
  'https://schweisos.org/' \
  'https://archlinux.org/' \
  'ip route get 1.1.1.1' \
  'nmcli -t -f CONNECTIVITY general' \
  'networkmanager_reports_full_connectivity' \
  'watch_network "$watch_seconds" "$interval"' \
  'write_state connected https-probe' \
  'write_state connected networkmanager-connectivity nmcli' \
  'write_state offline https-probe-failed'; do
  grep -Fq "$network_fragment" "${package_dir}/schweisos-calamares-network-status" || \
    fail "installer network detector is missing: ${network_fragment}"
done
! grep -Eq 'Image[[:space:]]*\{' "${package_dir}/welcomeq.qml" || \
  fail 'text-first welcome must not contain a centered logo image'
! grep -Eq '^[[:space:]]+(sidebarBackground|sidebarText|sidebarTextSelect):' \
  "${package_dir}/branding.desc" || fail 'Calamares branding uses invalid case-sensitive style keys'
for required_welcome_condition in storage ram root; do
  grep -A5 '^[[:space:]]*required:' "${package_dir}/welcomeq.conf" \
    | grep -Fxq "    - ${required_welcome_condition}" || \
    fail "installer welcome gate is not required: ${required_welcome_condition}"
done
if grep -A8 '^[[:space:]]*required:' "${package_dir}/welcomeq.conf" \
    | grep -Fxq '    - internet'; then
  fail 'installer welcome gate must not require internet access'
fi
grep -A10 '^[[:space:]]*check:' "${package_dir}/welcomeq.conf" \
  | grep -Fxq '    - internet' || \
  fail 'installer welcome must expose informative network state'
grep -Fxq '  internetCheckUrl: "https://schweisos.org/"' \
  "${package_dir}/welcomeq.conf" || \
  fail 'installer network probe must use the privacy-bounded SchweisOS endpoint'
grep -Fxq 'qmlSearch: branding' "${package_dir}/welcomeq.conf" || \
  fail 'welcomeq must load only the package-owned branding implementation'

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
  base btrfs-progs dosfstools e2fsprogs efibootmgr linux-firmware \
  networkmanager plasma-desktop sddm sudo tzdata \
  schweisos-branding schweisos-keyring schweisos-mirrorlist \
  schweisos-pacman-config schweisos-release; do
  grep -Fxq "$target_package" "${tmp_dir}/target-packages.normalized" || \
    fail "required target package is missing: ${target_package}"
done
for dynamic_target_package in \
  firefox chromium falkon linux linux-lts linux-zen linux-hardened \
  distrobox podman firewalld plasma-firewall xorg-xwayland; do
  ! grep -Fxq "$dynamic_target_package" "${tmp_dir}/target-packages.normalized" || \
    fail "dynamic target package must be owned by the fixed selection or a chooser: ${dynamic_target_package}"
done
for forbidden_target_package in calamares schweisos-calamares-config mkinitcpio-archiso plymouth; do
  ! grep -Fxq "$forbidden_target_package" "${tmp_dir}/target-packages.normalized" || \
    fail "live-only package must not be installed to target: ${forbidden_target_package}"
done

for live_package in \
  arch-install-scripts btrfs-progs calamares dosfstools efibootmgr \
  schweisos-calamares-config firefox linux linux-lts linux-zen \
  linux-hardened firewalld plasma-firewall distrobox podman xorg-xwayland; do
  grep -Fxq "$live_package" "$profile_packages" || \
    fail "installer live package is missing from ISO profile: ${live_package}"
done
for forbidden_live_package in chromium falkon; do
  ! grep -Fxq "$forbidden_live_package" "$profile_packages" || \
    fail "unsupported browser must not be part of the Phase 1 ISO payload: ${forbidden_live_package}"
done

grep -Fq 'ADR-016 Installer Architecture' "${project_root}/docs/adr/README.md" || \
  fail 'ADR index must reference ADR-016'
grep -Fq 'DDR-002 Installer Experience' "${project_root}/docs/ddr/README.md" || \
  fail 'DDR index must reference DDR-002'
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
  docs/ddr \
  docs/installer \
  iso/profiles/kde \
  packages/calamares \
  packages/schweisos-calamares-config \
  tests/test-installer-experience.sh \
  tests/validate-installer-config.sh

"${project_root}/tests/test-installer-experience.sh"
bash "${project_root}/tests/test-installer-reconciliation.sh"

printf 'Installer configuration validation passed.\n'
printf '  package: schweisos-calamares-config\n'
printf '  installer: Calamares configuration packaged separately\n'
printf '  target install: offline unpackfs payload with fail-closed reconciliation\n'
printf '  bootloader: UEFI systemd-boot MVP\n'
