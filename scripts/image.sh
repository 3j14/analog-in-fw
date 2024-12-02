#!/usr/bin/env bash
# Derived from github.com/pavel-demin/red-pitaya-notes, licensed under
# the MIT license.
# Requirements:
#   - rsync
#   - debootstrap
#   - qemu-user-static
#   - qemu-user-static-binfmt
#       (or binfmt-support, qemu-user-binfmt on debian based)
#   - resize2fs (optional)
#
# Generates the build/red-pitaya-debian-*.img file. This can be flashed
# to an SD card using 'dd if=build/red-pitaya-*.img of=/dev/<sd-card-path> bs=4M'

set -euxo pipefail

BUILD_DIR="./build"
DEBIAN_SUITE="bookworm"
DEBIAN_ARCH="armhf"
LINUX_DIR="./build/linux-6.11"
LINUX_VERSION="6.11.32-xilinx"
IMAGE_FILE="$BUILD_DIR/red-pitaya-debian-$DEBIAN_SUITE-$DEBIAN_ARCH.img"
DEBIAN_PACKAGES="locales,openssh-server,ca-certificates,fake-hwclock,usbutils,psmisc,lsof,vim,curl,wget,dnsmasq,dhcpcd"
DEBIAN_PASSWORD="redpitaya"
DEBIAN_HOSTNAME="redpitaya"

BOOT_DIR=$(mktemp -d)
ROOT_DIR=$(mktemp -d)
# Remove directories after exit
traps='rm -rf -- "$BOOT_DIR" "$ROOT_DIR"'
trap "$traps" EXIT

# If the image already exist, delete it
if [[ -f "$IMAGE_FILE" ]]; then
    rm -- "$IMAGE_FILE"
fi
# Generate image of size bs*count
dd if=/dev/zero of="$IMAGE_FILE" bs=1M count=1024

# Create loop device for image
DEV=$(sudo losetup --show -f "$IMAGE_FILE")
traps='sudo losetup -d "$DEV" && '$traps
trap "$traps" EXIT

# Create partitions for the image
sudo parted -s "$DEV" mklabel msdos
# Boot partition
sudo parted -s "$DEV" mkpart primary fat16 4MiB 16MiB
# Root partition
sudo parted -s "$DEV" mkpart primary ext4 16MiB 100%

BOOT_PART="$DEV""p1"
ROOT_PART="$DEV""p2"
# Check if the partitions have the expected name
if [[ ! -b "$ROOT_PART" || ! -b "$BOOT_PART" ]]; then
    echo "Error: Partitions $BOOT_PART, $ROOT_PART not found"
    exit 1
fi

# Make the file systems
sudo mkfs.vfat -v $BOOT_PART
sudo mkfs.ext4 -F -j $ROOT_PART

# Mount the two partitions to their temporary directories
sudo mount $BOOT_PART $BOOT_DIR
sudo mount $ROOT_PART $ROOT_DIR
traps='sudo umount "$BOOT_DIR" && sudo umount "$ROOT_DIR" && '$traps
trap "$traps" EXIT

# Copy the bootloader
sudo cp "$BUILD_DIR/boot.bin" "$BOOT_DIR/boot.bin"
sudo umount "$BOOT_DIR"
sudo rm -rf -- "$BOOT_DIR"
traps='sudo umount "$ROOT_DIR" && sudo losetup -d "$DEV" && rm -rf -- "$BOOT_DIR"'
trap "$traps" EXIT

# Prepare Debian system
sudo debootstrap --foreign --include="$DEBIAN_PACKAGES" --arch "$DEBIAN_ARCH" "$DEBIAN_SUITE" "$ROOT_DIR"

# Copy modules from Linux Kernel
MOD_DIR="$ROOT_DIR/lib/modules/$LINUX_VERSION"
sudo mkdir -p "$MOD_DIR/kernel"
find "$LINUX_DIR" -name \*.ko -printf '%P\n' | sudo rsync -ahrH --no-inc-recursive --chown=0:0 --files-from=- "$LINUX_DIR" "$MOD_DIR/kernel"
sudo cp "$LINUX_DIR/modules.order" "$LINUX_DIR/modules.builtin" "$LINUX_DIR/modules.builtin.modinfo" "$MOD_DIR/"
sudo depmod -a -b $ROOT_DIR $LINUX_VERSION

# Copy the resize utility and make sure it is executable
sudo cp ./linux/resize.sh "$ROOT_DIR/usr/bin/resize-sd"
sudo chmod +x "$ROOT_DIR/usr/bin/resize-sd"

# Prepare the chroot environment (requires QEMU)
sudo cp /usr/bin/qemu-arm-static "$ROOT_DIR/usr/bin/"
# Enter chroot
sudo chroot "$ROOT_DIR" qemu-arm-static /bin/bash <<EOF
export LANG=C
export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

/debootstrap/debootstrap --second-stage
apt-get update
sed -i "/^# en_US.UTF-8 UTF-8$/s/^# //" etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

systemctl enable dnsmasq
systemctl enable nftables
systemctl enable dhcpcd

sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' etc/ssh/sshd_config

echo "root:$DEBIAN_PASSWORD" | chpasswd
apt-get clean
touch etc/hostname
echo "$DEBIAN_HOSTNAME" > etc/hostname
history -c
sync
EOF

# Remove QEMU from image
sudo rm -- "$ROOT_DIR/usr/bin/qemu-arm-static"

# Un-mount image
sudo umount "$ROOT_DIR"
sudo rm -rf -- "$ROOT_DIR"
trap 'sudo losetup -d "$DEV"' EXIT

# if command -v 'resize2fs'; then
#     sudo resize2fs -M "$ROOT_PART"
# fi
