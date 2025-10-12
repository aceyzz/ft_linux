#!/bin/bash
set -e

# --- couleurs ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RESET='\033[0m'

PKG=linux-6.16.1
SRC_DIR=$LFS/sources
BUILD_DIR=$SRC_DIR/$PKG

echo -e "${YELLOW}[INFO] Building $PKG API Headers${RESET}"

cd $SRC_DIR
rm -rf $BUILD_DIR
tar -xf $PKG.tar.xz
cd $PKG

echo -e "${YELLOW}[INFO] Cleaning source tree...${RESET}"
make mrproper

echo -e "${YELLOW}[INFO] Generating sanitized kernel headers...${RESET}"
make headers

echo -e "${YELLOW}[INFO] Cleaning up header tree...${RESET}"
find usr/include -name '.*' -delete
rm -f usr/include/Makefile

echo -e "${YELLOW}[INFO] Installing headers to $LFS/usr/include...${RESET}"
cp -rv usr/include $LFS/usr

echo -e "${GREEN}[SUCCESS] Linux API Headers installed successfully.${RESET}"

echo -e "${YELLOW}[INFO] Verifying installation...${RESET}"
ls -d $LFS/usr/include/{linux,asm,asm-generic} 2>/dev/null || {
    echo -e "${RED}[ERROR] Header directories missing.${RESET}"
    exit 1
}
echo -e "${GREEN}[OK] Header directories present.${RESET}"

echo -e "${YELLOW}[INFO] Cleaning up sources...${RESET}"
cd $SRC_DIR
rm -rf $BUILD_DIR
echo -e "${GREEN}[SUCCESS] $PKG build script completed.${RESET}"