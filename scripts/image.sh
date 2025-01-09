#!/usr/bin/env bash
# Derived from github.com/pavel-demin/red-pitaya-notes, licensed under
# the MIT license.
# Requirements:
#   - rsync
#   - debootstrap
#   - qemu-user-static
#   - qemu-user-static-binfmt
#       (or binfmt-support, qemu-user-binfmt on debian based)
#
# Generates the build/red-pitaya-debian-*.img file. This can be flashed
# to an SD card using 'dd if=build/red-pitaya-*.img of=/dev/<sd-card-path> bs=4M'

set -euo pipefail
shopt -s extglob

USAGE="Usage: $0 {base,boot,kernel,software,fpga,full} PROJECT [-l linuxdir] [files]"

if [[ "$#" -lt 2 ]]; then
    echo "$USAGE" 1>&2
    exit 1
fi

# First parameter is the mode that determines the steps invloved in building
# the image
MODE="$1"
shift
PROJECT_NAME="$1"
shift

# Parse all remaining arguments
files=()
while [[ "$#" -gt 0 ]]; do
    case "$1" in
        -l|--linux)
            # Linux directory is fixed by cli parameter
            LINUX_DIR="$2"
            if [[ ! -d "$LINUX_DIR" ]]; then
                echo "Error: '$LINUX_DIR' is not a directory." 1>&2
                exit 1
            fi
            shift
            shift
            ;;
        *)
            # Add argument to list of files copied to /usr/bin
            files+=("$1")
            shift
            ;;
    esac
done


BUILD_DIR="./build"
BUILD_DIR_IMAGE="$BUILD_DIR/image"
mkdir -p "$BUILD_DIR_IMAGE"

# Debian related settings
DEBIAN_SUITE="bookworm"
DEBIAN_ARCH="armhf"
DEBIAN_PACKAGES="locales,exfatprogs,openssh-server,ca-certificates,fake-hwclock,usbutils,python3,ipython3,psmisc,lsof,vim,curl,wget,dhcpcd"
DEBIAN_PASSWORD="redpitaya"
DEBIAN_HOSTNAME="redpitaya"

if [[ "$MODE" == "kernel" || "$MODE" == "full" ]]; then
    # Linux (kernel) related settings
    if [[ ! -v LINUX_DIR ]]; then
        _linux_dirs=( "$BUILD_DIR"/linux-+([0-9]).+([0-9]) )
        LINUX_DIR="${_linux_dirs[${#_linux_dirs[@]}-1]}"
    fi
    # Using latest linux version "
    KERNEL_MOD_DIR="$BUILD_DIR/kernel"
    LINUX_VERSION_FULL="$(make -s -C "$LINUX_DIR" kernelversion)-xilinx"
fi

IMAGE_FILE_BASE="$BUILD_DIR_IMAGE/red-pitaya-debian-$DEBIAN_SUITE-$DEBIAN_ARCH-base.img"
IMAGE_FILE_FINAL="$BUILD_DIR/red-pitaya-debian-$DEBIAN_SUITE-$DEBIAN_ARCH.img"

cleanup() {
    # Unmount all devices and delete temporary directories
    if [[ -v BOOT_DIR ]]; then
        sudo umount "$BOOT_DIR"
        sudo rm -r -- "$BOOT_DIR"
        unset -v BOOT_DIR
    fi
    if [[ -v ROOT_DIR ]]; then
        sudo umount "$ROOT_DIR"
        sudo rm -r -- "$ROOT_DIR"
        unset -v ROOT_DIR
    fi
    # Remove the loop device
    if [[ -v DEV ]]; then
        sudo losetup -d "$DEV"
        unset -v DEV
    fi
}
trap "cleanup" EXIT

create_image() {
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: $0 imagefile" 1>&2
        exit 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a file" 1>&2
        exit 1
    fi
    # Generate image of size bs*count
    dd if=/dev/zero of="$1" bs=1M count=1024
}

create_loop_device() {
    if [[ -v DEV ]]; then
        # Nothing to do, loop device already created
        return 0
    fi
    if [[ "$#" -ne 1 ]]; then
        echo "Usage: create_loop_device imagefile" 1>&2
        exit 1
    fi
    if [[ ! -f "$1" ]]; then
        echo "Error: '$1' is not a file" 1>&2
        exit 1
    fi
    echo "Create loop device for image"
    DEV=$(sudo losetup --show -f "$1")
}

create_partition_table() {
    if [[ ! -b "$DEV" ]]; then
        echo "Error: '$DEV' is not a valid block device" 1>&2
        exit 1
    fi
    if [[ -v BOOT_PART && -v ROOT_PART ]]; then
        # Nothing to do, partitions already defined
        return 0
    fi
    echo "Create partition table for '$DEV'"
    # Create partitions for the image
    sudo parted -s "$DEV" mklabel msdos > /dev/null
    # Boot partition
    sudo parted -s "$DEV" mkpart primary fat16 4MiB 16MiB > /dev/null
    # Root partition
    sudo parted -s "$DEV" mkpart primary ext4 16MiB 100% > /dev/null
    
    BOOT_PART="$DEV""p1"
    ROOT_PART="$DEV""p2"
}

format_partitions() {
    if [[ ! -b "$ROOT_PART" || ! -b "$BOOT_PART" ]]; then
        echo "Error: Partitions '$BOOT_PART', '$ROOT_PART' not found" 1>&2
        exit 1
    fi
    echo "Format partitions '$BOOT_PART' and '$ROOT_PART'"
    # Make the file systems
    sudo mkfs.vfat -v "$BOOT_PART" > /dev/null
    sudo mkfs.ext4 -F -j "$ROOT_PART" /dev/null
}

mount_boot() {
    if [[ ! -v BOOT_DIR ]]; then
        BOOT_DIR=$(mktemp --tmpdir="$BUILD_DIR_IMAGE" -d)
        echo "Mount boot partition to '$BOOT_DIR'"
        sudo mount "$BOOT_PART" "$BOOT_DIR"
    fi
}

mount_root() {
    if [[ ! -v ROOT_DIR ]]; then
        ROOT_DIR=$(mktemp --tmpdir="$BUILD_DIR_IMAGE" -d)
        echo "Mount root partition to '$ROOT_DIR'"
        sudo mount "$ROOT_PART" "$ROOT_DIR"
    fi
}

copy_bootloader() {
    echo "Copy bootloader to boot partition"
    sudo cp "$BUILD_DIR/boot.bin" "$BOOT_DIR/boot.bin"
}

setup_debian() {
    # Prepare Debian system
    echo "Prepare packages for Debian (debootstrap --foreign)"
    sudo debootstrap --foreign --include="$DEBIAN_PACKAGES" --arch "$DEBIAN_ARCH" "$DEBIAN_SUITE" "$ROOT_DIR" > /dev/null
    echo "Copy /usr/bin/qemu-arm-static to root"
    sudo cp /usr/bin/qemu-arm-static "$ROOT_DIR/usr/bin/"
    echo "Enter chroot to prepare system (debootstrap --second-stage)"
    echo "This may take a while..."
    sudo chroot "$ROOT_DIR" /bin/bash <<EOF > /dev/null
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
    echo "Remove /usr/bin/qemu-arm-static from root"
    sudo rm -- "$ROOT_DIR/usr/bin/qemu-arm-static"
}

setup_kernel_modules() {
    echo "Copy modules from Linux kernel to root partition"
    sudo mkdir -p -- "$ROOT_DIR/lib"
    sudo cp -r -- "$KERNEL_MOD_DIR/lib/modules" "$ROOT_DIR/lib/"
    echo "Enable 'dmadc' module on boot"
    echo "dmadc" | sudo tee "$ROOT_DIR/etc/modules-load.d/dmadc.conf" > /dev/null
    echo "Remove symlink to original build dir"
    sudo rm -rf -- "$ROOT_DIR/lib/modules/$LINUX_VERSION_FULL/build"
    echo "Generate kernel module dependencies"
    sudo depmod -a -b "$ROOT_DIR" "$LINUX_VERSION_FULL"
}

setup_fpga() {
    # Copy device tree overlay and bin file
    _firmware_dir="$ROOT_DIR/lib/firmware"
    echo "Create /lib/firmware directory"
    sudo mkdir -p -- "$_firmware_dir"
    _bin_file="$BUILD_DIR/projects/$PROJECT_NAME/$PROJECT_NAME.bin"
    _dtbo_file="$BUILD_DIR/projects/$PROJECT_NAME/pl.dtbo"
    if [[ -f "$_bin_file" ]]; then
        echo "Copy FPGA bitstream file"
        sudo cp -- "$_bin_file" "$_firmware_dir"
        sudo cp -- "$_bin_file" "$ROOT_DIR/root"
    fi
    if [[ -f "$_dtbo_file" ]]; then
        echo "Copy FPGA device tree overlay"
        sudo cp -- "$_dtbo_file" "$_firmware_dir"
        sudo cp -- "$_dtbo_file" "$ROOT_DIR/root"
    fi
}

setup_software() {
    # Copy utilities
    files=("$@")
    files+=("./linux/resize-sd" "$BUILD_DIR/fpgautil")
    for file in "${files[@]}"; do
        echo "Copy '$(basename "$file")' to /usr/bin"
        sudo cp -- "$file" "$ROOT_DIR/usr/bin"
    done
}

base(){
    touch "$IMAGE_FILE_BASE"
    create_image "$IMAGE_FILE_BASE"
    create_loop_device "$IMAGE_FILE_BASE"
    create_partition_table
    format_partitions
    mount_root
    setup_debian
}

boot() {
    create_loop_device "$IMAGE_FILE_FINAL"
    create_partition_table
    mount_boot
    copy_bootloader
}

kernel() {
    create_loop_device "$IMAGE_FILE_FINAL"
    create_partition_table
    mount_root
    setup_kernel_modules
}

software() {
    create_loop_device "$IMAGE_FILE_FINAL"
    create_partition_table
    mount_root
    # Pass files to 'setup_software'
    setup_software "${files[@]}"
}

fpga() {
    create_loop_device "$IMAGE_FILE_FINAL"
    create_partition_table
    mount_root
    setup_fpga
}

case "$MODE" in
    base|full)
        echo "Building base image"
        base
        cleanup
        # Remove old image file if it already exist
        if [[ -f "$IMAGE_FILE_FINAL" ]]; then
            rm -- "$IMAGE_FILE_FINAL"
        fi
        cp "$IMAGE_FILE_BASE" "$IMAGE_FILE_FINAL"
        ;;&
    base)
        # nothing left to be done
        ;;
    full)
        echo "Building full image"
        boot
        kernel
        software
        fpga
        ;;
    boot|kernel|software|fpga)
        if [[ ! -f "$IMAGE_FILE_FINAL" ]]; then
            echo \
                "Error: File '$IMAGE_FILE_FINAL' does not exist. " \
                "Build 'base' image first" 1>&2
            echo "$USAGE" 1>&2
            exit 1
        fi
        ;;&
    boot)
        boot
        ;;
    kernel)
        kernel
        ;;
    software)
        software
        ;;
    fpga)
        fpga
        ;;
    *)
        echo "Error: Unknown mode '$MODE'" 1>&2
        echo "$USAGE" 1>&2
        exit 1
        ;;
esac
