#!/usr/bin/env bash
# shellcheck disable=SC2034

iso_name="schweisos"
iso_label="SCHWEIS_$(date --utc --date="@${SOURCE_DATE_EPOCH:-$(date +%s)}" +%Y%m)"
iso_publisher="Schweis Project <https://schweisos.org>"
iso_application="SchweisOS KDE Live Environment"
iso_version="0.2.0"
install_dir="schweis"
buildmodes=('iso')
bootmodes=('uefi.systemd-boot')
arch="x86_64"
pacman_conf="pacman.conf"
airootfs_image_type="squashfs"
airootfs_image_tool_options=('-comp' 'xz' '-Xbcj' 'x86' '-b' '1M' '-Xdict-size' '1M')
