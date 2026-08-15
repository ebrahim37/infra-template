# Fedora CoreOS configs

Butane/Ignition configs and Podman Quadlet services for my 3 'servers':
- `vps1`: x86_64 VPS with a public IPv4 and IPv6. Runs VPN (headscale), DNS (blocky), Caddy with Tinyauth and Pocket ID, and more.
- `homelab`: x86_64 headless PC on my home network. Runs things like media (Jellyfin) and music (Navidrome) servers. Backup target for vps1 and other devices.
- `offsite`: Raspberry Pi 4B booting from a USB-SATA SSD. Clones the backups from vps1 for redundancy.

## Build

The `build-*` scripts use Podman so Butane, Copier etc. don't need to be installed.

```sh
./build-butane.sh HOST # renders HOST/butane/config.ign
./build-iso.sh HOST # creates isos/HOST.iso for unattended install to DEST_DEVICE set in HOST/installer.env
./build-services.sh HOST # renders and deploys the host's quadlet files, updated services must be restarted
```

## ISO installation

To build the unattended installer (no screen or keyboard needed) for a host, first build the Ignition config, then the ISO.
```sh
./build-butane.sh HOST
./build-iso.sh HOST
```

You can then write the resulting `isos/HOST.iso` to a USB (change /dev/sdX to your USB device):
```sh
sudo dd if=isos/HOST.iso of=/dev/sdX bs=4M status=progress conv=fsync
```
Or you can use something like Rufus but make sure to use DD mode.

For x86_64 hosts, the ISO skips the automatic reboot so we don't reboot and install FCOS again.
Remove the USB before rebooting.

`offsite` is aarch64 and needs extra Raspberry Pi boot support. Its ISO includes
PFTF EDK2 and the FCOS EFI loader in an appended Pi boot partition, applies the
configured USB-SATA kernel quirk to both the installer and installed system,
and copies EDK2 to the SSD's EFI System Partition after installing.
For Raspberry Pis, the ISO shuts down the Pi so we can visually tell the install finished.

Post-install, get the IP address of the machine (maybe from your router's DHCP page) and run `ssh core@IP`.

## Service deployment

After installing a host, place the SOPS age identity at:

```text
~/.config/sops/age/keys.txt
```

Then deploy its services:

```sh
cd ~/infra-template
./build-services.sh HOST
```

## Pinned container images

Some container image versions are intentionally pinned instead of following
the newest release automatically:

- TinyAuth and Pocket ID provide authentication for Caddy-protected services,
  so their versions are kept stable to avoid an unplanned authentication
  breakage.
- Headscale is pinned because its newest release may be too new for the latest
  Headplane release.
- Every Rybbit container is pinned, including its ClickHouse, PostgreSQL, and
  Redis dependencies. When Rybbit publishes a new release, use the
  [`update-rybbit` skill](vps1/services/rootless/rybbit/update-rybbit/SKILL.md)
  to review the upstream changes and update all containers together.

## Layout

- `HOST/butane/`: Butane template and generated Ignition config.
- `HOST/services/root/`: rootful Quadlets.
- `HOST/services/rootless/`: rootless Quadlets.
- `HOST/volumes/`: ignored persistent service data.
- `cnc-shared/`: files shared by the C&C containers.
- `secrets.yaml`: SOPS-encrypted service secrets. Keys prefixed with `enc_priv_` are encrypted by SOPS and decrypted by build-services.sh, non-sensitive values are kept plaintext. `build-butane.sh` will error if you use a sensitive value in Butane config as it is meant to be publicly exposed.

Rendered service trees are written to the ignored `HOST/services-dist/` directories,
and then synced to `/etc/containers/systemd/HOST-root` and `~/.config/containers/systemd/HOST-rootless`.

## Raspberry Pi EEPROM update

The Pi EEPROM must try USB before microSD and enable partition walking so it can
find EDK2 on the FCOS SSD. If this is not already the case, we must flash the EEPROM.
This script creates `isos/rpi4-eeprom.iso` with the appropriate EEPROM config:

```bash
source offsite/installer.env

tmp=$(mktemp -d)

cat > "$tmp/rpi4-eeprom.conf" <<'EOF'
[all]
BOOT_UART=0
WAKE_ON_GPIO=1
POWER_OFF_ON_HALT=0
NET_INSTALL_AT_POWER_ON=1
ENABLE_SELF_UPDATE=1
BOOT_ORDER=0xf14
PARTITION_WALK=1
EOF

podman run --rm --pull=always --security-opt label=disable \
    -e EDK2_VERSION="$EDK2_VERSION" \
    -v "$PWD:/repo" -v "$tmp:/config:ro" -w /tmp \
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
python3 rpi-eeprom/rpi-eeprom-config --config /config/rpi4-eeprom.conf --out payload/pieeprom.upd "$base"
sh rpi-eeprom/rpi-eeprom-digest -c 2711 -i payload/pieeprom.upd -o payload/pieeprom.sig
mkdir -p /repo/isos
truncate -s 64M /repo/isos/rpi4-eeprom.iso
printf "label: dos\nunit: sectors\n\nstart=2048, type=c, bootable\n" | sfdisk /repo/isos/rpi4-eeprom.iso >/dev/null
mformat -F -i /repo/isos/rpi4-eeprom.iso@@1048576 -v RPI-EEPROM ::
mcopy -s -i /repo/isos/rpi4-eeprom.iso@@1048576 payload/* ::
'

rm -rf "$tmp"
unset tmp ARCH DEST_DEVICE LIVE_KARG DEST_KARG EDK2_VERSION
```

Write this image with Rufus in DD/raw mode, or on Linux:
```sh
sudo dd if=isos/rpi4-eeprom.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Power off the Pi, attach only this USB, and power on. Wait at least two minutes, then power off and remove it.
If USB self-update is disabled in the existing EEPROM, you'll have to use an official microSD recovery image instead.
