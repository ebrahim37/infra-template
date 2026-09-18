# Fedora CoreOS configuration

This repository declaratively configures servers with Butane configs (`*/butane`) and Podman Quadlets (`*/services`).
These directories contain Jinja templates rendered with [Copier](https://copier.readthedocs.io).

I have made the setup as turnkey as possible, but many values are still hard-coded for my environment. Use this repository as an example for your own infra.

Public configuration values (hostnames, tailnet IP addresses, etc.) and secrets encrypted with [SOPS](https://github.com/getsops/sops) are stored in `secrets.yaml`. Values are grouped by host, `shared.*` values apply to every host.

The hosts are:
- `vps1`: An x86_64 VPS with public IPv4 and IPv6 addresses. It runs Headscale, Blocky, Caddy with TinyAuth, Pocket ID, and more.
- `homelab`: An x86_64 headless PC on my home network. It runs media-streaming services (including Navidrome), and is the primary backup target for my devices.
- `offsite`: A Raspberry Pi 4B that boots from a USB-to-SATA SSD. It replicates backups from `homelab` for redundancy. Some Pis may need their EEPROM updated, see [Raspberry Pi EEPROM update](#raspberry-pi-eeprom-update).

These services run on all hosts:
- `root/tailscale-client`: Connects to the Headscale tailnet hosted on `vps1`. Every host advertises itself as an exit node, `homelab` and `offsite` also advertise subnet routes. `Network=host` makes the Tailscale interface available to the host and its containers.
- `root/cnc`: An Arch Linux container for administration and development. The `offsite` container uses Alpine instead because it runs on ARM. The container mounts the CoreOS root at `/host`, persists `/data`, uses `Network=host` and `UserNS=host`, and includes several convenience scripts:
  - `run-host` and `run-host-root`: Run a command on the CoreOS host as `core` or `root`, respectively.
  - `rebuild-services`: Pull the latest changes from this repository, then run `build-services.sh` for the current host. Changed services must still be restarted manually (for example, with `hsc restart blocky`).
  - `rebuild-cnc`: Rebuild the container image from its Containerfile, then offer to restart the container.
  - `force-rebuild-cnc`: Rebuild the `cnc` image without cached layers. This is useful when an old cached `RUN pacman -Syu ...` layer causes errors.
  - `list-services`: Show the status of all rootful and rootless Quadlets.
  - `start-services` and `stop-services`: Start or stop all rootful and rootless Quadlets, with a progress bar.
  - `ports`: Show all listening ports. On `vps1`, LiveKit ports are omitted.
  - `td`: Send and receive files with Taildrop. I mostly use this for transfers to and from my phone, where I cannot use croc.
  - `croc` and `scroc`: Send and receive files through the croc relay hosted on `vps1`. The shared secret is preset in the scripts. `scroc` receives files as `root`.
  - `ll` and `llh`: List files in the current directory with [eza](https://github.com/eza-community/eza). `llh` also shows hidden files.
  - `http` and `phttp`: Run [http-server](https://www.npmjs.com/package/http-server) on a given port. `phttp` listens only on the Tailscale interface. On `vps1`, `https` and `phttps` are available which use Caddy's SSL certificate.
  - `btop`: Wrap [btop](https://github.com/aristocratos/btop) to include host processes.
  - `codex` and `omp`: Wrap Codex and Oh My Pi, storing their data under `/data` so sessions and authentication survive container rebuilds.
  - `npm`, `vi`, `svi`, `nvi`, `snvi`, and `ya`: Wrap npm, Vim, Neovim, and yay to prevent them from polluting `$HOME`. `svi` and `snvi` run Vim and Neovim as `root`.
  - Aliases `sc`/`jc` and `hsc`/`hjc`: Run `systemctl --user` and `journalctl --user -u`, respectively. The `h` variants run on the CoreOS host.
  - Aliases `ssc`/`jjc` and `hssc`/`hjjc`: Run `sudo systemctl` and `journalctl -u`, respectively. The `h` variants run on the CoreOS host.
  - `format-usb`: Format a connected USB drive as exFAT. This command is not available on `vps1`.

  `cnc-shared/` contains configuration files and scripts copied into the `cnc` containers. Its `scripts/` directory is split into `cnc/` and `common/`; the latter is shared with my [NixOS configuration](https://github.com/ebrahim37/nixos-configs).

  The container also runs an SSH server on port 222, using the same `authorized_keys` file and host keys as CoreOS. Waypipe is installed in each `cnc` container, so I can remotely access GUI applications from any Wayland host with for eg. `waypipe ssh homelab firefox`.

  The tmux configuration gives every SSH connection a persistent, mostly invisible tmux environment with shared sessions and windows.
- `root/beszel` (rootless on `vps1`): A [Beszel](https://www.beszel.dev/) agent that reports to the Beszel instance on `vps1`. It tracks running services (excluding rootless Quadlets), resource usage, and S.M.A.R.T. data for connected disks. The `vps1` agent does not need root access because that host does not use S.M.A.R.T. monitoring.
- `rootless/monitor`: A small Fedora container that monitors rootful and rootless Quadlets. If a container remains down for at least 10 minutes, it sends a notification through the [ntfy](https://ntfy.sh/) instance on `vps1`.

Persistent data for all containers, including `cnc`, is stored under `HOST/volumes`. Containers create their volume directories as needed. Back up this directory on every host.

## Dependencies

- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) for editing `secrets.yaml`. Generate an age identity at the expected path:
  ```sh
  mkdir -p ~/.config/sops/age
  age-keygen -o ~/.config/sops/age/keys.txt
  ```
- Podman for running the `build-*` scripts.

These tools are also installed in the `cnc` containers.

## Installing CoreOS

First, configure `HOST/butane/config.bu.jinja`, then build its Ignition file:
```sh
./build-butane.sh HOST
```
Note: this script aborts if there are `enc_priv_*` vars used in the butane config. This is because the resulting ignition file meant to be publicly visible, so that provisioning machines is a bit easier.

You can then boot the standard Fedora CoreOS ISO and run:
```sh
sudo coreos-installer install /dev/sda --ignition-url https://raw.githubusercontent.com/ebrahim37/infra-template/refs/heads/main/HOST/butane/config.ign
```

Alternatively, create bootable installation media with the Ignition file embedded:
```sh
./build-iso.sh HOST
sudo dd if=isos/HOST.iso of=/dev/sdX bs=4M status=progress conv=fsync # change sdX
rm -rf isos
```

The customized installation media boots and installs without a keyboard or display. It does not reboot automatically after installation, which prevents the machine from booting the installer again. Remove the USB drive, then boot the installed system.

The machine reboots once during its initial startup after installing host packages with `rpm-ostree`. Find its IP address, perhaps on your router's DHCP page, then connect over SSH.

## Starting services

After installation, the `infra-template` repository should be automatically cloned to `/home/core/infra-template`. Copy your age identity to `/home/core/.config/sops/age/keys.txt` so that `secrets.yaml` can be decrypted.

Configure `HOST/services/`, then run:
```sh
cd ~/infra-template
./build-services.sh HOST
```

Rendered services are written to the ignored `HOST/services-dist/` directory and then synced to `/etc/containers/systemd/HOST-root` and `~/.config/containers/systemd/HOST-rootless`. The deployed directories are updated in place so that bind-mounted files, such as `vps1/services/rootless/caddy/conf/Caddyfile`, remain mounted in running containers during rebuilds.

After the first build, start each service manually:
```sh
sudo systemctl start tailscale-client
sudo systemctl start cnc
# ...
```

Alternatively, start `cnc`, then run `start-services` inside it.

## Pinned container images

Some container image versions are intentionally pinned rather than updated to the newest release automatically:
- TinyAuth and Pocket ID authenticate users for Caddy-protected services, so their versions remain fixed to avoid unplanned authentication breakage.
- Headscale is pinned because its newest release may be incompatible with the latest Headplane release.
- Every Rybbit container is pinned, as are its ClickHouse, PostgreSQL, and Redis dependencies. When Rybbit publishes a new release, use the [`update-rybbit` skill](vps1/services/rootless/rybbit/update-rybbit/SKILL.md) to review the upstream changes and update all containers together.

## Raspberry Pi EEPROM update

The Pi's EEPROM must try USB before microSD and enable partition walking so that it can find EDK2 on the FCOS SSD. If it is not already configured this way, update the EEPROM. The following script creates `isos/rpi4-eeprom.iso` with the required settings:
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
base=$(ls rpi-eeprom/firmware-2711/default/pieeprom-*.bin | tail -n 1)
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

Write the image with Rufus in DD/raw mode, or use `dd` on Linux:
```sh
sudo dd if=isos/rpi4-eeprom.iso of=/dev/sdX bs=4M status=progress conv=fsync
```

Power off the Pi, connect only this USB drive, and power it on. Wait at least two minutes, then power it off and remove the drive.

If USB self-update is disabled in the existing EEPROM, use an official microSD recovery image instead.
