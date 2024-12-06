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

if [[ "$#" -lt 2 ]]; then
    echo "Usage: $0 project-name linux-version [files]"
    exit 1;
fi

BUILD_DIR="./build"
BUILD_DIR_TEMP="./build/image"
mkdir -p "$BUILD_DIR_TEMP"
DEBIAN_SUITE="bookworm"
DEBIAN_ARCH="armhf"
PROJECT_NAME="$1"
shift
LINUX_VERSION="$1"
shift
LINUX_DIR="./build/linux-$LINUX_VERSION"
LINUX_VERSION_FULL="$(make -s -C "$LINUX_DIR" kernelversion)-xilinx"
IMAGE_FILE_FINAL="$BUILD_DIR/red-pitaya-debian-$DEBIAN_SUITE-$DEBIAN_ARCH.img"
IMAGE_FILE="$(mktemp --tmpdir=$BUILD_DIR_TEMP)"
DEBIAN_PACKAGES="locales,exfatprogs,openssh-server,ca-certificates,fake-hwclock,usbutils,psmisc,lsof,vim,curl,wget,dhcpcd"
DEBIAN_PASSWORD="redpitaya"
DEBIAN_HOSTNAME="redpitaya"

cleanup() {
    # Unmount all devices and delete temporary directories
    if [[ -v BOOT_DIR ]]; then
        sudo umount "$BOOT_DIR"
    fi
    if [[ -v ROOT_DIR ]]; then
        sudo umount "$ROOT_DIR"
    fi
    rm -rf -- "$BUILD_DIR_TEMP"
    # Remove the loop device
    if [[ -v DEV ]]; then
        sudo losetup -d "$DEV"
    fi
}
trap "cleanup" EXIT

# Generate image of size bs*count
dd if=/dev/zero of="$IMAGE_FILE" bs=1M count=1024

# Create loop device for image
DEV=$(sudo losetup --show -f "$IMAGE_FILE")

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
sudo mkfs.vfat -v "$BOOT_PART"
sudo mkfs.ext4 -F -j "$ROOT_PART"

BOOT_DIR=$(mktemp --tmpdir="$BUILD_DIR_TEMP" -d)
ROOT_DIR=$(mktemp --tmpdir="$BUILD_DIR_TEMP" -d)

# Mount the two partitions to their temporary directories
sudo mount "$BOOT_PART" "$BOOT_DIR"
sudo mount "$ROOT_PART" "$ROOT_DIR"

# Copy the bootloader
sudo cp "$BUILD_DIR/boot.bin" "$BOOT_DIR/boot.bin"
sudo umount "$BOOT_DIR"
sudo rm -rf -- "$BOOT_DIR"
unset -v BOOT_DIR

# Prepare Debian system
sudo debootstrap --foreign --include="$DEBIAN_PACKAGES" --arch "$DEBIAN_ARCH" "$DEBIAN_SUITE" "$ROOT_DIR"

# Copy modules from Linux Kernel
MOD_DIR="$ROOT_DIR/lib/modules/$LINUX_VERSION_FULL"
sudo mkdir -p "$MOD_DIR/kernel"
find "$LINUX_DIR" -name \*.ko -printf '%P\n' | sudo rsync -ahrH --no-inc-recursive --chown=0:0 --files-from=- "$LINUX_DIR" "$MOD_DIR/kernel"
sudo cp "$LINUX_DIR/modules.order" "$LINUX_DIR/modules.builtin" "$LINUX_DIR/modules.builtin.modinfo" "$MOD_DIR/"
sudo depmod -a -b "$ROOT_DIR" "$LINUX_VERSION_FULL"

# Copy device tree overlay and bin file
_firmware_dir="$ROOT_DIR/lib/firmware"
sudo mkdir -p -- "$_firmware_dir"
_bin_file="$BUILD_DIR/projects/$PROJECT_NAME/$PROJECT_NAME.bin"
_dtbo_file="$BUILD_DIR/projects/$PROJECT_NAME/pl.dtbo"
if [[ -f "$_bin_file" ]]; then
    sudo cp -- "$_bin_file" "$_firmware_dir"
fi
if [[ -f "$_dtbo_file" ]]; then
    sudo cp -- "$_dtbo_file" "$_firmware_dir"
fi

# Copy utilities
sudo cp ./linux/resize.sh "$ROOT_DIR/usr/bin/resize-sd"
sudo chmod +x "$ROOT_DIR/usr/bin/resize-sd"
sudo cp "$BUILD_DIR/fpgautil" "$ROOT_DIR/usr/bin"
while [[ "$#" -gt 0 ]]; do
    # Copy file $1 to location $2
    sudo cp -- "$1" "$ROOT_DIR/usr/bin"
    shift
done

# Prepare the chroot environment (requires QEMU)
sudo cp /usr/bin/qemu-arm-static "$ROOT_DIR/usr/bin/"
# Enter chroot
sudo chroot "$ROOT_DIR" /bin/bash <<EOF
export LANG=C
export LC_ALL=C
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

/debootstrap/debootstrap --second-stage
apt-get update
sed -i "/^# en_US.UTF-8 UTF-8$/s/^# //" etc/locale.gen
locale-gen
update-locale LANG=en_US.UTF-8

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
rm -rf -- "$ROOT_DIR"
unset -v ROOT_DIR

# If the image already exist, delete it
if [[ -f "$IMAGE_FILE_FINAL" ]]; then
    rm -- "$IMAGE_FILE_FINAL"
fi
mv "$IMAGE_FILE" "$IMAGE_FILE_FINAL"
