# offsite

`offsite` is a Raspberry Pi 4B behind NAT. It boots from a 2.5-inch SSD through
a USB-SATA adapter. EEPROM partition walking must be enabled as described below.

## FCOS installer

[`installer.env`](installer.env) selects aarch64 FCOS, the exact Crucial SSD,
PFTF EDK2 v1.52, and the `7825:a2a4` USB-SATA quirk. `DEST_DEVICE` is erased
without confirmation.

Build the unattended ISO from the repository root:

```sh
./build-butane.sh offsite
./build-iso.sh offsite
```

This creates `isos/offsite.iso`. The build embeds Ignition, applies the USB
quirk to the live and installed kernels, and adds
`coreos.inst.skip_reboot`. It downloads EDK2 once and uses it for both:

- MBR partition 1 with type `0xef`, containing PFTF, FCOS's `EFI/BOOT`
  fallback loader, and `startup.nsh` to launch it explicitly before chaining
  into the FCOS ISO on the same USB; and
- `/rpi4-edk2.tar.gz` inside the ISO, which the post-install hook copies to the
  SSD.

`xorriso` appends the Pi boot partition while replaying the ISO's existing boot
metadata.

[`installer/rpi4-edk2-post.sh`](installer/rpi4-edk2-post.sh) receives the
configured `DEST_DEVICE`, finds its `EFI-SYSTEM` partition, mounts it, extracts
the EDK2 archive, syncs and unmounts it, then schedules a poweroff 30 seconds
later. This makes the SSD Pi-bootable without downloading firmware during
installation and prevents the unattended installer from running again.

After applying the EEPROM update below, installation needs only:

1. a USB stick containing `isos/offsite.iso`; and
2. the target USB-SATA SSD.

I use Rufus to write the ISO in DD/raw mode. On Linux, `dd` also works; replace
`/dev/sdX` with the whole USB device, not a partition:

```sh
sudo dd if=isos/offsite.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Boot with both devices. The EEPROM finds the appended EDK2 partition, EDK2
boots FCOS from the same USB, and FCOS installs to the SSD. After the scheduled
poweroff, disconnect power, remove the installer USB, leave the SSD attached,
and reconnect power.

If the SSD is already Pi-bootable, selection between the two USB drives is not
deterministic. Wipe its existing Pi boot partition before a reliable reinstall.

## EEPROM USB image

[`installer/rpi4-eeprom.conf`](installer/rpi4-eeprom.conf) enables EEPROM
self-update, tries USB before microSD, and enables partition walking so the Pi
can find FCOS on the SSD's later GPT partition.

Build `isos/rpi4-eeprom-usb.img` with Podman from the repository root:

```bash
source offsite/installer.env

podman run --rm --security-opt label=disable \
    -e EDK2_VERSION="$EDK2_VERSION" -v "$PWD:/repo" -w /tmp \
    debian:stable-slim sh -c '
set -eu
export DEBIAN_FRONTEND=noninteractive
apt-get update >/dev/null
apt-get install -y --no-install-recommends ca-certificates curl fdisk git mtools python3 unzip >/dev/null
mkdir build && cd build
git clone --depth 1 https://github.com/raspberrypi/rpi-eeprom.git
curl -fL "https://github.com/pftf/RPi4/releases/download/$EDK2_VERSION/RPi4_UEFI_Firmware_$EDK2_VERSION.zip" -o edk2.zip
mkdir payload && unzip -q edk2.zip -d payload
base=$(ls rpi-eeprom/firmware-2711/default/pieeprom-*.bin | tail -1)
python3 rpi-eeprom/rpi-eeprom-config --config /repo/offsite/installer/rpi4-eeprom.conf --out payload/pieeprom.upd "$base"
sh rpi-eeprom/rpi-eeprom-digest -c 2711 -i payload/pieeprom.upd -o payload/pieeprom.sig
mkdir -p /repo/isos
truncate -s 64M /repo/isos/rpi4-eeprom-usb.img
printf "label: dos\nunit: sectors\n\nstart=2048, type=c, bootable\n" | sfdisk /repo/isos/rpi4-eeprom-usb.img >/dev/null
mformat -F -i /repo/isos/rpi4-eeprom-usb.img@@1048576 -v RPI-EEPROM ::
mcopy -s -i /repo/isos/rpi4-eeprom-usb.img@@1048576 payload/* ::
'
```

I use Rufus to write this raw `.img`; `dd` is also suitable:

```sh
sudo dd if=isos/rpi4-eeprom-usb.img of=/dev/sdX bs=4M status=progress conv=fsync
```

To update, power off, disconnect other storage, and attach only the EEPROM USB.
Power on, wait at least two minutes without interrupting power, then power off,
remove it, and boot with only the SSD. This relies on the existing EEPROM
allowing self-update; otherwise use the official microSD recovery image.

## First boot

The package installation and Git clone wait for `chronyd` because the Pi has no
battery-backed clock and incorrect time breaks TLS validation. After FCOS has
finished its first-boot package layering and rebooted, install the SOPS age key
and deploy the services:

```sh
cd ~/infra-template
./build-services.sh offsite
```
