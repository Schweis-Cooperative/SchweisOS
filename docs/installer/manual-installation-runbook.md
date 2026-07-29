# Manual Installation Runbook

Version: 0.1
Status: Operator reference
Date: 2026-07-29

This runbook documents the intended installed-system shape for Faz 1. It is a
manual reference and recovery aid, not a replacement for the graphical
installer.

The commands are intentionally explicit because installation changes disk
state. Operators must adapt device names to the target machine and must not
copy commands blindly.

## Preconditions

- Booted in UEFI mode.
- Network available.
- SchweisOS keyring, mirrorlist, and pacman configuration available from a
  trusted live environment.
- Target disk selected by the operator.
- All user data on the target disk backed up.

## Target Shape

```text
GPT disk
  512 MiB EFI system partition -> /boot, FAT32
  remaining space root         -> /, ext4 by default
```

Btrfs may be used by an advanced operator, but Faz 1 does not define snapshots
or rollback.

## Package Set

The canonical target package manifest lives in:

```text
packages/schweisos-calamares-config/target-packages.x86_64
```

The graphical installer uses that same list through `pacstrap`.

## Manual Outline

1. Partition the disk with GPT.
2. Format the EFI system partition as FAT32.
3. Format root as ext4 unless intentionally choosing another documented
   filesystem.
4. Mount root at `/mnt`.
5. Mount the EFI system partition at `/mnt/boot`.
6. Install packages using `pacstrap` with a pacman configuration that includes
   Arch repositories and `/etc/pacman.d/schweisos.conf`.
7. Generate `/mnt/etc/fstab`.
8. Configure locale, keymap, timezone, hostname, and first user.
9. Add `Include = /etc/pacman.d/schweisos.conf` to target `/etc/pacman.conf`
   if it is not already present.
10. Install systemd-boot with `bootctl install`.
11. Create `/boot/loader/loader.conf`.
12. Create `/boot/loader/entries/schweisos.conf` with a root UUID.
13. Run `mkinitcpio -P` in the target.
14. Enable `NetworkManager.service` and `sddm.service`.
15. Reboot and verify login to Plasma.

## Verification After First Boot

Run:

```bash
cat /etc/os-release
findmnt /
bootctl status
systemctl is-enabled NetworkManager.service
systemctl is-enabled sddm.service
pacman-conf --repo-list
```

Expected:

- `/etc/os-release` identifies SchweisOS.
- `/` is the intended installed root filesystem.
- systemd-boot is installed on the EFI system partition.
- NetworkManager and SDDM are enabled.
- `schweisos` appears as a separate pacman repository when the installed
  system's SchweisOS repository include is active.

Do not perform partial upgrades. Use full-system pacman updates only.
