# Fedora CoreOS configs

Butane/Ignition configs and Podman Quadlet services for:

- `vps1`, the public VPS running the main service stack;
- `offsite`, a Raspberry Pi 4B documented in
  [`offsite/README.md`](offsite/README.md); and
- `homelab`, the x86_64 home media and application server documented in
  [`homelab/README.md`](homelab/README.md).

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

After installing a host, place the SOPS age identity at:

```text
~/.config/sops/age/keys.txt
```

Then deploy its services:

```sh
cd ~/infra-template
./build-services.sh HOST
```

## Layout

- `HOST/butane/`: Butane template and generated Ignition config.
- `HOST/services/root/`: rootful Quadlets.
- `HOST/services/rootless/`: rootless Quadlets.
- `HOST/volumes/`: ignored persistent service data.
- `shared/`: files shared by the C&C containers.
- `secrets.yaml`: SOPS-encrypted service secrets.

Rendered service trees are written to the ignored `HOST/services-dist/`
directories.
