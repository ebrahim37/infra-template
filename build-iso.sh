#!/usr/bin/env bash
set -euo pipefail

[ "$#" = 1 ] || { echo "usage: $0 <host>"; exit 2; }

repo=$(dirname "$(realpath "$0")")

host=$1
dir="$repo/$host"
source "$dir/installer.env"

tmp=$(mktemp -d)
cp "$dir/butane/config.ign" "$tmp/config.ign"

coreos() {
	podman run --rm --pull=always --security-opt label=disable \
		-v "$tmp:/work" -w /work quay.io/coreos/coreos-installer:release "$@"
}

coreos download -s stable -a "$ARCH" -p metal -f iso -C /work
iso=$(basename "$tmp"/fedora-coreos-*-live-iso."$ARCH".iso)
args=(iso customize --dest-device "$DEST_DEVICE" --dest-ignition /work/config.ign --live-karg-append coreos.inst.skip_reboot)
[[ -z ${LIVE_KARG:-} ]] || args+=(--live-karg-append "$LIVE_KARG")
[[ -z ${DEST_KARG:-} ]] || args+=(--dest-karg-append "$DEST_KARG")

out=$host.iso
if [[ -n ${EDK2_VERSION:-} ]]; then
	url=https://github.com/pftf/RPi4/releases/download/$EDK2_VERSION/RPi4_UEFI_Firmware_$EDK2_VERSION.zip
	curl -fL "$url" -o "$tmp/edk2.zip"
	mkdir "$tmp/edk2"
	unzip -q "$tmp/edk2.zip" -d "$tmp/edk2"
	cat > "$tmp/edk2/startup.nsh" <<'EOF'
FS0:\EFI\BOOT\BOOTAA64.EFI
FS1:\EFI\BOOT\BOOTAA64.EFI
FS2:\EFI\BOOT\BOOTAA64.EFI
EOF
	tar -C "$tmp/edk2" -czf "$tmp/rpi4-edk2.tar.gz" .
	sed "s|@DEST_DEVICE@|$DEST_DEVICE|" > "$tmp/post.sh" <<'EOF'
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
EOF
	args+=(--post-install /work/post.sh)
	out=coreos.iso
fi

coreos "${args[@]}" -o "/work/$out" "/work/$iso"

if [[ -n ${EDK2_VERSION:-} ]]; then
	podman run --rm --pull=always --security-opt label=disable -v "$tmp:/work" alpine \
		sh -c 'apk add --no-cache mtools xorriso >/dev/null \
			&& xorriso -osirrox on -indev /work/coreos.iso \
				-extract /images/efiboot.img /work/fcos-efiboot.img \
			&& mkdir /work/fcos-efi \
			&& mcopy -s -i /work/fcos-efiboot.img ::/EFI /work/fcos-efi \
			&& truncate -s 32M /work/rpi4-edk2.img \
			&& mformat -i /work/rpi4-edk2.img -v RPI-EDK2 :: \
			&& mcopy -s -i /work/rpi4-edk2.img /work/edk2/* :: \
			&& mcopy -s -i /work/rpi4-edk2.img /work/fcos-efi/EFI :: \
			&& xorriso -indev /work/coreos.iso -outdev "/work/$1.iso" \
				-boot_image any replay \
				-map /work/rpi4-edk2.tar.gz /rpi4-edk2.tar.gz \
				-append_partition 1 0xef /work/rpi4-edk2.img \
				-boot_image any appended_part_as=mbr' sh "$host"
fi

install -D -m 0644 "$tmp/$host.iso" "$repo/isos/$host.iso"
rm -rf "$tmp"
echo "built $repo/isos/$host.iso (will erase $DEST_DEVICE without confirmation)"
