#!/bin/sh
set -eu

dest='@DEST_DEVICE@'
esp=$(lsblk -nrpo PATH,LABEL "$dest" | awk '$2 == "EFI-SYSTEM" { print $1; exit }')
mnt=/mnt/rpi4-edk2
mkdir -p "$mnt"
mount "$esp" "$mnt"
tar -xzf /run/media/iso/rpi4-edk2.tar.gz -C "$mnt"
sync
umount "$mnt"
systemd-run --unit=installer-poweroff --on-active=30s /usr/bin/systemctl poweroff
