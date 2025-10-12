#!/bin/bash
set -euo pipefail

# ---- couleurs ----
R(){ echo -e "\033[0;31m[ERROR]\033[0m $*"; }
Y(){ echo -e "\033[0;33m[INFO]\033[0m  $*"; }
G(){ echo -e "\033[0;32m[SUCCESS]\033[0m $*"; }

# ---- env ----
: "${LFS:?LFS non défini}"
: "${LFS_TGT:?LFS_TGT non défini}"
[[ "$PATH" == "$LFS/tools/bin:"* ]] || { R "PATH ne commence pas par $LFS/tools/bin"; exit 1; }

SRC_DIR="$LFS/sources"
GCC_PKG="gcc-15.2.0"
GCC_TARBALL="$SRC_DIR/$GCC_PKG.tar.xz"
BUILD_DIR="$SRC_DIR/$GCC_PKG/build-libstdcxx"

# glibc/headers
[[ -d "$LFS/usr/include/linux" ]] || { R "Linux headers absents: $LFS/usr/include/linux"; exit 1; }
[[ -e "$LFS/usr/lib/libc.so" || -e "$LFS/usr/lib/libc.so.6" ]] || { R "glibc pass1 non trouvée dans $LFS/usr/lib"; exit 1; }

command -v "$LFS_TGT-g++" >/dev/null || { R "$LFS_TGT-g++ introuvable dans PATH"; exit 1; }

# includes C++
GXX_INC_DIR="/tools/$LFS_TGT/include/c++/15.2.0"

Y "Build libstdc++ (pass 1) depuis $GCC_PKG"

# ---- sources ----
[[ -f "$GCC_TARBALL" ]] || { R "Archive absente: $GCC_TARBALL"; exit 1; }
cd "$SRC_DIR"
rm -rf "$SRC_DIR/$GCC_PKG" "$BUILD_DIR"
tar -xf "$GCC_TARBALL"
mkdir -pv "$BUILD_DIR"
cd "$BUILD_DIR"

# ---- config ----
Y "Configure libstdc++"
../libstdc++-v3/configure \
  --host="$LFS_TGT" \
  --build="$(../config.guess)" \
  --prefix=/usr \
  --disable-multilib \
  --disable-nls \
  --disable-libstdcxx-pch \
  --with-gxx-include-dir="$GXX_INC_DIR"

# ---- build ----
Y "Compilation"
make -j"$(nproc)" || { Y "Repli en -j1"; make -j1; }

# ---- install ----
Y "Installation sous \$LFS"
make DESTDIR="$LFS" install

# ---- checks ----
Y "Vérifications"
test -d "$LFS$GXX_INC_DIR" || { R "Répertoire d'includes C++ manquant: $LFS$GXX_INC_DIR"; exit 1; }
ls "$LFS/usr/lib"/libstdc++.so* >/dev/null 2>&1 || { R "libstdc++ non trouvée dans $LFS/usr/lib"; exit 1; }

# sanity check
cd "$SRC_DIR"
cat > hello.cpp <<'EOF'
#include <iostream>
int main(){ std::cout << "ok\n"; }
EOF
"$LFS_TGT-g++" hello.cpp
readelf -l a.out | grep -q '/ld-linux' || { R "L’interpréteur dynamique n’a pas été trouvé dans a.out"; exit 1; }
rm -f hello.cpp a.out

G "libstdc++ (pass 1) installé avec succès."

# ---- nettoyage sources ----
cd "$SRC_DIR"
rm -rf "$BUILD_DIR" "$SRC_DIR/$GCC_PKG"
G "Nettoyage terminé."

Y "Déplacement depuis lib64 vers lib"
mkdir -p $LFS/usr/lib
mv -v $LFS/usr/lib64/libstdc++.a $LFS/usr/lib/
rmdir $LFS/usr/lib64 2>/dev/null || true
