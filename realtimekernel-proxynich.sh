#!/bin/bash

set -e

# === CONFIGURABLE ===
WORKDIR=~/rtkernel
MAKE_THREADS=$(nproc)

# === DETECT KERNEL VERSION ===
KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
MAJOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f1)
MINOR=$(echo "$KERNEL_VERSION" | cut -d'.' -f2)
BASE_VERSION="$MAJOR.$MINOR"

echo "[+] Detected running kernel: $KERNEL_VERSION"
echo "[+] Using base version: $BASE_VERSION"

# === PREPARE DEPENDENCIES ===
echo "[+] Installing build dependencies..."
sudo apt update
sudo apt install -y build-essential bc curl wget libncurses-dev flex bison libssl-dev libelf-dev git

# === PREPARE WORKDIR ===
mkdir -p "$WORKDIR"
cd "$WORKDIR"

# === DOWNLOAD KERNEL SOURCE ===
echo "[+] Downloading Linux kernel $KERNEL_VERSION source..."
wget -c https://cdn.kernel.org/pub/linux/kernel/v$MAJOR.x/linux-$KERNEL_VERSION.tar.xz
tar -xf linux-$KERNEL_VERSION.tar.xz
cd linux-$KERNEL_VERSION

# === DOWNLOAD RT PATCH ===
echo "[+] Searching for suitable RT patch..."
RT_PATCH_URL=$(curl -s https://cdn.kernel.org/pub/linux/kernel/projects/rt/$BASE_VERSION/ | grep "patch-$KERNEL_VERSION-rt" | grep ".patch.gz" | tail -1 | awk -F'"' '{print $2}')

if [[ -z "$RT_PATCH_URL" ]]; then
    echo "[!] ERROR: RT patch not found for kernel $KERNEL_VERSION"
    exit 1
fi

echo "[+] Found RT patch: $RT_PATCH_URL"
wget https://cdn.kernel.org$RT_PATCH_URL
gunzip $(basename "$RT_PATCH_URL")
PATCH_FILE=$(basename "$RT_PATCH_URL" .gz)

# === APPLY PATCH ===
echo "[+] Applying RT patch..."
patch -p1 < "$PATCH_FILE"

# === COPY CONFIG ===
echo "[+] Copying current kernel config..."
cp /boot/config-$(uname -r) .config
yes "" | make oldconfig

# === BUILD KERNEL ===
echo "[+] Building kernel, this may take a while (~30–60 minutes)..."
make -j"$MAKE_THREADS"
sudo make modules_install
sudo make install

# === UPDATE BOOTLOADER ===
echo "[+] Updating GRUB bootloader..."
sudo update-grub

echo "[+] DONE. Reboot to use the new RT kernel!"
