# Recovery Runbook

Version: 0.1
Status: Faz 1 recovery reference
Date: 2026-07-29

This document records the first recovery procedures for a SchweisOS MVP
installation. It is intentionally conservative and terminal-oriented.

Faz 1 does not implement snapshots, rollback automation, full-disk encryption,
Secure Boot, or BIOS boot recovery. Those require later architecture.

## Bootloader Recovery

Use this when the installed system exists but firmware no longer boots the
SchweisOS systemd-boot entry.

1. Boot the SchweisOS live ISO in UEFI mode.
2. Mount the installed root filesystem at `/mnt`.
3. Mount the EFI system partition at `/mnt/boot`.
4. Chroot into the installed system:

   ```bash
   arch-chroot /mnt
   ```

5. Reinstall systemd-boot:

   ```bash
   bootctl install
   ```

6. Verify `/boot/loader/loader.conf` and
   `/boot/loader/entries/schweisos.conf`.
7. Regenerate initramfs:

   ```bash
   mkinitcpio -P
   ```

8. Exit, unmount, and reboot.

## Pacman Repository Recovery

Use this when SchweisOS packages cannot be resolved after installation.

1. Verify that the keyring package is installed:

   ```bash
   pacman -Q schweisos-keyring schweisos-mirrorlist schweisos-pacman-config
   ```

2. Verify that `/etc/pacman.conf` contains:

   ```ini
   Include = /etc/pacman.d/schweisos.conf
   ```

3. Verify that the SchweisOS snippet still requires trusted signatures:

   ```bash
   pacman-conf --repo schweisos SigLevel
   ```

4. If the include is missing, add it manually after review. Do not set
   `SigLevel = Never`, do not use `TrustAll`, and do not remove Arch
   repositories.

## Display Manager Recovery

Use this when the installed system boots to a terminal but not to Plasma.

```bash
systemctl status sddm.service
systemctl enable --now sddm.service
```

If SDDM starts but the Plasma session fails, inspect the user's journal:

```bash
journalctl --user -b
```

## Network Recovery

Use this when the installed system has no network after first boot.

```bash
systemctl status NetworkManager.service
systemctl enable --now NetworkManager.service
nmcli device
```

## Update Recovery Boundary

SchweisOS preserves Arch's full-system update model. Recovery documentation
must not recommend partial upgrades. If a package transaction is interrupted,
repair the package database and complete a full update rather than mixing old
and new repository states.
