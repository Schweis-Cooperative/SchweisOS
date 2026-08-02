#!/usr/bin/bash
# SPDX-License-Identifier: GPL-3.0-or-later

# Validate the staged live root that mkarchiso has populated before it is
# compressed into SquashFS. This is intentionally a runtime-payload validator:
# it checks installed paths, pacman ownership records, permissions, desktop
# entries, Calamares branding resources, and launcher bridge files in the
# actual root filesystem tree that the live ISO will consume.
set -euo pipefail

export LC_ALL=C
export PATH=/usr/bin:/bin

fail() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

usage() {
    printf 'Usage: %s [ROOTFS]\n' "${0##*/}" >&2
}

for tool in awk bash desktop-file-validate find git grep readlink sort stat; do
    type -P "$tool" >/dev/null 2>&1 || fail "required tool not found: $tool"
done

if (( $# > 1 )); then
    usage
    exit 2
fi

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
project_root="$(cd -- "${script_dir}/.." && pwd -P)"
git_root="$(git -C "$project_root" rev-parse --show-toplevel 2>/dev/null)" || \
    fail 'repository root is unavailable'
git_root="$(cd -- "$git_root" && pwd -P)"
[[ "$git_root" == "$project_root" ]] || fail 'validator is not running from the repository root'

rootfs="${1:-${project_root}/work/iso/kde/x86_64/airootfs}"
rootfs="$(readlink -f -- "$rootfs" 2>/dev/null || true)"
[[ -n "$rootfs" && "$rootfs" != / && -d "$rootfs" && ! -L "$rootfs" ]] || \
    fail 'staged rootfs is missing or unsafe'

relative_file() {
    local relative_path=$1
    local path="${rootfs}/${relative_path}"
    [[ -f "$path" && ! -L "$path" ]] || fail "missing runtime file: ${relative_path}"
    printf '%s\n' "$path"
}

require_mode() {
    local path=$1
    local expected_mode=$2
    local actual_mode
    actual_mode="$(stat -c %a -- "$path")" || fail "cannot stat ${path#"$rootfs"/}"
    [[ "$actual_mode" == "$expected_mode" ]] || \
        fail "${path#"$rootfs"/} has mode ${actual_mode}; expected ${expected_mode}"
}

require_contains() {
    local path=$1
    local fragment=$2
    grep -Fq -- "$fragment" "$path" || \
        fail "${path#"$rootfs"/} is missing required fragment: ${fragment}"
}

require_absent_path() {
    local relative_path=$1
    [[ ! -e "${rootfs}/${relative_path}" && ! -L "${rootfs}/${relative_path}" ]] || \
        fail "forbidden runtime path exists: ${relative_path}"
}

desktop_dir="${rootfs}/usr/share/applications"
local_desktop_dir="${rootfs}/usr/local/share/applications"
[[ -d "$desktop_dir" && ! -L "$desktop_dir" ]] || fail 'runtime desktop directory is missing'
desktop_search_dirs=("$desktop_dir")
if [[ -d "$local_desktop_dir" ]]; then
    desktop_search_dirs+=("$local_desktop_dir")
fi

require_absent_path usr/share/applications/calamares.desktop
require_absent_path usr/local/share/applications/calamares.desktop

calamares_bin="$(relative_file usr/bin/calamares)"
installer_launcher="$(relative_file usr/share/applications/schweisos-installer.desktop)"
installer_autostart="$(relative_file etc/xdg/autostart/schweisos-installer-autostart.desktop)"
installer_wrapper="$(relative_file usr/bin/schweisos-installer)"
installer_autostart_helper="$(relative_file usr/lib/schweisos-calamares/autostart)"
installer_live_session_helper="$(relative_file usr/lib/schweisos-calamares/is-live-session)"
installer_root_helper="$(relative_file usr/lib/schweisos-calamares/launch-root)"
installer_policy="$(relative_file usr/share/polkit-1/actions/org.schweisos.installer.policy)"
live_profile_marker="$(relative_file usr/lib/schweisos-live/session)"
calamares_settings="$(relative_file etc/calamares/settings.conf)"
calamares_branding="$(relative_file etc/calamares/branding/schweisos/branding.desc)"
calamares_slideshow="$(relative_file etc/calamares/branding/schweisos/show.qml)"
calamares_welcome_qml="$(relative_file etc/calamares/branding/schweisos/welcomeq.qml)"
calamares_welcome_config="$(relative_file etc/calamares/modules/welcomeq.conf)"
calamares_browser_chooser="$(relative_file etc/calamares/modules/packagechooser-browser.conf)"
calamares_kernel_chooser="$(relative_file etc/calamares/modules/packagechooser-kernel.conf)"
calamares_extras_chooser="$(relative_file etc/calamares/modules/packagechooser-extras.conf)"
calamares_unpackfs="$(relative_file etc/calamares/modules/unpackfs.conf)"
calamares_reconcile_config="$(relative_file etc/calamares/modules/shellprocess-reconcile.conf)"
calamares_reconcile_helper="$(relative_file usr/lib/schweisos-calamares/reconcile-target)"
calamares_target_manifest="$(relative_file usr/share/schweisos/calamares/target-packages.x86_64)"
timezone_index="$(relative_file usr/share/zoneinfo/zone1970.tab)"
istanbul_timezone="$(relative_file usr/share/zoneinfo/Europe/Istanbul)"
runtime_logo="$(relative_file usr/share/schweisos/branding/schweisos.png)"

require_mode "$calamares_bin" 755
require_mode "$installer_launcher" 644
require_mode "$installer_autostart" 644
require_mode "$installer_wrapper" 755
require_mode "$installer_autostart_helper" 755
require_mode "$installer_live_session_helper" 755
require_mode "$installer_root_helper" 755
require_mode "$installer_policy" 644
require_mode "$live_profile_marker" 644
require_mode "$calamares_settings" 644
require_mode "$calamares_branding" 644
require_mode "$calamares_slideshow" 644
require_mode "$calamares_welcome_qml" 644
require_mode "$calamares_welcome_config" 644
require_mode "$calamares_browser_chooser" 644
require_mode "$calamares_kernel_chooser" 644
require_mode "$calamares_extras_chooser" 644
require_mode "$calamares_unpackfs" 644
require_mode "$calamares_reconcile_config" 644
require_mode "$calamares_reconcile_helper" 755
require_mode "$calamares_target_manifest" 644
require_mode "$timezone_index" 644
require_mode "$istanbul_timezone" 644
require_mode "$runtime_logo" 644

desktop-file-validate "$installer_launcher"
desktop-file-validate "$installer_autostart"

visible_launcher_count="$({ grep -RIl --include='*.desktop' '^Name=Install SchweisOS$' \
    "${desktop_search_dirs[@]}" 2>/dev/null || true; } \
    | while IFS= read -r desktop_file; do
        grep -Fxq 'NoDisplay=true' "$desktop_file" && continue
        grep -Fxq 'Exec=/usr/bin/schweisos-installer' "$desktop_file" || continue
        printf '%s\n' "$desktop_file"
      done | sort | awk 'END { print NR }')"
[[ "$visible_launcher_count" == 1 ]] || \
    fail "expected exactly one visible Install SchweisOS launcher; found ${visible_launcher_count}"

generic_installer_entry="$(grep -RIl --include='*.desktop' '^Name=Install System$' \
    "${desktop_search_dirs[@]}" 2>/dev/null || true)"
[[ -z "$generic_installer_entry" ]] || \
    fail "generic Install System launcher is visible: ${generic_installer_entry#"$rootfs"/}"
direct_calamares_entry="$(grep -RIl --include='*.desktop' '^Exec=.*calamares' \
    "${desktop_search_dirs[@]}" 2>/dev/null || true)"
[[ -z "$direct_calamares_entry" ]] || \
    fail "desktop entry bypasses SchweisOS installer wrapper: ${direct_calamares_entry#"$rootfs"/}"

for launcher_fragment in \
    'Name=Install SchweisOS' \
    'Exec=/usr/bin/schweisos-installer' \
    'Icon=schweisos' \
    'StartupNotify=true'; do
    grep -Fxq "$launcher_fragment" "$installer_launcher" || \
        fail "installer launcher is missing: ${launcher_fragment}"
done
for autostart_fragment in \
    'Exec=/usr/lib/schweisos-calamares/autostart' \
    'NoDisplay=true' \
    'OnlyShowIn=KDE;'; do
    grep -Fxq "$autostart_fragment" "$installer_autostart" || \
        fail "installer autostart is missing: ${autostart_fragment}"
done

require_contains "$installer_autostart_helper" '/usr/lib/schweisos-calamares/is-live-session'
require_contains "$installer_autostart_helper" '/usr/bin/sleep 3'
require_contains "$installer_autostart_helper" 'autostart-attempted'
require_contains "$installer_autostart_helper" '/usr/bin/schweisos-installer'
require_contains "$installer_wrapper" '/usr/bin/flock -n'
require_contains "$installer_wrapper" '/usr/bin/kdialog'
require_contains "$installer_wrapper" '/usr/lib/schweisos-calamares/is-live-session'
require_contains "$installer_wrapper" '/usr/bin/pkexec /usr/lib/schweisos-calamares/launch-root'
require_contains "$installer_live_session_helper" '/usr/bin/id -un'
require_contains "$installer_live_session_helper" '/usr/lib/schweisos-live/session'
require_contains "$installer_live_session_helper" '/usr/bin/stat -c %s'
require_contains "$installer_live_session_helper" '/usr/bin/mountpoint -q "$1"'
require_contains "$installer_live_session_helper" 'mountpoint_is_mounted /run/archiso/airootfs'
require_contains "$installer_live_session_helper" '/proc/cmdline'
require_contains "$installer_live_session_helper" 'archisobasedir=schweis'
if grep -Fq '/run/archiso/bootmnt' \
    "$installer_wrapper" "$installer_autostart_helper" "$installer_live_session_helper"; then
    fail 'runtime installer launch policy depends on transient Archiso bootmnt'
fi
grep -Fxq 'SCHWEISOS_LIVE_SESSION=1' "$live_profile_marker" || \
    fail 'runtime live profile marker is invalid'
mapfile -t live_marker_package_owners < <(
    for package_files in "${rootfs}"/var/lib/pacman/local/*/files; do
        [[ -f "$package_files" ]] || continue
        if grep -Fxq 'usr/lib/schweisos-live/session' "$package_files"; then
            package_record="${package_files%/files}"
            printf '%s\n' "${package_record##*/}"
        fi
    done | sort
)
(( ${#live_marker_package_owners[@]} == 0 )) || \
    fail "live profile marker must be overlay-owned, not package-owned: ${live_marker_package_owners[*]}"
require_contains "$installer_autostart_helper" 'Automatic installer start was blocked.'
require_contains "$installer_root_helper" 'exec /usr/bin/calamares -D6'
require_contains "$installer_root_helper" 'export QT_QPA_PLATFORM=xcb'
require_contains "$installer_policy" '/usr/lib/schweisos-calamares/launch-root</annotate>'
require_contains "$installer_policy" 'org.freedesktop.policykit.exec.allow_gui">true</annotate>'

grep -Fxq 'branding: schweisos' "$calamares_settings" || \
    fail 'runtime Calamares settings do not select SchweisOS branding'
for module in \
    welcomeq \
    packagechooser@browser \
    packagechooser@kernel \
    packagechooser@extras \
    unpackfs \
    shellprocess@reconcile; do
    grep -Fxq "      - ${module}" "$calamares_settings" || \
        fail "runtime Calamares settings omit required module: ${module}"
done
grep -Fxq 'slideshow: "show.qml"' "$calamares_branding" || \
    fail 'runtime Calamares branding omits the slideshow key'
require_contains "$calamares_branding" 'productLogo: "/usr/share/schweisos/branding/schweisos.png"'
require_contains "$calamares_branding" 'productIcon: "/usr/share/schweisos/branding/schweisos.png"'
if grep -Eq '^[[:space:]]*product(Banner|Welcome):' "$calamares_branding"; then
    fail 'runtime Calamares branding must not display a centered welcome logo or banner'
fi
require_contains "$calamares_slideshow" 'readonly property string maintainerName: "Marijua"'
require_contains "$calamares_slideshow" 'text: "Project Maintainer"'
require_contains "$calamares_slideshow" 'text: "Maintained by " + root.maintainerName'
require_contains "$calamares_slideshow" 'Welcome to SchweisOS'
if grep -Fq 'Contributor' "$calamares_slideshow"; then
    fail 'runtime Calamares slideshow labels the project maintainer as a contributor'
fi
for welcome_fragment in \
    'Welcome to SchweisOS' \
    'Network.hasInternet' \
    'Offline installation is fully available.' \
    'Maintained by Marijua'; do
    require_contains "$calamares_welcome_qml" "$welcome_fragment"
done
if grep -Eq 'Image[[:space:]]*\{' "$calamares_welcome_qml"; then
    fail 'runtime Calamares welcome page must remain text-first'
fi
if awk '
    /^[[:space:]]*required:/ { in_required=1; next }
    in_required && /^[^[:space:]]/ { in_required=0 }
    in_required && /^[[:space:]]*-[[:space:]]*internet[[:space:]]*$/ { found=1 }
    END { exit !found }
' "$calamares_welcome_config"; then
    fail 'runtime Calamares welcome page makes internet connectivity mandatory'
fi
require_contains "$calamares_welcome_config" 'internetCheckUrl: "https://schweisos.org/"'
grep -Fxq 'mode: required' "$calamares_browser_chooser" || \
    fail 'runtime browser chooser is not mandatory'
grep -Fxq 'default: firefox' "$calamares_browser_chooser" || \
    fail 'runtime browser chooser default is not Firefox'
grep -Fxq 'mode: required' "$calamares_kernel_chooser" || \
    fail 'runtime kernel chooser is not mandatory'
grep -Fxq 'default: linux-zen' "$calamares_kernel_chooser" || \
    fail 'runtime kernel chooser default is not Linux Zen'
require_contains "$calamares_kernel_chooser" 'Linux Zen (Recommended)'
grep -Fxq 'mode: optionalmultiple' "$calamares_extras_chooser" || \
    fail 'runtime optional-feature chooser does not allow multiple choices'
require_contains "$calamares_unpackfs" 'source: "/run/archiso/airootfs/"'
require_contains "$calamares_unpackfs" 'sourcefs: "file"'
for selection_key in packagechooser_browser packagechooser_kernel packagechooser_extras; do
    require_contains "$calamares_reconcile_config" "\${gs[${selection_key}]}"
done
require_contains "$calamares_reconcile_config" '/usr/lib/schweisos-calamares/reconcile-target ${ROOT}'
require_contains "$calamares_reconcile_helper" 'PAYLOAD=archiso-airootfs'
require_contains "$calamares_reconcile_helper" '/var/lib/schweisos/installer'
grep -Fq $'TR\tEurope/Istanbul' "$timezone_index" || \
    fail 'runtime IANA timezone index omits Europe/Istanbul'

mapfile -t installer_records < <(
    find "${rootfs}/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d \
        -name 'schweisos-calamares-config-*' -print | sort
)
(( ${#installer_records[@]} == 1 )) || \
    fail "expected one schweisos-calamares-config pacman record; found ${#installer_records[@]}"
installer_files="${installer_records[0]}/files"
for owned_path in \
    etc/calamares/settings.conf \
    etc/calamares/branding/schweisos/branding.desc \
    etc/calamares/branding/schweisos/show.qml \
    etc/calamares/branding/schweisos/welcomeq.qml \
    etc/calamares/modules/packagechooser-browser.conf \
    etc/calamares/modules/packagechooser-kernel.conf \
    etc/calamares/modules/packagechooser-extras.conf \
    etc/calamares/modules/unpackfs.conf \
    etc/calamares/modules/welcomeq.conf \
    etc/calamares/modules/shellprocess-reconcile.conf \
    etc/xdg/autostart/schweisos-installer-autostart.desktop \
    usr/bin/schweisos-installer \
    usr/lib/schweisos-calamares/autostart \
    usr/lib/schweisos-calamares/is-live-session \
    usr/lib/schweisos-calamares/launch-root \
    usr/lib/schweisos-calamares/reconcile-target \
    usr/share/applications/schweisos-installer.desktop \
    usr/share/schweisos/calamares/target-packages.x86_64 \
    usr/share/polkit-1/actions/org.schweisos.installer.policy; do
    grep -Fxq "$owned_path" "$installer_files" || \
        fail "schweisos-calamares-config does not own ${owned_path}"
done

mapfile -t calamares_records < <(
    find "${rootfs}/var/lib/pacman/local" -mindepth 1 -maxdepth 1 -type d \
        -name 'calamares-*' -print | sort
)
(( ${#calamares_records[@]} == 1 )) || \
    fail "expected one calamares pacman record; found ${#calamares_records[@]}"
calamares_files="${calamares_records[0]}/files"
grep -Fxq 'usr/bin/calamares' "$calamares_files" || \
    fail 'calamares package does not own /usr/bin/calamares'
! grep -Fxq 'usr/share/applications/calamares.desktop' "$calamares_files" || \
    fail 'calamares package still owns the generic desktop launcher'

printf 'Installer runtime payload validation passed.\n'
printf '  rootfs: %s\n' "$rootfs"
printf '  launcher: single visible Install SchweisOS entry\n'
printf '  autostart: hidden once-only live-session helper\n'
printf '  presentation: text-first welcome and maintainer identity verified\n'
printf '  target: offline chooser, unpackfs, and reconciliation payload verified\n'
