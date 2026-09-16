# Fedora CoreOS configs

This repo delaratively defines my headless 'server' hosts through Butane configs (`*/butane`) and Podman Quadlets (`*/services`).
These folders contain Jinja templates which are rendered by [Copier](https://copier.readthedocs.io).

I tried to make this as 'turnkey' as possible but there's still a lot of hardcoded things specific to my setup. Use this repo as an example for setting up your own infra.

Public config vars (hostnames, tailnet IPs, etc) and secrets (encrypted with [SOPS](https://github.com/getsops/sops)) are managed in `secrets.yaml`, grouped by host (`shared.*` vars are used by all hosts).

Some details about the hosts:
- `vps1`: x86_64 VPS with a public IPv4 and IPv6. Runs VPN (headscale), DNS (blocky), Caddy with Tinyauth, Pocket ID, and more.
- `homelab`: x86_64 headless PC on home network. Runs media streaming, music (Navidrome), and more. Also the primary backup target for my devices.
- `offsite`: Raspberry Pi 4B booting from a USB-SATA SSD. Clones the backups from homelab for redundancy. EEPROM may need to be updated (see [here](#raspberry-pi-eeprom-update)).

All hosts have these 4 services:
- `root/tailscale-client`: Connects to headscale tailnet (running on `vps1`), advertises exit node, and subnets (on `homelab` and `offsite`). Has `Network=host` so the interface is available everywhere (including containers).
- `root/cnc`: Arch Linux container used for administration, development etc. (`offsite` cnc is Alpine because ARM). Has CoreOS root mounted at `/host`, a persisted `/data` mount, `Network=host`, `UserNS=host`, and also has a bunch of convenience scripts:
  - `run-host(-root)`: Runs a command on the CoreOS host.
  - `rebuild-services`: git pull this repo, then run build-services for this host. You will also need to restart changed services manually (eg. `hsc restart blocky`).
  - `rebuild-cnc`: Rerun the Containerfile for this image, then prompt to restart.
  - `force-rebuild-cnc`: Sometimes, the cached `RUN pacman -Syu ...` step is too old and causes errors. Use this to rebuild cnc without cached layers.
  - `list-services`: Lists status of all rootful and rootless quadlets.
  - `start/stop-services`: Start/stop all rootful and rootless quadlets, with progress bar.
  - `ports`: Show all listening ports. On `vps1`, livekit ports are filtered out.
  - `td`: Send/receive files with taildrop. I mostly use this to send files to/from my phone, because I can't use croc there.
  - `(s)croc`: Send/receive files with croc. Uses croc-relay hosted on `vps1`. Don't need to copy a secret because it is preset in the script. `scroc` receives as root.
  - `ll(h)`: List files in directory with [eza](https://github.com/eza-community/eza). `llh` shows hidden.
  - `(p)http`: Runs [http-server](https://www.npmjs.com/package/http-server) on a given port. `phttp` listens on tailscale interface only. `vps1` additionally has `(p)https` which uses the SSL cert from caddy.
  - `btop`: Wrapper around [btop](https://github.com/aristocratos/btop) that lists host processes as well.
  - `codex/omp`: Wrappers around codex and oh-my-pi that store data under `/data` so session/auth info stays after container rebuild.
  - `npm, (s)vi, (s)nvi, ya`: Wrappers around npm, Vim, Neovim, and yay. These wrappers are to prevent these programs from polluting $HOME. `svi/snvi` run Vim/Neovim as root.
  - (alias) `(h)sc/(h)jc`: Alias to `systemctl --user` and `journalctl --user -u`. `hsc/hjc` run on host.
  - (alias) `(h)ssc/(h)jjc`: Alias to `sudo systemctl` and `journalctl -u`. `hssc/hjjc` runs on host.
  - `format-usb`: Format a plugged-in USB to exFAT. Not available on `vps1`.

  `cnc-shared/` contains configs and scripts to be copied into cnc containers. `cnc-shared/scripts` is split into `cnc` and `common`, the `common` scripts are used/cloned by my [NixOS config](https://github.com/ebrahim37/nixos-configs).
  
  This container also runs an ssh server on port 222, with same authorized_keys and host keys as CoreOS. Waypipe is also installed in the cnc containers, so I can remotely access GUI programs with for eg. `waypipe ssh homelab firefox` from any wayland host.

  The tmux config gives every SSH connection a persistent, mostly invisible tmux environment with shared sessions/windows.
- `root/beszel`: [Beszel](https://www.beszel.dev/) agent reporting to Beszel instance running on `vps1`. Keeps track of running services (not including rootless quadlets), resource usage, and S.M.A.R.T. status of connected disks (`vps1`'s agent is rootless because it doesn't need S.M.A.R.T. monitoring).
- `rootless/monitor`: Small Fedora container keeping track of rootful+rootless quadlets. If a container is down for at least 10 minutes, sends a notification via [ntfy](https://ntfy.sh/) instance running on `vps1`.

Persistent data for all containers (including cnc) is placed in `HOST/volumes`. Containers will automatically mkdir their volumes if they don't exist. Make sure this `volumes` directory is backed up on all hosts.


## Dependencies

- [SOPS](https://github.com/getsops/sops) and [age](https://github.com/FiloSottile/age) for editing `secrets.yaml`. Also generate an age key with:
  ```sh
  mkdir -p ~/.config/sops/age
  age-keygen -o ~/.config/sops/age/keys.txt
  ```
- podman for running the `build-*` scripts.

These are installed inside the `cnc` containers as well.


## Installing CoreOS

First, configure `HOST/butane/config.bu.jinja` to your needs, then build the Ignition file:
```sh
./build-butane.sh HOST
```

You can then either use the standard CoreOS ISO and run:
```sh
sudo coreos-installer install /dev/sda --ignition-url https://raw.githubusercontent.com/ebrahim37/infra-template/refs/heads/main/HST/butane/config.ign
```

Or make a bootable USB with the Ignition file embedded:
```sh
./build-iso.sh HOST
sudo dd if=isos/HOST.iso of=/dev/sdX bs=4M status=progress conv=fsync
rm -rf isos
```
The bootable USB does not need a keyboard or screen to install. For x86_64 hosts, the ISO skips the automatic reboot so we don't reboot and install FCOS again.
Remove the USB before rebooting.

The machine will reboot once after initial install to install packages with `rpm-ostree` (git, sops, etc.).
Get the IP address of the machine (maybe from your router's DHCP page) and ssh in.


## Starting services

After install, the `infra-template` repo should be automatically cloned to `/home/core/infra-template`. We just need to copy our age key to `/home/core/.config/sops/age/keys.txt` so that `secrets.yaml` can be decrypted.

Then, configure `HOST/services/` to your liking, and run:
```sh
cd ~/infra-template
./build-services.sh HOST
```
Rendered services are written to the ignored `HOST/services-dist/` directory, then synced to `/etc/containers/systemd/HOST-root` and `~/.config/containers/systemd/HOST-rootless`. We do this so that for eg. `vps1/services/rootless/caddy/conf/Caddyfile` is not unmounted from the caddy container.

For first boot, we need to manually start each service:
```
sudo systemctl start tailscale-client
sudo systemctl start cnc
...
```
Or you can start cnc and run `start-services` from there.


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
