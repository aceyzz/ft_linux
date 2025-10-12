set -euo pipefail
cd "$LFS/sources"

# ===== m4 =====
rm -rf m4-*/ && tar -xf m4-*.tar.* && cd m4-*/
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_GL_ATTRIBUTE_NODISCARD=" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
perl -0777 -pe 's/#\s*define\s+_GL_ATTRIBUTE_NODISCARD.*/#define _GL_ATTRIBUTE_NODISCARD/' \
  -i config.h lib/config.h
sed -i 's/_GL_ATTRIBUTE_NODISCARD[[:space:]]\+//g' lib/gl_oset.h
make clean
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== ncurses =====
rm -rf ncurses-*/ && tar -xf ncurses-*.tar.* && cd ncurses-*/
sed -i s/mawk// configure
mkdir build && cd build
../configure --prefix=/usr --host="$LFS_TGT" --build="$(../config.guess)" \
  --mandir=/usr/share/man --with-shared --without-debug --without-ada \
  --disable-stripping --enable-widec
make -j"$(nproc)"
make DESTDIR="$LFS" install
ln -sfv libncursesw.so "$LFS/usr/lib/libncurses.so"
cd ../..

# ===== bash =====
rm -rf bash-*/ && tar -xf bash-*.tar.* && cd bash-*/
./configure --prefix=/usr --build="$(./support/config.guess)" --host="$LFS_TGT" \
  --without-bash-malloc
make -j"$(nproc)"
make DESTDIR="$LFS" install
ln -sv bash "$LFS/usr/bin/sh" || true
cd ..

# ===== coreutils =====
rm -rf coreutils-*/ && tar -xf coreutils-*.tar.* && cd coreutils-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)" \
  --enable-no-install-program=kill,uptime
make -j"$(nproc)"
make DESTDIR="$LFS" install
mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin/" || true
cd ..

# ===== diffutils =====
rm -rf diffutils-*/ && tar -xf diffutils-*.tar.* && cd diffutils-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== file =====
rm -rf file-*/ && tar -xf file-*.tar.* && cd file-*/
mkdir build-host && pushd build-host
../configure --prefix=/usr
make -j"$(nproc)"
popd
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)"
make -j"$(nproc)" FILE_COMPILE=$(pwd)/build-host/src/file
make DESTDIR="$LFS" install
rm -rf build-host
cd ..

# ===== findutils =====
rm -rf findutils-*/ && tar -xf findutils-*.tar.* && cd findutils-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== gawk =====
rm -rf gawk-*/ && tar -xf gawk-*.tar.* && cd gawk-*/
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== grep =====
rm -rf grep-*/ && tar -xf grep-*.tar.* && cd grep-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== gzip =====
rm -rf gzip-*/ && tar -xf gzip-*.tar.* && cd gzip-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== make =====
rm -rf make-*/ && tar -xf make-*.tar.* && cd make-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== patch =====
rm -rf patch-*/ && tar -xf patch-*.tar.* && cd patch-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== sed =====
rm -rf sed-*/ && tar -xf sed-*.tar.* && cd sed-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== tar =====
rm -rf tar-*/ && tar -xf tar-*.tar.* && cd tar-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== xz =====
rm -rf xz-*/ && tar -xf xz-*.tar.* && cd xz-*/
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)" \
  --disable-static --docdir=/usr/share/doc/xz
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== cleanup =====
find "$LFS/usr/lib" -type f -name '*.la' -delete || true