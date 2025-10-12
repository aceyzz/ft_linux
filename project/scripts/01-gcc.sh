#!/bin/bash
set -e

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

[ -z "$LFS" ] && { echo -e "${RED}[ERROR] LFS variable not set.${RESET}"; exit 1; }
[ -z "$LFS_TGT" ] && { echo -e "${RED}[ERROR] LFS_TGT variable not set.${RESET}"; exit 1; }
[ -z "$PATH" ] && { echo -e "${RED}[ERROR] PATH variable not set.${RESET}"; exit 1; }

PKG=gcc-15.2.0
SRC_DIR=$LFS/sources
BUILD_DIR=$SRC_DIR/$PKG/build

echo -e "${YELLOW}[INFO] Building $PKG (Pass 1)${RESET}"

cd $SRC_DIR
rm -rf $PKG $BUILD_DIR
tar -xf $PKG.tar.xz
cd $PKG

echo -e "${YELLOW}[INFO] Preparing dependencies (GMP, MPFR, MPC)...${RESET}"
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc

mkdir -v build
cd build

echo -e "${YELLOW}[INFO] Configuring...${RESET}"
../configure \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.42 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-initfini-array   \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-decimal-float   \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++

echo -e "${YELLOW}[INFO] Compiling...${RESET}"
make -j$(nproc)

echo -e "${YELLOW}[INFO] Installing...${RESET}"
make install

echo -e "${YELLOW}[INFO] Creating limits.h...${RESET}"
cd ..
cat gcc/limitx.h gcc/glimits.h gcc/limity.h > \
  "$(dirname $($LFS_TGT-gcc -print-libgcc-file-name))"/install-tools/include/limits.h

echo -e "${GREEN}[SUCCESS] $PKG (Pass 1) installed successfully.${RESET}"

echo -e "${YELLOW}[INFO] Check installation...${RESET}"
$LFS/tools/bin/$LFS_TGT-gcc --version
if [ $? -ne 0 ]; then
  echo -e "${RED}[ERROR] $PKG (Pass 1) installation failed.${RESET}"
  exit 1
else
  echo -e "${GREEN}[SUCCESS] $PKG (Pass 1) installation check passed.${RESET}"
fi

echo -e "${YELLOW}[INFO] Cleaning up...${RESET}"
cd $SRC_DIR
rm -rf $PKG $BUILD_DIR
echo -e "${GREEN}[SUCCESS] $PKG (Pass 1) build script completed.${RESET}"