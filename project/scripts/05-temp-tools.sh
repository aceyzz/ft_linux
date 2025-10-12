set -euo pipefail
cd "$LFS/sources"

# ===== m4 =====
rm -rf m4-1.4.19 && tar -xf m4-1.4.19.tar.xz && cd m4-1.4.19
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_GL_ATTRIBUTE_NODISCARD=" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
perl -0777 -pe 's/#\s*define\s+_GL_ATTRIBUTE_NODISCARD.*/#define _GL_ATTRIBUTE_NODISCARD/' -i config.h lib/config.h
sed -i 's/_GL_ATTRIBUTE_NODISCARD[[:space:]]\+//g' lib/gl_oset.h
make clean
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== ncurses =====
rm -rf ncurses-6.5-20250809 && tar -xf ncurses-6.5-20250809.tgz && cd ncurses-6.5-20250809
sed -i s/mawk// configure
mkdir -p build && cd build
../configure --prefix=/usr --host="$LFS_TGT" --build="$(../config.guess)" \
  --mandir=/usr/share/man --with-shared --without-debug --without-ada \
  --disable-stripping --enable-widec
make -j"$(nproc)"
make DESTDIR="$LFS" install
ln -sfv libncursesw.so "$LFS/usr/lib/libncurses.so"
cd ../..

# ===== bash =====
rm -rf bash-5.3 && tar -xf bash-5.3.tar.gz && cd bash-5.3
./configure --prefix=/usr --build="$(./support/config.guess)" --host="$LFS_TGT" --without-bash-malloc
make -j"$(nproc)"
make DESTDIR="$LFS" install
ln -sv bash "$LFS/usr/bin/sh" || true
cd ..

# ===== coreutils =====
rm -rf coreutils-9.7
tar -xf coreutils-9.7.tar.xz
cd coreutils-9.7
patch -Np1 -i ../coreutils-9.7-i18n-1.patch
patch -Np1 -i ../coreutils-9.7-upstream_fix-1.patch
CPPFLAGS="-DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_GL_ATTRIBUTE_NODISCARD=" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)" \
  --enable-no-install-program=kill,uptime
make clean
make -j"$(nproc)"
make DESTDIR="$LFS" CPPFLAGS="-DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_GL_ATTRIBUTE_NODISCARD=" install
mv -v "$LFS/usr/bin/chroot" "$LFS/usr/sbin/" || true
cd ..

# ===== diffutils =====
cd "$LFS/sources"
rm -rf diffutils-3.12
tar -xf diffutils-3.12.tar.xz
cd diffutils-3.12
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096" \
gl_cv_func_strcasecmp_works=yes \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== file =====
rm -rf file-5.46 && tar -xf file-5.46.tar.gz && cd file-5.46
mkdir -p build-host && pushd build-host
../configure --prefix=/usr
make -j"$(nproc)"
popd
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./config.guess)"
make -j"$(nproc)" FILE_COMPILE=$(pwd)/build-host/src/file
make DESTDIR="$LFS" install
rm -rf build-host
cd ..

# ===== findutils =====
cd "$LFS/sources"
rm -rf findutils-4.10.0
tar -xf findutils-4.10.0.tar.xz
cd findutils-4.10.0
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096 -include limits.h" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096 -include limits.h" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== gawk =====
rm -rf gawk-5.3.2 && tar -xf gawk-5.3.2.tar.xz && cd gawk-5.3.2
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== grep =====
cd "$LFS/sources"
rm -rf grep-3.12
tar -xf grep-3.12.tar.xz
cd grep-3.12
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096 -include limits.h" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -DPATH_MAX=4096 -include limits.h" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== gzip =====
cd "$LFS/sources"
rm -rf gzip-1.14
tar -xf gzip-1.14.tar.xz
cd gzip-1.14
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -include limits.h" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -include limits.h" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== make =====
rm -rf make-4.4.1 && tar -xf make-4.4.1.tar.gz && cd make-4.4.1
./configure --prefix=/usr --host="$LFS_TGT" --build="$(build-aux/config.guess)"
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== patch =====
cd "$LFS/sources"
rm -rf patch-2.8
tar -xf patch-2.8.tar.xz
cd patch-2.8
CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -include limits.h" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make CPPFLAGS="-I$LFS/usr/include -DMB_LEN_MAX=16 -include limits.h" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== sed =====
cd "$LFS/sources"
rm -rf sed-4.9
tar -xf sed-4.9.tar.xz
cd sed-4.9
CPPFLAGS="-DMB_LEN_MAX=16 -include limits.h" \
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make CPPFLAGS="-DMB_LEN_MAX=16 -DPATH_MAX=4096 -include limits.h" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== tar =====
rm -rf tar-1.35 && tar -xf tar-1.35.tar.xz && cd tar-1.35
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)"
make CPPFLAGS="-DMB_LEN_MAX=16 -DPATH_MAX=4096 -include limits.h" -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== xz =====
rm -rf xz-5.8.1 && tar -xf xz-5.8.1.tar.xz && cd xz-5.8.1
./configure --prefix=/usr --host="$LFS_TGT" --build="$(./build-aux/config.guess)" \
  --disable-static --docdir=/usr/share/doc/xz
make -j"$(nproc)"
make DESTDIR="$LFS" install
cd ..

# ===== cleanup =====
find "$LFS/usr/lib" -type f -name '*.la' -delete || true