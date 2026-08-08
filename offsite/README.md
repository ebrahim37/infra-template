# offsite

`offsite` is a Raspberry Pi 4B that boots Fedora CoreOS from a USB-SATA SSD.
Setup has two steps: update the Pi EEPROM, then install FCOS.

## 1. Update the EEPROM

From the repository root, use Podman and
[`installer/rpi4-eeprom.conf`](installer/rpi4-eeprom.conf) to create
`isos/rpi4-eeprom-usb.img`:

```bash
source offsite/installer.env

podman run --rm --pull=always --security-opt label=disable \
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

The config enables USB-first boot and partition walking so the Pi can find
EDK2 on the FCOS SSD.

Write the image with Rufus in DD/raw mode, or on Linux:

```sh
sudo dd if=isos/rpi4-eeprom-usb.img of=/dev/sdX bs=4M status=progress conv=fsync
```

Power off the Pi, disconnect all other storage, attach only this USB, and power
on. Wait at least two minutes without interrupting power, then power off and
remove it. If USB self-update is disabled in the existing EEPROM, use the
official microSD recovery image instead.

## 2. Install FCOS

Build the unattended installer:

```sh
./build-butane.sh offsite
./build-iso.sh offsite
```

Write `isos/offsite.iso` with Rufus in DD/raw mode, or on Linux:

```sh
sudo dd if=isos/offsite.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

The ISO contains PFTF EDK2, the FCOS EFI loader, Ignition, and the USB-SATA
quirk. Its post-install hook copies EDK2 to the SSD and powers off instead of
rebooting. `DEST_DEVICE` in [`installer.env`](installer.env) is erased without
confirmation.

Attach the installer USB and target SSD, then power on. After the Pi powers
off, disconnect power, remove the installer USB, and boot with only the SSD.
If the SSD is already Pi-bootable, wipe its boot partition first so it cannot
compete with the installer USB.

After first boot, install the SOPS age key and deploy the services:

```sh
cd ~/infra-template
./build-services.sh offsite
```
