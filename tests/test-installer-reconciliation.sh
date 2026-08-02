#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

export LC_ALL=C

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

project_root="$(git -C "$(dirname -- "${BASH_SOURCE[0]}")" rev-parse --show-toplevel)"
helper="${project_root}/packages/schweisos-calamares-config/schweisos-calamares-reconcile-target"
manifest="${project_root}/packages/schweisos-calamares-config/target-packages.x86_64"
tmp_dir="$(mktemp -d)"
cleanup() {
  rm -r -- "$tmp_dir"
}
trap cleanup EXIT

mock_bin="${tmp_dir}/bin"
target_root="${tmp_dir}/target"
runtime_share="${tmp_dir}/runtime/usr/share/schweisos/calamares"
install -d -- "$mock_bin" "$target_root/etc" "$target_root/boot" \
  "$target_root/usr/lib/schweisos-live" "$target_root/var/lib/mock" "$runtime_share"
cp -- "$manifest" "${runtime_share}/target-packages.x86_64"
printf '[options]\n' >"${target_root}/etc/pacman.conf"
printf 'root:x:0:0:root:/root:/usr/bin/bash\nlive:x:1000:1000:Live:/home/live:/usr/bin/bash\n' \
  >"${target_root}/etc/passwd"
printf 'live-marker\n' >"${target_root}/usr/lib/schweisos-live/session"

sed 's/[[:space:]]*#.*$//' "$manifest" | awk 'NF { print }' \
  >"${target_root}/var/lib/mock/installed"
cat >>"${target_root}/var/lib/mock/installed" <<'EOF'
arch-install-scripts
calamares
chromium
falkon
firefox
linux
linux-hardened
linux-lts
linux-zen
mkinitcpio-archiso
plymouth
schweisos-calamares-config
firewalld
plasma-firewall
git
cmake
ninja
EOF
sort -u -o "${target_root}/var/lib/mock/installed" "${target_root}/var/lib/mock/installed"

cat >"${mock_bin}/findmnt" <<'EOF'
#!/usr/bin/bash
exit 0
EOF
cat >"${mock_bin}/arch-chroot" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
root=$1
shift
[[ ${1-} == pacman ]] || exit 0
shift
operation=$1
shift
case "$operation" in
  -Qq)
    [[ ${1-} == -- ]] && shift
    grep -Fxq -- "$1" "${root}/var/lib/mock/installed"
    ;;
  -Rns)
    while [[ $# -gt 0 && $1 != -- ]]; do shift; done
    [[ $# -gt 0 ]] && shift
    for package in "$@"; do
      sed -i "/^${package//\//\\/}$/d" "${root}/var/lib/mock/installed"
    done
    ;;
  -D)
    exit 0
    ;;
  *)
    printf 'unexpected mock pacman operation: %s\n' "$operation" >&2
    exit 1
    ;;
esac
EOF
cat >"${mock_bin}/userdel" <<'EOF'
#!/usr/bin/bash
set -euo pipefail
[[ $1 == --root && $3 == --remove && $4 == live ]] || exit 1
sed -i '/^live:/d' "$2/etc/passwd"
[[ ! -d "$2/home/live" ]] || rm -r -- "$2/home/live"
EOF
chmod 0755 -- "$mock_bin/findmnt" "$mock_bin/arch-chroot" "$mock_bin/userdel"

test_helper="${tmp_dir}/reconcile-target"
sed "s#/usr/share/schweisos/calamares#${runtime_share}#" "$helper" >"$test_helper"
chmod 0755 -- "$test_helper"

PATH="${mock_bin}:/usr/bin:/bin" "$test_helper" "$target_root" firefox linux-zen \
  security,development

selection="${target_root}/var/lib/schweisos/installer/selection.conf"
[[ -f "$selection" && ! -L "$selection" ]] || fail 'selection evidence was not created'
grep -Fxq 'BROWSER=firefox' "$selection" || fail 'browser evidence is incorrect'
grep -Fxq 'KERNEL=linux-zen' "$selection" || fail 'kernel evidence is incorrect'
grep -Fxq 'OPTIONAL_FEATURES=security,development' "$selection" || \
  fail 'optional-feature evidence is incorrect'
[[ ! -e "${target_root}/usr/lib/schweisos-live" ]] || fail 'live-only path remains'
! grep -q '^live:' "${target_root}/etc/passwd" || fail 'live account remains'
for retained in firefox linux-zen firewalld plasma-firewall git cmake ninja; do
  grep -Fxq "$retained" "${target_root}/var/lib/mock/installed" || \
    fail "selected package was removed: ${retained}"
done
for removed in chromium falkon linux linux-lts linux-hardened calamares plymouth; do
  ! grep -Fxq "$removed" "${target_root}/var/lib/mock/installed" || \
    fail "unselected or live-only package remains: ${removed}"
done

if PATH="${mock_bin}:/usr/bin:/bin" "$test_helper" "$target_root" unknown linux-zen '' \
    >/dev/null 2>&1; then
  fail 'unknown browser selection was accepted'
fi
if PATH="${mock_bin}:/usr/bin:/bin" "$test_helper" / firefox linux-zen '' \
    >/dev/null 2>&1; then
  fail 'unsafe target root was accepted'
fi

printf 'Installer reconciliation tests passed.\n'
