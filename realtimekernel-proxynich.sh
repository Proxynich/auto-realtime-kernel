#!/bin/bash

set -e

# Ambil versi kernel saat ini
KERNEL_VERSION=$(uname -r | cut -d'-' -f1)
MAJOR_VERSION=$(echo $KERNEL_VERSION | cut -d'.' -f1)
MINOR_VERSION=$(echo $KERNEL_VERSION | cut -d'.' -f2)
BASE_VERSION="$MAJOR_VERSION.$MINOR_VERSION"

echo "Detected kernel version: $KERNEL_VERSION"
echo "Using base version for RT patch: $BASE_VERSION"

# Buat direktori kerja
mkdir -p ~/rtkernel && cd ~/rtkernel

# Download kernel source
wget https://cdn.kernel.org/pub/linux/kernel/v$MAJOR_VERSION.x/linux-$KERNEL_VERSION.tar.xz
tar -xf linux-$KERNEL_VERSION.tar.xz
cd linux-$KERNEL_VERSION

# Download RT patch (deteksi otomatis versi yang cocok)
RT_PATCH_URL=$(curl -s https://cdn.kernel.org/pub/linux/kernel/projects/rt/ | grep "patch-$KERNEL_VERSION-rt" | grep ".patch.gz" | tail -1 | awk -F'"' '{print $2}')
if [[ -z "$RT_PATCH_URL" ]]; then
  echo "No RT patch found for $KERNEL_VERSION"
  exit 1
fi
wget https://cdn.kernel.org$RT_PATCH_URL
gzip -d $(basename $RT_PATCH_URL)
patch -p1 < $(basename $RT_PATCH_URL .gz)

# Gunakan konfigurasi kernel saat ini
cp -v /boot/config-$(uname -r) .config
yes "" | make oldconfig

# Kompilasi dan install kernel (lama, bisa 30–60 menit)
make -j$(nproc)
sudo make modules_install
sudo make install
