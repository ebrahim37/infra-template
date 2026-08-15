# Fedora CoreOS configs

Butane/Ignition configs and Podman Quadlet services for:

- `vps1`, the public VPS running the main service stack;
- `offsite`, a Raspberry Pi 4B booting from a USB-SATA SSD; and
- `homelab`, the x86_64 home media and application server.

This is a personal configuration, not a turnkey deployment.

## Build

The scripts use Podman, so Butane, Copier, SOPS, and age do not need to be
installed on the host.

```sh
./build-butane.sh HOST
./build-iso.sh HOST
./build-services.sh HOST
```

- `build-butane.sh` renders `HOST/butane/config.ign`.
- `build-iso.sh` creates the unattended `isos/HOST.iso`. It erases the
  `DEST_DEVICE` configured in `HOST/installer.env` without confirmation.
- `build-services.sh` renders and deploys the host's Quadlet files. The argument
  must match `/etc/hostname`.

## ISO installation

For any of the three hosts, first render its Ignition config and then build its
unattended installer:

```sh
./build-butane.sh HOST
./build-iso.sh HOST
```

The result is `isos/HOST.iso`. Boot it as physical or virtual installation
media. For a USB installer, write it in DD/raw mode; on Linux, replace
`/dev/sdX` with the whole USB device, not a partition:

```sh
sudo dd if=isos/HOST.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Each ISO installs stable Fedora CoreOS with `HOST/butane/config.ign` and erases
the `DEST_DEVICE` in `HOST/installer.env` without confirmation. `vps1` and
`homelab` use the standard x86_64 FCOS ISO. Their installers skip the automatic
reboot, so remove the installation media and reboot once installation has
finished.

`offsite` is aarch64 and needs extra Raspberry Pi boot support. Its ISO includes
PFTF EDK2 and the FCOS EFI loader in an appended Pi boot partition, applies the
configured USB-SATA kernel quirk to both the installer and installed system,
and copies EDK2 to the SSD's EFI System Partition after installing. Although
the common installer configuration skips FCOS's automatic reboot, the offsite
post-install hook powers the Pi off after 30 seconds. Once it powers off, remove
the installer USB and boot it again with only the target SSD attached. If that
SSD is already Pi-bootable, wipe its old Pi boot partition first so it cannot
compete with the installer USB.

## Update the offsite Raspberry Pi 4B EEPROM

The Pi EEPROM must try USB before microSD and enable partition walking so it can
find EDK2 on the FCOS SSD. From the repository root, the following creates
`isos/rpi4-eeprom.iso`; the EEPROM configuration is included in the command so
no separate config file is needed:

```bash
source offsite/installer.env

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

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
```

Write the image with Rufus in DD/raw mode, or on Linux:

```sh
sudo dd if=isos/rpi4-eeprom.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Power off the Pi, disconnect all other storage, attach only this USB, and power
on. Wait at least two minutes without interrupting power, then power off and
remove it. If USB self-update is disabled in the existing EEPROM, use the
official microSD recovery image instead.

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
  to review the upstream changes and update the complete set of pins together.

## Layout

- `HOST/butane/`: Butane template and generated Ignition config.
- `HOST/services/root/`: rootful Quadlets.
- `HOST/services/rootless/`: rootless Quadlets.
- `HOST/volumes/`: ignored persistent service data.
- `shared/`: files shared by the C&C containers.
- `secrets.yaml`: SOPS-encrypted service secrets.

Rendered service trees are written to the ignored `HOST/services-dist/`
directories.
