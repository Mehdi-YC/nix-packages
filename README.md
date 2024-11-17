#!/bin/bash

set -e  # Exit on error
set -o pipefail  # Fail if any command in a pipeline fails

# Ensure the script is run with an argument
if [ "$#" -ne 1 ]; then
    echo "Usage: $0 <target-architecture>"
    exit 1
fi

TARGET_ARCHITECTURE=$1
KERNEL_VERSION="6.10.6"
BUSYBOX_VERSION="1.36.1"
CROSS_COMPILE=""


if [ "$1" == "arm" ]; then
    sudo emerge  sys-devel/crossdev
    sudo emerge  app-eselect/eselect-repository
    sudo eselect repository create crossdev
    sudo crossdev -s4 -t arm-linux-gnueabi
    PORTAGE_CONFIGROOT="/usr/arm-linux-gnueabi"
    CROSS_COMPILE="arm-linux-gnueabi-"
fi


# Define URLs and filenames
KERNEL_URL="https://cdn.kernel.org/pub/linux/kernel/v6.x/linux-${KERNEL_VERSION}.tar.xz"
BUSYBOX_URL="https://busybox.net/downloads/busybox-${BUSYBOX_VERSION}.tar.bz2"
KERNEL_TAR="linux-${KERNEL_VERSION}.tar.xz"
BUSYBOX_TAR="busybox-${BUSYBOX_VERSION}.tar.bz2"
ROOTFS_DIR="rootfs-${TARGET_ARCHITECTURE}"

# Function to download files if they don't exist
download_file() {
    local url=$1
    local filename=$(basename "$url")
    if [ ! -f "$filename" ]; then
        echo "Downloading $filename..."
        wget -q "$url"
    else
        echo "$filename already exists, skipping download."
    fi
}

# Function to extract tar files
extract_file() {
    local file=$1
    local extension="${file##*.}"
    echo "Extracting $file..."
    case "$extension" in
        "xz")
            tar xf "$file"
            ;;
        "bz2")
            tar xjf "$file"
            ;;
        *)
            echo "Unsupported file type: $file"
            exit 1
            ;;
    esac
}

echo "Downloading source codes for Linux & BusyBox"
download_file "$KERNEL_URL"
download_file "$BUSYBOX_URL"

echo "Extracting source codes"
extract_file "$KERNEL_TAR"
extract_file "$BUSYBOX_TAR"

echo "Compiling the Linux kernel"
cd "linux-${KERNEL_VERSION}"
make ARCH=$TARGET_ARCHITECTURE defconfig
make -j$(nproc) ARCH=$TARGET_ARCHITECTURE
cd ..

echo "Compiling BusyBox"
cd "busybox-${BUSYBOX_VERSION}"
make ARCH=$TARGET_ARCHITECTURE $( [ -n "$CROSS_COMPILE" ] && echo "CROSS_COMPILE=$CROSS_COMPILE" ) defconfig
# Enable static binary option in BusyBox configuration
sed -i 's/# CONFIG_STATIC is not set/CONFIG_STATIC=y/' .config
if [ "$1" == "arm" ]; then
    # need to change other flags for this : http://lists.busybox.net/pipermail/busybox-cvs/2024-January/041752.html
    sed -i 's/CONFIG_TC=y/# CONFIG_TC is not set/' .config
    sed -i 's/CONFIG_FEATURE_TC_INGRESS=y/# CONFIG_FEATURE_TC_INGRESS is not set/' .config
fi
make -j$(nproc) ARCH=$TARGET_ARCHITECTURE
echo "Creating symlinks for the binaries"
make ARCH=$TARGET_ARCHITECTURE C$( [ -n "$CROSS_COMPILE" ] && echo "CROSS_COMPILE=$CROSS_COMPILE" ) install



cd ..

echo "Creating the filesystem structure"
mkdir -p "${ROOTFS_DIR}/home" "${ROOTFS_DIR}/bin" "${ROOTFS_DIR}/lib" "${ROOTFS_DIR}/sbin" "${ROOTFS_DIR}/etc" "${ROOTFS_DIR}/proc" "${ROOTFS_DIR}/sys" "${ROOTFS_DIR}/tmp" "${ROOTFS_DIR}/var"
touch "${ROOTFS_DIR}/etc/passwd" "${ROOTFS_DIR}/etc/group" "${ROOTFS_DIR}/etc/resolv.conf"

echo "nameserver 8.8.8.8" >>  "${ROOTFS_DIR}/etc/resolv.conf"

# Copy the kernel and BusyBox binaries into the root filesystem
cp "linux-${KERNEL_VERSION}/arch/${TARGET_ARCHITECTURE}/boot/*zImage" "./bzImage-${TARGET_ARCHITECTURE}"
cp -r "busybox-${BUSYBOX_VERSION}/_install/"* "${ROOTFS_DIR}/"

echo "Creating init script"
cat <<EOF > "${ROOTFS_DIR}/init"
#!/bin/sh
mount -t sysfs sysfs /sys
mount -t proc proc /proc
mount -t devtmpfs udev /dev
clear
echo "Hello hackathon! from arch=${TARGET_ARCHITECTURE}"
exec /bin/sh
EOF
chmod +x "${ROOTFS_DIR}/init"

cd "${ROOTFS_DIR}"

find . -print0 | cpio --null -ov --format=newc | gzip -9 > ../rootfs-${TARGET_ARCHITECTURE}.cpio.gz
#tar -cf ../rootfs-${TARGET_ARCHITECTURE}.img .
echo "Booting with QEMU"
qemu-system-${TARGET_ARCHITECTURE} -kernel "bzImage-${TARGET_ARCHITECTURE}" -initrd rootfs-${TARGET_ARCHITECTURE}.cpio.gz




echo "FINAL STEP: the ISO"

mkdir -p iso-${TARGET_ARCHITECTURE}/boot/grub
cp "bzImage-${TARGET_ARCHITECTURE}" "iso-${TARGET_ARCHITECTURE}/boot/"
cp "rootfs-${TARGET_ARCHITECTURE}.cpio.gz" "iso-${TARGET_ARCHITECTURE}/boot/"
cat <<EOF > "iso-${TARGET_ARCHITECTURE}/boot/grub/grub.cfg"
set default=0
set timeout=10
menuentry 'Hackathon-${TARGET_ARCHITECTURE}' --class os {
    insmod gzio
    insmod part_msdos
    linux /boot/bzImage-${TARGET_ARCHITECTURE}
    initrd /boot/rootfs-${TARGET_ARCHITECTURE}.cpio.gz
}
EOF
grub2-mkrescue -o Hackathon${TARGET_ARCHITECTURE}.iso iso-${TARGET_ARCHITECTURE}/ || grub-mkrescue -o Hackathon.iso iso-${TARGET_ARCHITECTURE}/

qemu-system-${TARGET_ARCHITECTURE} -cdrom Hackathon.iso -boot d -m 512
