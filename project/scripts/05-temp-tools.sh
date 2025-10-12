#!/bin/bash
set -euo pipefail

# === CONFIG ===
LFS=${LFS:-/mnt/lfs}
LOGDIR="$LFS/sources/logs"
mkdir -p "$LOGDIR"

RED='\033[0;31m'; YEL='\033[0;33m'; GRN='\033[0;32m'; NC='\033[0m'
log(){ echo -e "${YEL}[INFO]${NC} $*"; }
ok(){ echo -e "${GRN}[OK]${NC} $*"; }
err(){ echo -e "${RED}[ERROR]${NC} $*" >&2; exit 1; }

cd "$LFS/sources"

[[ -d $LFS/tools ]] || err "Toolchain non monté."
[[ -d $LFS/usr/include/linux ]] || err "Linux headers absents."
[[ -x $(command -v "$LFS_TGT-gcc" || true) ]] || err "GCC cross non trouvé."

cleanup(){ rm -rf "$1" build; }

# --- FONCTION GENERIQUE ---
build_pkg(){
  local pkg="$1" tarball="$2" config_cmd="$3" make_opts="$4" post_install="${5:-true}"
  log "==== Building ${pkg} ===="
  rm -rf "$pkg" build
  tar -xf "$tarball"
  cd "$pkg"
  mkdir -p build
  cd build
  bash -c "$config_cmd" || err "$pkg configure failed"
  make -j$(nproc) $make_opts || { log "Repli en -j1"; make -j1 $make_opts; }
  make DESTDIR=$LFS install || err "$pkg install failed"
  cd ../..
  bash -c "$post_install"
  cleanup "$pkg"
  ok "$pkg OK"
}

# === 6.2 M4 ===================================================
build_pkg "m4-1.4.20" "m4-1.4.20.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" ""

# === 6.3 Ncurses ==============================================
log "==== Building ncurses-6.5 ===="
rm -rf ncurses-6.5 build
tar -xf ncurses-6.5-20250809.tgz
cd ncurses-6.5
sed -i s/mawk// configure
mkdir build
pushd build
  ../configure
  make -C include
  make -C progs tic
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess) \
  --mandir=/usr/share/man --with-manpage-format=normal \
  --with-shared --without-debug --without-ada --without-normal \
  --disable-stripping --enable-widec
make -j$(nproc)
make DESTDIR=$LFS TIC_PATH=$(pwd)/build/progs/tic install
echo "INPUT(-lncursesw)" > $LFS/usr/lib/libncurses.so
cd ..
cleanup ncurses-6.5
ok "ncurses-6.5 OK"

# === 6.4 Bash ================================================
build_pkg "bash-5.3" "bash-5.3.tar.gz" \
"./configure --prefix=/usr --build=\$(support/config.guess) --host=$LFS_TGT --without-bash-malloc" \
"" \
"ln -sv bash $LFS/bin/sh"

# === 6.5 Coreutils ============================================
build_pkg "coreutils-9.7" "coreutils-9.7.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess) \
 --enable-install-program=hostname --enable-no-install-program=kill,uptime" \
"" \
"mv -v $LFS/usr/bin/chroot $LFS/usr/sbin; \
 mkdir -pv $LFS/usr/share/man/man8; \
 mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8; \
 sed -i 's/\"1\"/\"8\"/' $LFS/usr/share/man/man8/chroot.8"

# === 6.6 Diffutils ============================================
build_pkg "diffutils-3.12" "diffutils-3.12.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT" ""

# === 6.7 File ================================================
log "==== Building file-5.46 ===="
rm -rf file-5.46 build
tar -xf file-5.46.tar.gz
cd file-5.46
mkdir build
pushd build
  ../configure --disable-bzlib --disable-libseccomp --disable-xzlib --disable-zlib
  make
popd
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
make FILE_COMPILE=$(pwd)/build/src/file
make DESTDIR=$LFS install
cd ..
cleanup file-5.46
ok "file-5.46 OK"


# === 6.8 Findutils ============================================
build_pkg "findutils-4.10.0" "findutils-4.10.0.tar.xz" \
"./configure --prefix=/usr --localstatedir=/var/lib/locate \
 --host=$LFS_TGT --build=\$(build-aux/config.guess)" ""

# === 6.9 Gawk =================================================
log "==== Building gawk-5.3.2 ===="
rm -rf gawk-5.3.2
tar -xf gawk-5.3.2.tar.xz
cd gawk-5.3.2
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host=$LFS_TGT --build=$(build-aux/config.guess)
make -j$(nproc)
make DESTDIR=$LFS install
cd ..
cleanup gawk-5.3.2
ok "gawk-5.3.2 OK"

# === 6.10 Grep ===============================================
build_pkg "grep-3.12" "grep-3.12.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT" ""

# === 6.11 Gzip ===============================================
build_pkg "gzip-1.14" "gzip-1.14.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT" ""

# === 6.12 Make ===============================================
build_pkg "make-4.4.1" "make-4.4.1.tar.gz" \
"./configure --prefix=/usr --without-guile --host=$LFS_TGT --build=\$(build-aux/config.guess)" ""

# === 6.13 Patch ==============================================
build_pkg "patch-2.8" "patch-2.8.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" ""

# === 6.14 Sed ================================================
build_pkg "sed-4.9" "sed-4.9.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT" ""

# === 6.15 Tar ================================================
build_pkg "tar-1.35" "tar-1.35.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess)" ""

# === 6.16 Xz ================================================
build_pkg "xz-5.8.1" "xz-5.8.1.tar.xz" \
"./configure --prefix=/usr --host=$LFS_TGT --build=\$(build-aux/config.guess) \
 --disable-static --docdir=/usr/share/doc/xz-5.8.1" ""

ok "Compilation + installation de la toolchain temporaire OK"