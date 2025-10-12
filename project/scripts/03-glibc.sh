#!/bin/bash
set -euo pipefail

# --- couleurs ---
R(){ echo -e "\033[0;31m[ERROR]\033[0m $*"; }
Y(){ echo -e "\033[0;33m[INFO]\033[0m  $*"; }
G(){ echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# --- env ---
: "${LFS:?LFS non défini}"
: "${LFS_TGT:?LFS_TGT non défini}"
[[ ":$PATH:" == *":$LFS/tools/bin:"* ]] || { R "PATH ne commence pas par $LFS/tools/bin"; exit 1; }

PKG=glibc-2.42
SRC_DIR="$LFS/sources"
BUILD_DIR="$SRC_DIR/$PKG/build"

# --- prérequis ---
[[ -d "$LFS/usr/include/linux" ]] || { R "Linux headers absents: $LFS/usr/include/linux"; exit 1; }
[[ -f "$SRC_DIR/$PKG.tar.xz" ]] || { R "Archive absente: $SRC_DIR/$PKG.tar.xz"; exit 1; }
[[ -f "$SRC_DIR/glibc-2.42-fhs-1.patch" ]] || { R "Patch FHS manquant: glibc-2.42-fhs-1.patch"; exit 1; }

Y "Build $PKG (pass 1)"

cd "$SRC_DIR"
rm -rf "$SRC_DIR/$PKG" || true
tar -xf "$PKG.tar.xz"
cd "$PKG"

Y "Patch FHS"
patch -Np1 -i ../glibc-2.42-fhs-1.patch

Y "Répertoire de build"
mkdir -v build
cd build

# --- build ---
echo "rootsbindir=/usr/sbin" > configparms

Y "Configure"
../configure \
  --prefix=/usr \
  --host="$LFS_TGT" \
  --build="$(../scripts/config.guess)" \
  --enable-kernel=3.2 \
  --with-headers="$LFS/usr/include" \
  libc_cv_slibdir=/usr/lib

Y "Compile (peut être long). Si échec, relance possible avec -j1"
make -j"$(nproc)" || { Y "Repli en -j1"; make -j1; }

Y "Install sous \$LFS"
make DESTDIR="$LFS" install

Y "Fix ldd"
sed '/RTLDLIST=/s@/usr@@g' -i "$LFS/usr/bin/ldd"

Y "Sanity check toolchain"
cd "$SRC_DIR"
cat > dummy.c << 'EOF'
int main() {}
EOF
"$LFS_TGT-gcc" dummy.c
if ! readelf -l a.out | grep -q '/ld-linux'; then
  R "readelf n'a pas trouvé l’interpréteur dynamique (/lib/ld-linux-*.so.*)"; exit 1
fi
rm -v dummy.c a.out

# --- headers ---
MKH="$LFS/tools/libexec/gcc/$LFS_TGT/15.2.0/install-tools/mkheaders"
if [[ -x "$MKH" ]]; then
  Y "mkheaders"
  "$MKH"
else
  R "mkheaders introuvable: $MKH"; exit 1
fi

G "$PKG installé (pass 1)."

# --- cleanup ---
Y "Nettoyage"
cd "$SRC_DIR"
rm -rf "$BUILD_DIR" "$SRC_DIR/$PKG"
rm -f dummy.c a.out

G "Nettoyage terminé."
exit 0