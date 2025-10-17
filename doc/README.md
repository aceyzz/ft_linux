> Je travaille ce projet sur un MacBook Pro M3 Max 36go (2023) avec macOS Tahoe 26.1. Ma solution pour manager mes VMs est [UTM](https://mac.getutm.app/). Il se peut que certaines configurations soient différentes sur d'autres systèmes d'exploitation. Cette documentation me sert principalement de feuille de route afin de tracer chaque étape de la construction de ma LFS ARM64, mais peut être utile comme tuto étape par étape  

Basée sur la source de cette documentation : [Linux From Scratch for ARM64](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/index.html)  

## Préparation de l'hôte

Téléchargement de l'image Ubuntu ARMv8 (64 bits) Server 22.04.5 LTS  
https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.5-live-server-arm64.iso

Propriétés de la VM
```plaintext
Nom : ft_linux
Architecture : ARM64 (aarch64)
Version d'Ubuntu : 22.04.5 LTS
Mémoire RAM : 8192 Mo
Processeurs : 4
Disque dur1 : 64 Go (virtio)
Disque dur2 : 64 Go (virtio)
Réseau : Bridge (virtio-net-pci)
```

Installation d'Ubuntu
[Tutoriel dispo ici (UTM)](https://docs.getutm.app/guides/ubuntu/)  
[Sinon ici (Ubuntu)](https://ubuntu.com/tutorials/install-ubuntu-server#1-overview)  

> Une fois l'installation faite, redémarrer la VM et se connecter avec les identifiants créés lors de l'installation

Mise à jour de l'OS
```bash
sudo apt update && sudo apt upgrade -y
```

Installation SSH
```bash
sudo apt install openssh-server -y
sudo systemctl enable ssh
sudo systemctl start ssh
```
> Maintenant, depuis votre hôte, vous pouvez vous connecter en SSH à votre VM. A vous de voir si vous souhaitez changer la methode d'authentification SSH, le port par défaut...etc.
```bash
ssh username@ip-address
```

## Prérequis de l'hôte

### Logiciels

Logiciels avec version min. à vérfier/installer sur l'hôte
```plaintext
Bash-3.2
Binutils-2.13.1
Bison-2.7
Coreutils-8.1
Diffutils-2.8.1
Findutils-4.2.31
Gawk-4.0.1
GCC-5.4
Grep-2.5.1a
Gzip-1.3.12
Linux Kernel-5.4
M4-1.4.10
Make-4.0
Patch-2.5.4
Perl-5.8.8
Python-3.4
Sed-4.1.5
Tar-1.22
Texinfo-5.0
Xz-5.0.0
```
Script pour la verification automatique [disponible ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter02/hostreqs.html)

-> Si des paquets sont manquants, les installer via apt
```bash
sudo apt install package-name
```
-> Si des liens symboliques sont manquants, les créer (exemple avec bash)
```bash
sudo ln -sf bash /bin/sh
```

## Partitionnement du disque

### Création des partitions

Créer les partitions
```bash
sudo fdisk /dev/vdb
```
> A adapter selon le disque que vous utilisez

Dans fdisk
```plaintext
g                       # créer une table de partition GPT
n                       # nouvelle partition
(Enter)                 # partition 1
(Enter)                 # début par défaut
+1M                     # taille = 1M
t                       # changer le type
4                       # type = BIOS boot

n                       # nouvelle partition
(Enter)                 # partition 2
(Enter)                 # début par défaut
+200M                   # taille = 200M
t                       # changer le type
2                       # partition 2
20                      # type = Linux filesystem

n                       # nouvelle partition
(Enter)                 # partition 3
(Enter)                 # début par défaut
+4G                     # taille = 4G
t                       # changer le type
3                       # partition 3
19                      # type = Linux swap

n                       # nouvelle partition
(Enter)                 # partition 4
(Enter)                 # début par défaut
(Enter)                 # fin par défaut (utilise le reste)
w                       # sauvegarde et quitte
```

Formater les partitions
```bash
# boot
sudo mkfs -v -t ext2 /dev/vdb2
# root
sudo mkfs -v -t ext4 /dev/vdb4
# swap
sudo mkswap /dev/vdb3
sudo swapon /dev/vdb3
```

Vérifier le resultat
```bash
sudo fdisk -l /dev/vdb
# doit ressembler à ça :
#	Device       Start       End   Sectors  Size Type
#	/dev/vdb1     2048      4095      2048    1M BIOS boot
#	/dev/vdb2     4096    413695    409600  200M Linux filesystem
#	/dev/vdb3   413696   8802303   8388608    4G Linux swap
#	/dev/vdb4  8802304 134217694 125415391 59.8G Linux filesystem
```

### Montage des partitions

```bash
# mount root
sudo mkdir -pv /mnt/lfs
sudo mount -v -t ext4 /dev/vdb4 /mnt/lfs

# mount boot
sudo mkdir -pv /mnt/lfs/boot
sudo mount -v -t ext2 /dev/vdb2 /mnt/lfs/boot
```

Verifier que tout est bien monté
```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep vdb
# doit ressembler à ça :
#	NAME                       SIZE FSTYPE      MOUNTPOINT
#	vdb                         64G
#	├─vdb1                       1M
#	├─vdb2                     200M ext2        /mnt/lfs/boot
#	├─vdb3                       4G swap        [SWAP]
#	└─vdb4                    59.8G ext4        /mnt/lfs
```

(après chaque reboot, il faudra remonter les partitions)
```bash
# script a lancer en root
cat > mount_lfs.sh << "EOF"
#!/bin/bash
set -euo pipefail

DEV_ROOT=/dev/vdb4
DEV_BOOT=/dev/vdb2
DEV_SWAP=/dev/vdb3
MNT_ROOT=/mnt/lfs
MNT_BOOT=/mnt/lfs/boot

mkdir -p "$MNT_ROOT" "$MNT_BOOT"

mountpoint -q "$MNT_ROOT" || mount -t ext4 "$DEV_ROOT" "$MNT_ROOT"
mountpoint -q "$MNT_BOOT" || mount -t ext2 "$DEV_BOOT" "$MNT_BOOT"

swapon --show | awk '{print $1}' | grep -qx "$DEV_SWAP" || swapon "$DEV_SWAP"
EOF
chmod +x mount_lfs.sh
./mount_lfs.sh
```

(puis vérifier)
```bash
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT | grep vdb
mount | egrep 'vdb2|vdb4'
swapon --show
```

## Paquets et patchs

Passer en root
```bash
sudo su -
```

Set de l'environnement
```bash
export LFS=/mnt/lfs
```

Créer le dossier `sources`
```bash
mkdir -pv $LFS/sources
chmod -v a+wt $LFS/sources
```

Télécharger la liste des sources et leurs MD5
```bash
wget https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/wget-list-sysv
wget https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/md5sums
```
OU
```bash
wget https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/wget-list-sysv
wget https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/md5sums
```

Lancer le téléchargement
```bash
wget --input-file=wget-list-sysv --continue --directory-prefix=$LFS/sources
```
> Cette étape peut prendre pas mal de temps, va prendre un café

Vérifier les MD5
```bash
cp md5sums $LFS/sources
cd $LFS/sources
md5sum -c md5sums
rm md5sums
```
> Si tout est OK, continuez, sinon retéléchargez les fichiers corrompus [ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter03/packages.html) et [la](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter03/patches.html)

## Préparations finales

### Création des dossiers

> Toujours en root

```bash
mkdir -pv $LFS/{etc,var} $LFS/usr/{bin,lib,sbin}

for i in bin lib sbin; do
  ln -sv usr/$i $LFS/$i
done
```

Cross-compilation temporaire
```bash
mkdir -pv $LFS/tools
```

### Création de l'user lfs

```bash
groupadd lfs
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
```

Attribuer les droits aux dossiers
```bash
chown -v lfs $LFS/{usr{,/*},var,etc,tools}
```

### User LFS - environnement

Basculer sur l'utilisateur lfs
```bash
su - lfs
```

Créer profil bash
```bash
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
```

Créer bashrc
```bash
cat > ~/.bashrc << "EOF"
set +h
umask 022
LFS=/mnt/lfs
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:$PATH; fi
PATH=$LFS/tools/bin:$PATH
CONFIG_SITE=$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE
EOF
```

Ajouter nproc au .bashrc
```bash
cat >> ~/.bashrc << "EOF"
export MAKEFLAGS=-j$(nproc)
EOF
```

Recharger le profil bash
```bash
source ~/.bash_profile
```

## Construction Cross toolchain et outils temporaires

Passer a l'utilisateur `lfs`
```bash
su - lfs
```

Verifier l'environnement
```bash
echo $LFS
echo $LFS_TGT
# doit retourner : 
#   /mnt/lfs
#   aarch64-lfs-linux-gnu
# peut varier selon l'archi
```

Accéder au dossier `sources`
```bash
cd $LFS/sources
```

### Compilation des paquets

> Tout les programmes seront installés dans `/mnt/lfs/tools` (`$LFS/tools`). Les librairies par contre seront installées dans `/mnt/lfs/usr/lib` (`$LFS/usr/lib`), leur place definitive

Pour chaque compilation, ca sera a peu pres la même chose :
```plaintext
- extraire le package avec `tar`
- accéder au dossier extrait
- suivre les instructions de compilation
- revenir au dossier `sources` apres chaque compilation
- supprimer le dossier extrait apres chaque compilation
```

#### Binutils (pass 1)

Dossier de build
```bash
tar -xvf binutils-2.45.tar.xz
cd binutils-2.45
mkdir -v build
cd build
```

Configuration
```bash
time {
  ../configure --prefix=$LFS/tools \
             --with-sysroot=$LFS \
             --target=$LFS_TGT   \
             --disable-nls       \
             --enable-gprofng=no \
             --disable-werror    \
             --enable-new-dtags  \
             --enable-default-hash-style=gnu
}
```

Comilation et installation
```bash
time {
  make
  make install
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf binutils-2.45
```

#### GCC (pass 1)

Extraction
```bash
tar -xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
```

Dépendances
```bash
tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc
```

Specificité ARM64
```bash
sed -e '/lp64=/s/lib64/lib/' \
    -i.orig gcc/config/aarch64/t-aarch64-linux
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
time {
  ../configure                  \
    --target=$LFS_TGT         \
    --prefix=$LFS/tools       \
    --with-glibc-version=2.42 \
    --with-sysroot=$LFS       \
    --with-newlib             \
    --without-headers         \
    --enable-default-pie      \
    --enable-default-ssp      \
    --disable-nls             \
    --disable-shared          \
    --disable-multilib        \
    --disable-threads         \
    --disable-libatomic       \
    --disable-libgomp         \
    --disable-libquadmath     \
    --disable-libssp          \
    --disable-libvtv          \
    --disable-libstdcxx       \
    --enable-languages=c,c++
}
```

Compilation et installation
```bash
time {
  make
  make install
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf gcc-15.2.0
```

#### Linux API Headers

Extraction
```bash
tar -xvf linux-6.16.1.tar.xz
cd linux-6.16.1
```

Petit cleanup
```bash
make mrproper
```

Installation des headers
```bash
make headers
# puis deplacer les headers dans /mnt/lfs/usr/include
find usr/include -type f ! -name '*.h' -delete
cp -rv usr/include $LFS/usr
```

Cleanup
```bash
cd $LFS/sources
rm -rvf linux-6.16.1
```

#### Glibc

Extraction
```bash
tar -xvf glibc-2.42.tar.xz
cd glibc-2.42
```

Patch
```bash
patch -Np1 -i ../glibc-2.42-fhs-1.patch
```

Dossier de build
```bash
mkdir -v build
cd build
```

Paramétrage
```bash
echo "rootsbindir=/usr/sbin" > configparms
```

Configuration
```bash
time {
  ../configure                             \
      --prefix=/usr                      \
      --host=$LFS_TGT                    \
      --build=$(../scripts/config.guess) \
      --disable-nscd                     \
      libc_cv_slibdir=/usr/lib           \
      --enable-kernel=5.4
}
```

Compilation
> Attention : Par sécurité, il est préférable de lancer `make -j1` pour cette étape, car il peut y avoir des erreurs de compilation avec le multi-threading. Ce sera plus long, mais au moins ça passe
```bash
time {
  make -j1
}
```

Installation
```bash
time {
  make DESTDIR=$LFS install -j1
}
```

Fix des liens
```bash
sed '/RTLDLIST=/s@/usr@@g' -i $LFS/usr/bin/ldd
```

Sanity check (1)
```bash
echo 'int main(){}' | $LFS_TGT-gcc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
# doit retourner :
#      [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
# peut etre legerement different selon l'archi
```

Sanity check (2)
```bash
grep -E -o "$LFS/lib.*/S?crt[1in].*succeeded" dummy.log
# doit retourner :
#   /mnt/lfs/lib/../lib/Scrt1.o succeeded
#   /mnt/lfs/lib/../lib/crti.o succeeded
#   /mnt/lfs/lib/../lib/crtn.o succeeded
```

Sanity check (3)
```bash
grep -B3 "^ $LFS/usr/include" dummy.log
# doit retourner :
#   /mnt/lfs/tools/lib/gcc/aarch64-lfs-linux-gnu/15.2.0/include
#   /mnt/lfs/tools/lib/gcc/aarch64-lfs-linux-gnu/15.2.0/include-fixed
#   /mnt/lfs/usr/include
# peut etre legerement different selon l'archi
```

Sanity check (4)
```bash
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
# doit retourner :
#   SEARCH_DIR("=/mnt/lfs/tools/aarch64-lfs-linux-gnu/lib64")
#   SEARCH_DIR("=/usr/local/lib64")
#   SEARCH_DIR("=/lib64")
#   SEARCH_DIR("=/usr/lib64")
#   SEARCH_DIR("=/mnt/lfs/tools/aarch64-lfs-linux-gnu/lib")
#   SEARCH_DIR("=/usr/local/lib")
#   SEARCH_DIR("=/lib")
#   SEARCH_DIR("=/usr/lib");
# peut etre legerement different selon l'archi
```

Sanity check (5)
```bash
grep "/lib.*/libc.so.6 " dummy.log
# doit retourner :
#   attempt to open /mnt/lfs/usr/lib/libc.so.6 succeeded
```

Sanity check (6)
```bash
grep found dummy.log
# doit retourner :
#   found ld-linux-aarch64.so.1 at /mnt/lfs/usr/lib/ld-linux-aarch64.so.1
# peut etre legerement different selon l'archi
```

Cleanup
```bash
rm -v a.out dummy.log
cd $LFS/sources
rm -rvf glibc-2.42
```

> Pour les prochaines étapes, si un des packages échoue, cela voudra dire que quelque chose s'est mal passé avant. Auquel cas, il faudra certainement reprendre l'ensemble des étapes depuis le [début de la cross-toolchain ](#compilation-des-paquets)

#### Libstdc++

> `libstdc++` fait partie de `gcc`, donc on va réutiliser `gcc-15.2.0`

Extraction
```bash
tar -xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
time {
  ../libstdc++-v3/configure      \
    --host=$LFS_TGT            \
    --build=$(../config.guess) \
    --prefix=/usr              \
    --disable-multilib         \
    --disable-nls              \
    --disable-libstdcxx-pch    \
    --with-gxx-include-dir=/tools/$LFS_TGT/include/c++/15.2.0
}
```

Compilation
```bash
time {
  make
}
```

Installation
```bash
time {
  make DESTDIR=$LFS install
}
```

Cleanup
> Nécessite de supprimer `libtool`, car il va y avoir des conflits lors de la cross compilation
```bash
rm -v $LFS/usr/lib/lib{stdc++{,exp,fs},supc++}.la
cd $LFS/sources
rm -rvf gcc-15.2.0
```

### Outils temporaires

> Toujours en user `lfs`

#### M4

Extraction
```bash
tar -xvf m4-1.4.20.tar.xz
cd m4-1.4.20
```

Configuration
```bash
CPPFLAGS='-DMB_LEN_MAX=16 -DPATH_MAX=4096' \
./configure --prefix=/usr \
            --host="$LFS_TGT" \
            --build="$(build-aux/config.guess)"
```
> Pour une raison inconnue, ajouter les flags CPP m'a permis de faire passer la compilation

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf m4-1.4.20
```

#### Ncurses

Extraction
```bash
tar -xvf ncurses-6.5-20250809.tgz
cd ncurses-6.5-20250809
```

Installation de tic
```bash
time {
  mkdir build
  pushd build
    ../configure --prefix=$LFS/tools AWK=gawk
    make -C include
    make -C progs tic
    install progs/tic $LFS/tools/bin
  popd
}
```

Configuration
```bash
time {
  ./configure --prefix=/usr                \
            --host=$LFS_TGT              \
            --build=$(./config.guess)    \
            --mandir=/usr/share/man      \
            --with-manpage-format=normal \
            --with-shared                \
            --without-normal             \
            --with-cxx-shared            \
            --without-debug              \
            --without-ada                \
            --disable-stripping          \
            AWK=gawk
}
```

Compilation
```bash
make
```

Installation
```bash
time {
  make DESTDIR=$LFS install
}
ln -sv libncursesw.so $LFS/usr/lib/libncurses.so
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i $LFS/usr/include/curses.h
```

Cleanup
```bash
cd $LFS/sources
rm -rvf ncurses-6.5-20250809
```

#### Bash

Extraction
```bash
tar -xvf bash-5.3.tar.gz
cd bash-5.3
```

Configuration
```bash
time {
  ./configure --prefix=/usr                      \
            --build=$(sh support/config.guess) \
            --host=$LFS_TGT                    \
            --without-bash-malloc
}
```

Compilation et installation
```bash
time {
  make
  make DESTDIR=$LFS install
}
```

Linkage
```bash
ln -sv bash $LFS/bin/sh
```

Cleanup
```bash
cd $LFS/sources
rm -rvf bash-5.3
```

#### Coreutils

Extraction
```bash
tar -xvf coreutils-9.7.tar.xz
cd coreutils-9.7
```

Configuration
```bash
time {
  CPPFLAGS='-DMB_LEN_MAX=16 -DPATH_MAX=4096' \
  ./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --enable-install-program=hostname \
            --enable-no-install-program=kill,uptime
}
```
> Pareil que pour M4, ajouter les flags CPP m'a permis de faire passer la compilation

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Deplacement de `chroot`
```bash
mv -v $LFS/usr/bin/chroot              $LFS/usr/sbin
mkdir -pv $LFS/usr/share/man/man8
mv -v $LFS/usr/share/man/man1/chroot.1 $LFS/usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/'                    $LFS/usr/share/man/man8/chroot.8
```

Cleanup
```bash
cd $LFS/sources
rm -rvf coreutils-9.7
```

#### Diffutils

Extraction
```bash
tar -xvf diffutils-3.12.tar.xz
cd diffutils-3.12
```

Configuration
```bash
time {
  CPPFLAGS='-DMB_LEN_MAX=16 -DPATH_MAX=4096' \
  ./configure --prefix=/usr   \
            --host=$LFS_TGT \
            gl_cv_func_strcasecmp_works=y \
            --build=$(./build-aux/config.guess)
}
```
> Pareil que pour M4, ajouter les flags CPP m'a permis de faire passer la compilation

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf diffutils-3.12
```

#### File

Extraction
```bash
tar -xvf file-5.46.tar.gz
cd file-5.46
```

Dossier de build (creation d'une copie pour la signature)
```bash
mkdir build
pushd build
  ../configure --disable-bzlib      \
               --disable-libseccomp \
               --disable-xzlib      \
               --disable-zlib
  make
popd
```

Preparer file pour la compilation
```bash
./configure --prefix=/usr --host=$LFS_TGT --build=$(./config.guess)
```

Compilation et installation
```bash
time {
  make FILE_COMPILE=$(pwd)/build/src/file -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
rm -v $LFS/usr/lib/libmagic.la
cd $LFS/sources
rm -rvf file-5.46
```

#### Findutils

Extraction
```bash
tar -xvf findutils-4.10.0.tar.xz
cd findutils-4.10.0
```

Configuration
```bash
CPPFLAGS='-DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr                   \
            --localstatedir=/var/lib/locate \
            --host=$LFS_TGT                 \
            --build=$(build-aux/config.guess)
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf findutils-4.10.0
```

#### Gawk

Extraction
```bash
tar -xvf gawk-5.3.2.tar.xz
cd gawk-5.3.2
```

Petit cleanup
```bash
sed -i 's/extras//' Makefile.in
```

Configuration
```bash
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf gawk-5.3.2
```

#### Grep

Extraction
```bash
tar -xvf grep-3.12.tar.xz
cd grep-3.12
```

Configuration
```bash
CPPFLAGS='-I. -I./lib -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
```
> Toujours pareil, les flags CPP

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf grep-3.12
```

#### Gzip

Extraction
```bash
tar -xvf gzip-1.14.tar.xz
cd gzip-1.14
```

Configuration
```bash
CPPFLAGS='-I. -I./lib -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr --host=$LFS_TGT
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf gzip-1.14
```

#### Make

Extraction
```bash
tar -xvf make-4.4.1.tar.gz
cd make-4.4.1
```

Configuration
```bash
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf make-4.4.1
```

#### Patch

Extraction
```bash
tar -xvf patch-2.8.tar.xz
cd patch-2.8
```

Configuration
```bash
CPPFLAGS='-I. -I./lib -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf patch-2.8
```

#### Sed

Extraction
```bash
tar -xvf sed-4.9.tar.xz
cd sed-4.9
```

Configuration
```bash
CPPFLAGS='-I. -I./lib -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(./build-aux/config.guess)
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf sed-4.9
```

#### Tar

Extraction
```bash
tar -xvf tar-1.35.tar.xz
cd tar-1.35
```

Configuration
```bash
CPPFLAGS='-I. -I./lib -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr   \
            --host=$LFS_TGT \
            --build=$(build-aux/config.guess)
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
cd $LFS/sources
rm -rvf tar-1.35
```

#### Xz

Extraction
```bash
tar -xvf xz-5.8.1.tar.xz
cd xz-5.8.1
```

Configuration
```bash
CPPFLAGS='-I. -I./lib -DMB_LEN_MAX=16 -DPATH_MAX=4096 -D_POSIX_ARG_MAX=4096' \
./configure --prefix=/usr                     \
            --host=$LFS_TGT                   \
            --build=$(build-aux/config.guess) \
            --disable-static                  \
            --docdir=/usr/share/doc/xz-5.8.1
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
rm -v $LFS/usr/lib/liblzma.la
cd $LFS/sources
rm -rvf xz-5.8.1
```

#### Binutils (pass 2)

Extraction
```bash
tar -xvf binutils-2.45.tar.xz
cd binutils-2.45
```

Preparation
```bash
sed '6031s/$add_dir//' -i ltmain.sh
```
> Correction d'un bug dans `ltmain.sh` qui empêche la compilation de binutils

Configuration
```bash
../configure                   \
    --prefix=/usr              \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --disable-nls              \
    --enable-shared            \
    --enable-gprofng=no        \
    --disable-werror           \
    --enable-64-bit-bfd        \
    --enable-new-dtags         \
    --enable-default-hash-style=gnu
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Cleanup
```bash
rm -v $LFS/usr/lib/lib{bfd,ctf,ctf-nobfd,opcodes,sframe}.{a,la}
cd $LFS/sources
rm -rvf binutils-2.45
```

#### GCC (pass 2)

Extraction
```bash
tar -xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
```

Dépendances
```bash
tar -xf ../mpfr-4.2.2.tar.xz
mv -v mpfr-4.2.2 mpfr
tar -xf ../gmp-6.3.0.tar.xz
mv -v gmp-6.3.0 gmp
tar -xf ../mpc-1.3.1.tar.gz
mv -v mpc-1.3.1 mpc
```

Specificité ARM64
```bash
sed -e '/lp64=/s/lib64/lib/' \
    -i.orig gcc/config/aarch64/t-aarch64-linux
```

Surcharge les regles de build
```bash
sed '/thread_header =/s/@.*@/gthr-posix.h/' \
    -i libgcc/Makefile.in libstdc++-v3/include/Makefile.in
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
../configure                   \
    --build=$(../config.guess) \
    --host=$LFS_TGT            \
    --target=$LFS_TGT          \
    --prefix=/usr              \
    --with-build-sysroot=$LFS  \
    --enable-default-pie       \
    --enable-default-ssp       \
    --disable-nls              \
    --disable-multilib         \
    --disable-libatomic        \
    --disable-libgomp          \
    --disable-libquadmath      \
    --disable-libsanitizer     \
    --disable-libssp           \
    --disable-libvtv           \
    --enable-languages=c,c++   \
    LDFLAGS_FOR_TARGET=-L$PWD/$LFS_TGT/libgcc
```

Compilation et installation
```bash
time {
  make -j1
  make DESTDIR=$LFS install -j1
}
```

Creation symlink
```bash
ln -sv gcc $LFS/usr/bin/cc
```

Cleanup
```bash
cd $LFS/sources
rm -rvf gcc-15.2.0
```

## `chroot`

### Ownership

Basculer en root
```bash
exit
sudo su -
```

Changer ownership `lfs` -> `root`
```bash
chown -R --from lfs root:root $LFS/{usr,var,etc,tools}
```

### Preparer le systeme de fichier kernel virtuel

Creer les dossiers
```bash
mkdir -pv $LFS/{dev,proc,sys,run}
```

Monter et populer `/dev`
```bash
mount -v --bind /dev $LFS/dev
```

Monter le reste du systeme de fichier
```bash
mount -vt devpts devpts -o gid=5,mode=0620 $LFS/dev/pts
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run
```

Verification specifique de `/dev/shm`
> Selon la configuration de l'hôte, `/dev/shm` peut être un lien symbolique vers un dossier (souvent `/run/shm`) ou un point de montage `tmpfs`  
```bash
if [ -h $LFS/dev/shm ]; then
  install -v -d -m 1777 $LFS$(realpath /dev/shm)
else
  mount -vt tmpfs -o nosuid,nodev tmpfs $LFS/dev/shm
fi
```
> Cette commande garantit que `/dev/shm` est bien un dossier `tmpfs` avec les bons droits

### Entrer dans le `chroot`

> Toujours en `root`

Entrer dans le `chroot`
```bash
chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    MAKEFLAGS="-j$(nproc)"      \
    TESTSUITEFLAGS="-j$(nproc)" \
    /bin/bash --login
```
> Nous sommes maintenant dans le `chroot`. Si vous voyez `I have no name!` dans le prompt, c'est normal, le fichier `/etc/passwd` n'existe pas encore

A partir d'ici, si pour une raison quelconque vous sortez du `chroot` (reboot par exemple), il vous faudra reprendre les étapes depuis le début de la section [`chroot`](#chroot) pour s'assurer des mountpoints, ownerships etc. Voir [ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter07/chroot.html) pour plus d'informations

### Créer les dossiers nécessaires

`root` level
```bash
mkdir -pv /{boot,home,mnt,opt,srv}
```

Sous dossiers
```bash
mkdir -pv /etc/{opt,sysconfig}
mkdir -pv /lib/firmware
mkdir -pv /media/{floppy,cdrom}
mkdir -pv /usr/{,local/}{include,src}
mkdir -pv /usr/lib/locale
mkdir -pv /usr/local/{bin,lib,sbin}
mkdir -pv /usr/{,local/}share/{color,dict,doc,info,locale,man}
mkdir -pv /usr/{,local/}share/{misc,terminfo,zoneinfo}
mkdir -pv /usr/{,local/}share/man/man{1..8}
mkdir -pv /var/{cache,local,log,mail,opt,spool}
mkdir -pv /var/lib/{color,misc,locate}
```

Liens symboliques
```bash
ln -sfv /run /var/run
ln -sfv /run/lock /var/lock
```

Permissions
```bash
install -dv -m 0750 /root
install -dv -m 1777 /tmp /var/tmp
```
> Voir [compliance FHS](https://refspecs.linuxfoundation.org/fhs.shtml)

### Fichier et liens symboliques essentiels

`mtab`
```bash
ln -sv /proc/self/mounts /etc/mtab
```

`/etc/hosts`
```bash
cat > /etc/hosts << EOF
127.0.0.1  localhost $(hostname)
::1        localhost
EOF
```

`/etc/passwd`
```bash
cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF
```
> On definira le mot de passe plus tard

`/etc/group`
```bash
cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF
```

Utilisateur temporaire `tester`
```bash
echo "tester:x:101:101::/home/tester:/bin/bash" >> /etc/passwd
echo "tester:x:101:" >> /etc/group
install -o tester -d /home/tester
```

Refresh
```bash
exec /usr/bin/bash --login
```
> Le prompt est passé de `I have no name!` a `root`

Créer fichiers de log necessaires
```bash
touch /var/log/{btmp,lastlog,faillog,wtmp}
chgrp -v utmp /var/log/lastlog
chmod -v 664  /var/log/lastlog
chmod -v 600  /var/log/btmp
```

### Packages

> Toujours en root dans le chroot

Meme procédure que pour la cross-toolchain : extraction, configuration, compilation, installation, cleanup  

#### Gettext

Extraction
```bash
tar -xvf gettext-0.26.tar.xz
cd gettext-0.26
```

Configuration
```bash
./configure --disable-shared
```

Compilation
```bash
make
```

`msgfmt`, `msgmerge`, `xgettext`
```bash
cp -v gettext-tools/src/{msgfmt,msgmerge,xgettext} /usr/bin
```

Cleanup
```bash
cd /sources
rm -rvf gettext-0.26
```

#### Bison

Extraction
```bash
tar -xvf bison-3.8.2.tar.xz
cd bison-3.8.2
```

Configuration
```bash
./configure --prefix=/usr \
            --docdir=/usr/share/doc/bison-3.8.2
```

Compilation et installation
```bash
time {
  make
  make install
}
```

Cleanup
```bash
cd /sources
rm -rvf bison-3.8.2
```

#### Perl

Extraction
```bash
tar -xvf perl-5.42.0.tar.xz
cd perl-5.42.0
```

Configuration
```bash
sh Configure -des                                         \
             -D prefix=/usr                               \
             -D vendorprefix=/usr                         \
             -D useshrplib                                \
             -D privlib=/usr/lib/perl5/5.42/core_perl     \
             -D archlib=/usr/lib/perl5/5.42/core_perl     \
             -D sitelib=/usr/lib/perl5/5.42/site_perl     \
             -D sitearch=/usr/lib/perl5/5.42/site_perl    \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl
```

Compilation et installation
```bash
time {
  make
  make install
}
```

Cleanup
```bash
cd /sources
rm -rvf perl-5.42.0
```

#### Python

> attention a bien prendre le package avec la majuscule `P` (dans notre cas, `Python-3.13.7.tar.xz`)

Extraction
```bash
tar -xvf Python-3.13.7.tar.xz
cd Python-3.13.7
```

Configuration
```bash
./configure --prefix=/usr       \
            --enable-shared     \
            --without-ensurepip \
            --without-static-libpython
```

Compilation
```bash
make
```
> Plusieurs modules de python3 ne peuvent pas etre installés à cause de dependances manquantes (comme `ssl`), c'est normal. Toutefois, faites juste bien attention que la commande `make` se termine sans erreur avec `echo $?` qui doit retourner `0`

Installation
```bash
time {
  make install
}
```

Cleanup
```bash
cd /sources
rm -rvf Python-3.13.7
```

#### Texinfo

Extraction
```bash
tar -xvf texinfo-7.2.tar.xz
cd texinfo-7.2
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et installation
```bash
time {
  make
  make install
}
```

Cleanup
```bash
cd /sources
rm -rvf texinfo-7.2
```

#### Util-linux

Extraction
```bash
tar -xvf util-linux-2.41.1.tar.xz
cd util-linux-2.41.1
```

Creation dossier `hwclock`
```bash
mkdir -pv /var/lib/hwclock
```

Configuration
```bash
./configure --libdir=/usr/lib     \
            --runstatedir=/run    \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-static      \
            --disable-liblastlog2 \
            --without-python      \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1
```

Compilation et installation
```bash
time {
  make
  make install
}
```

Cleanup
```bash
cd /sources
rm -rvf util-linux-2.41.1
```

### Cleanup et sauvegarde du systeme de fichier temporaire

#### Cleanup

Supprimer documentation inutile
```bash
rm -rvf /usr/share/{info,man,doc}/*
```

Supprimer fichiers `.la` par sécurité
```bash
find /usr/{lib,libexec} -name \*.la -delete
```

Supprimer dossier `/tools`
```bash
rm -rvf /tools
```

#### Backup (facultatif, mais conseillé)

**Précautions** :

- Attention : cette etape est facultative, mais fortement recommandée, parce que flemme de recommencer tout depuis le début si on foire quelque chose.  
- Toute ces etapes doivent etre realisées en dehors du `chroot`, donc sortir du `chroot` avec `exit` ou `Ctrl+D` (sinon tu vas mettre oú la backup ?)  
- Derniere chose : faut etre en `root`, et s'assurer que l'env $LFS est bien set (sinon, `export LFS=/mnt/lfs`)  

Unmount le systeme de fichier kernel virtuel
```bash
mountpoint -q $LFS/dev/shm && umount $LFS/dev/shm
umount $LFS/dev/pts
umount $LFS/{sys,proc,run,dev}
```

S'assurer de la place disponible pour la backup
```bash
df -h $LFS
```
> S'assurer d'au moins 2GB de libre, la backup sera placée dans `$HOME` du `root` par défaut

Backup
```bash
cd $LFS
tar -cJpf $HOME/lfs-temp-tools-arm64-r12.4-15.tar.xz .
```
> Compter au moins 10mins pour cette étape, petit café ?

#### (HELP!) Restore

En cas de problème (crash, commande mal passée etc), il est possible de restaurer la backup précédemment faite.  
Présumes que tu es en `root` sur le système host, et que `$LFS` est bien set
```bash
export LFS=/mnt/lfs
cd $LFS
rm -rf ./*
tar -xpf $HOME/lfs-temp-tools-arm64-r12.4-15.tar.xz
```

Attention aux mount et de bien réentrer dans le `chroot` ([voir ici pour plus de détails](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter07/kernfs.html), [puis ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter07/chroot.html))

## Construction système LFS

Redémarrer dans le `chroot` (si tu as fait une restore, il faut refaire les mountpoints)  
Voir [ici](#entrer-dans-le-chroot) pour les détails

### Installation Basic System Software

> Si c'est ta première fois, évite les customisations et optimisations custom. Vaut mieux suivre le guide à la lettre (et ce tuto donc, qui va + droit au but)  

> Meme principe que pour les étapes précédentes : extraction, configuration, compilation, installation, cleanup

#### Man-pages

Extraction
```bash
tar -xvf man-pages-6.15.tar.xz
cd man-pages-6.15
```

Supprimer les pages `man3/crypt*`
```bash
rm -v man3/crypt*
```

Installation
```bash
make -R GIT=false prefix=/usr install
```

Cleanup
```bash
cd /sources
rm -rvf man-pages-6.15
```

#### Iana-Etc

Extraction et installation
```bash
tar -xvf iana-etc-20250807.tar.gz
cd iana-etc-20250807
cp services protocols /etc
```

Cleanup
```bash
cd /sources
rm -rvf iana-etc-20250807
```

#### Glibc

Extraction
```bash
tar -xvf glibc-2.42.tar.xz
cd glibc-2.42
```

Patch
```bash
patch -Np1 -i ../glibc-2.42-fhs-1.patch
sed -e '/unistd.h/i #include <string.h>' \
    -e '/libc_rwlock_init/c\
  __libc_rwlock_define_initialized (, reset_lock);\
  memcpy (&lock, &reset_lock, sizeof (lock));' \
    -i stdlib/abort.c 
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Params
```bash
echo "rootsbindir=/usr/sbin" > configparms
```

Configuration
```bash
../configure --prefix=/usr                   \
             --disable-werror                \
             --disable-nscd                  \
             libc_cv_slibdir=/usr/lib        \
             --enable-stack-protector=strong \
             --enable-kernel=5.4
```

Compilation
```bash
make
```

Tests (important!)
```bash
make check
```
> [Voir ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter08/glibc.html) pour les erreurs acceptables et les details des resultats des tests selon scenario

Small fixes
```bash
touch /etc/ld.so.conf
sed '/test-installation/s@$(PERL)@echo not running@' -i ../Makefile
```

Installation
```bash
time {
  make install
}
```

Fix path hardcoded `ldd` script
```bash
sed '/RTLDLIST=/s@/usr@@g' -i /usr/bin/ldd
```

Definitions locales

Option 1 : locales minimales (rapide)
```bash
localedef -i C -f UTF-8 C.UTF-8
localedef -i cs_CZ -f UTF-8 cs_CZ.UTF-8
localedef -i de_DE -f ISO-8859-1 de_DE
localedef -i de_DE@euro -f ISO-8859-15 de_DE@euro
localedef -i de_DE -f UTF-8 de_DE.UTF-8
localedef -i el_GR -f ISO-8859-7 el_GR
localedef -i en_GB -f ISO-8859-1 en_GB
localedef -i en_GB -f UTF-8 en_GB.UTF-8
localedef -i en_HK -f ISO-8859-1 en_HK
localedef -i en_PH -f ISO-8859-1 en_PH
localedef -i en_US -f ISO-8859-1 en_US
localedef -i en_US -f UTF-8 en_US.UTF-8
localedef -i es_ES -f ISO-8859-15 es_ES@euro
localedef -i es_MX -f ISO-8859-1 es_MX
localedef -i fa_IR -f UTF-8 fa_IR
localedef -i fr_FR -f ISO-8859-1 fr_FR
localedef -i fr_FR@euro -f ISO-8859-15 fr_FR@euro
localedef -i fr_FR -f UTF-8 fr_FR.UTF-8
localedef -i is_IS -f ISO-8859-1 is_IS
localedef -i is_IS -f UTF-8 is_IS.UTF-8
localedef -i it_IT -f ISO-8859-1 it_IT
localedef -i it_IT -f ISO-8859-15 it_IT@euro
localedef -i it_IT -f UTF-8 it_IT.UTF-8
localedef -i ja_JP -f EUC-JP ja_JP
localedef -i ja_JP -f UTF-8 ja_JP.UTF-8
localedef -i nl_NL@euro -f ISO-8859-15 nl_NL@euro
localedef -i ru_RU -f KOI8-R ru_RU.KOI8-R
localedef -i ru_RU -f UTF-8 ru_RU.UTF-8
localedef -i se_NO -f UTF-8 se_NO.UTF-8
localedef -i ta_IN -f UTF-8 ta_IN.UTF-8
localedef -i tr_TR -f UTF-8 tr_TR.UTF-8
localedef -i zh_CN -f GB18030 zh_CN.GB18030
localedef -i zh_HK -f BIG5-HKSCS zh_HK.BIG5-HKSCS
localedef -i zh_TW -f UTF-8 zh_TW.UTF-8
# custom
localedef -i fr_CH -f UTF-8 fr_CH.UTF-8
```

Option 2 : toutes les locales (prends un peu + de temps)
```bash
make localedata/install-locales
```

Configuration - `nsswitch.conf`
```bash
cat > /etc/nsswitch.conf << "EOF"
# Begin /etc/nsswitch.conf

passwd: files
group: files
shadow: files

hosts: files dns
networks: files

protocols: files
services: files
ethers: files
rpc: files

# End /etc/nsswitch.conf
EOF
```

Configuration - Timezone
```bash
tar -xf ../../tzdata2025b.tar.gz

ZONEINFO=/usr/share/zoneinfo
mkdir -pv $ZONEINFO/{posix,right}

for tz in etcetera southamerica northamerica europe africa antarctica  \
          asia australasia backward; do
    zic -L /dev/null   -d $ZONEINFO       ${tz}
    zic -L /dev/null   -d $ZONEINFO/posix ${tz}
    zic -L leapseconds -d $ZONEINFO/right ${tz}
done

cp -v zone.tab zone1970.tab iso3166.tab $ZONEINFO
zic -d $ZONEINFO -p America/New_York
unset ZONEINFO tz
```

Puis test en configurant la timezone
```bash
tzselect # puis suivre les instructions
```

Créer le fichier `/etc/localtime`
```bash
ln -sfv /usr/share/zoneinfo/<xxx> /etc/localtime #remplacer <xxx> par le resultat de tzselect
# exexmple :
ln -sfv /usr/share/zoneinfo/Europe/Zurich /etc/localtime
```

Configuration - `ld.so.conf`
```bash
cat > /etc/ld.so.conf << "EOF"
# Begin /etc/ld.so.conf
/usr/local/lib
/opt/lib

EOF
```

> si voulu, ajouter des dossiers additionnels
```bash
cat >> /etc/ld.so.conf << "EOF"
# Add an include directory
include /etc/ld.so.conf.d/*.conf

EOF
mkdir -pv /etc/ld.so.conf.d
```

Cleanup
```bash
cd /sources
rm -rvf glibc-2.42
```

#### Zlib

Extraction
```bash
tar -xvf zlib-1.3.1.tar.gz
cd zlib-1.3.1
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et installation
```bash
make
make check
make install
```

Cleanup
```bash
rm -fv /usr/lib/libz.a
cd /sources
rm -rvf zlib-1.3.1
```

#### Bzip2

Extraction
```bash
tar -xvf bzip2-1.0.8.tar.gz
cd bzip2-1.0.8
```

Patch
```bash
patch -Np1 -i ../bzip2-1.0.8-install_docs-1.patch
sed -i 's@\(ln -s -f \)$(PREFIX)/bin/@\1@' Makefile
sed -i "s@(PREFIX)/man@(PREFIX)/share/man@g" Makefile
```

Preparer pour la compilation
```bash
make -f Makefile-libbz2_so
make clean
```

Compilation
```bash
make
```

Installation
```bash
make PREFIX=/usr install
cp -av libbz2.so.* /usr/lib
ln -sv libbz2.so.1.0.8 /usr/lib/libbz2.so
cp -v bzip2-shared /usr/bin/bzip2
for i in /usr/bin/{bzcat,bunzip2}; do
  ln -sfv bzip2 $i
done
```

Cleanup
```bash
rm -fv /usr/lib/libbz2.a
cd /sources
rm -rvf bzip2-1.0.8
```

#### Xz

Extraction
```bash
tar -xvf xz-5.8.1.tar.xz
cd xz-5.8.1
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/xz-5.8.1
```

Compilation et installation
```bash
time {
  make
  make check
  make install
}
```

Cleanup
```bash
cd /sources
rm -rvf xz-5.8.1
```

#### Lz4

Extraction
```bash
tar -xvf lz4-1.10.0.tar.gz
cd lz4-1.10.0
```

Compilation & check
```bash
make BUILD_STATIC=no PREFIX=/usr
make -j1 check
```

Installation
```bash
make BUILD_STATIC=no PREFIX=/usr install
```

Cleanup
```bash
cd /sources
rm -rvf lz4-1.10.0
```

#### Zstd

Extraction
```bash
tar -xvf zstd-1.5.7.tar.gz
cd zstd-1.5.7
```

Compilation & check
```bash
make prefix=/usr
make check
```

Installation
```bash
make prefix=/usr install
```

Cleanup
```bash
rm -v /usr/lib/libzstd.a
cd /sources
rm -rvf zstd-1.5.7
```

#### File

Extraction
```bash
tar -xvf file-5.46.tar.gz
cd file-5.46
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf file-5.46
```

#### Readline

Extraction
```bash
tar -xvf readline-8.3.tar.gz
cd readline-8.3
```

Preparation
```bash
sed -i '/MV.*old/d' Makefile.in
sed -i '/{OLDSUFF}/c:' support/shlib-install
sed -i 's/-Wl,-rpath,[^ ]*//' support/shobj-conf
```

Configuration 
```bash
./configure --prefix=/usr    \
            --disable-static \
            --with-curses    \
            --docdir=/usr/share/doc/readline-8.3
```

Compilation
```bash
make SHLIB_LIBS="-lncursesw"
```

Installation
```bash
make install
# optionnel : documentation
install -v -m644 doc/*.{ps,pdf,html,dvi} /usr/share/doc/readline-8.3
```

Cleanup
```bash
cd /sources
rm -rvf readline-8.3
```

#### Pcre2

Extraction
```bash
tar -xvf pcre2-10.45.tar.bz2
cd pcre2-10.45
```

Configuration
```bash
./configure --prefix=/usr                       \
            --docdir=/usr/share/doc/pcre2-10.45 \
            --enable-unicode                    \
            --enable-jit                        \
            --enable-pcre2-16                   \
            --enable-pcre2-32                   \
            --enable-pcre2grep-libz             \
            --enable-pcre2grep-libbz2           \
            --enable-pcre2test-libreadline      \
            --disable-static
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf pcre2-10.45
```

#### M4

Extraction
```bash
tar -xvf m4-1.4.20.tar.xz
cd m4-1.4.20
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf m4-1.4.20
```

#### Bc

Extraction
```bash
tar -xvf bc-7.0.3.tar.xz
cd bc-7.0.3
```

Configuration
```bash
CC='gcc -std=c99' ./configure --prefix=/usr -G -O3 -r
```

Compilation et check
```bash
make
make test
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf bc-7.0.3
```

#### Flex

Extraction
```bash
tar -xvf flex-2.6.4.tar.gz
cd flex-2.6.4
```

Configuration
```bash
./configure --prefix=/usr \
            --docdir=/usr/share/doc/flex-2.6.4 \
            --disable-static
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Lien symbolique `lex`
```bash
ln -sv flex   /usr/bin/lex
ln -sv flex.1 /usr/share/man/man1/lex.1
```

Cleanup
```bash
cd /sources
rm -rvf flex-2.6.4
```

#### Tcl

Extraction
```bash
tar -xvf tcl8.6.16-src.tar.gz
cd tcl8.6.16
```

Preparation
```bash
SRCDIR=$(pwd)
cd unix
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --disable-rpath
```

Build
```bash
make

sed -e "s|$SRCDIR/unix|/usr/lib|" \
    -e "s|$SRCDIR|/usr/include|"  \
    -i tclConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/tdbc1.1.10|/usr/lib/tdbc1.1.10|" \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10/generic|/usr/include|"     \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10/library|/usr/lib/tcl8.6|"  \
    -e "s|$SRCDIR/pkgs/tdbc1.1.10|/usr/include|"             \
    -i pkgs/tdbc1.1.10/tdbcConfig.sh

sed -e "s|$SRCDIR/unix/pkgs/itcl4.3.2|/usr/lib/itcl4.3.2|" \
    -e "s|$SRCDIR/pkgs/itcl4.3.2/generic|/usr/include|"    \
    -e "s|$SRCDIR/pkgs/itcl4.3.2|/usr/include|"            \
    -i pkgs/itcl4.3.2/itclConfig.sh

unset SRCDIR
```

Check
```bash
make test
```

Installation
```bash
make install
chmod 644 /usr/lib/libtclstub8.6.a
```

Permissions ecriture sur la lib
```bash
chmod -v u+w /usr/lib/libtcl8.6.so
```

Installation headers
```bash
make install-private-headers
```

Lien symbolique `tclsh`
```bash
ln -sfv tclsh8.6 /usr/bin/tclsh
```

Documentation
```bash
mv /usr/share/man/man3/{Thread,Tcl_Thread}.3 # conflit avec Perl
cd ..
tar -xf ../tcl8.6.16-html.tar.gz --strip-components=1
mkdir -v -p /usr/share/doc/tcl-8.6.16
cp -v -r  ./html/* /usr/share/doc/tcl-8.6.16
```

Cleanup
```bash
cd /sources
rm -rvf tcl8.6.16
```

#### Expect

Extraction
```bash
tar -xvf expect5.45.4.tar.gz
cd expect5.45.4
```

Check PTY
```bash
python3 -c 'from pty import spawn; spawn(["echo", "ok"])'
```
> Doit absolument retourner `ok`, sinon Expect ne fonctionnera pas correctement (voir [cette page](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter08/expect.html) si ca te renvoi une erreur)  

Mise a jour des scripts config
```bash
tar -C tclconfig -xf ../autoconf-2.72.tar.xz --strip-components=2 \
    autoconf-2.72/build-aux/config.{guess,sub}
```
> il faut bien que ce soit compatible avec notre architecture ARM64

Patch
```bash
patch -Np1 -i ../expect-5.45.4-gcc15-1.patch
```

Configuration
```bash
./configure --prefix=/usr           \
            --with-tcl=/usr/lib     \
            --enable-shared         \
            --disable-rpath         \
            --mandir=/usr/share/man \
            --with-tclinclude=/usr/include
```

Compilation et check
```bash
make
make test
```

Installation
```bash
make install
ln -svf expect5.45.4/libexpect5.45.4.so /usr/lib
```

Cleanup
```bash
cd /sources
rm -rvf expect5.45.4
```

#### DejaGNU

Extraction
```bash
tar -xvf dejagnu-1.6.3.tar.gz
cd dejagnu-1.6.3
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
../configure --prefix=/usr
makeinfo --html --no-split -o doc/dejagnu.html ../doc/dejagnu.texi
makeinfo --plaintext       -o doc/dejagnu.txt  ../doc/dejagnu.texi
```

Check
```bash
make check
```

Installation 
```bash
make install
install -v -dm755  /usr/share/doc/dejagnu-1.6.3
install -v -m644   doc/dejagnu.{html,txt} /usr/share/doc/dejagnu-1.6.3
```

Cleanup
```bash
cd /sources
rm -rvf dejagnu-1.6.3
```

#### Pkgconf

Extraction
```bash
tar -xvf pkgconf-2.5.1.tar.xz
cd pkgconf-2.5.1
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/pkgconf-2.5.1
```

Compilation
```bash
make
```

Installation
```bash
make install
ln -sv pkgconf   /usr/bin/pkg-config
ln -sv pkgconf.1 /usr/share/man/man1/pkg-config.1
```

Cleanup
```bash
cd /sources
rm -rvf pkgconf-2.5.1
```

#### Binutils

Extraction
```bash
tar -xvf binutils-2.45.tar.xz
cd binutils-2.45
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-ld=default \
             --enable-plugins    \
             --enable-shared     \
             --disable-werror    \
             --enable-64-bit-bfd \
             --enable-new-dtags  \
             --with-system-zlib  \
             --enable-default-hash-style=gnu
```

Compilation
```bash
make tooldir=/usr
```

Check (important!)
```bash
make -k check
```

List des echecs
```bash
grep '^FAIL:' $(find -name '*.log')
```

Installation
```bash
make tooldir=/usr install
```

Cleanup
```bash
rm -rfv /usr/lib/lib{bfd,ctf,ctf-nobfd,gprofng,opcodes,sframe}.a \
        /usr/share/doc/gprofng/
cd /sources
rm -rvf binutils-2.45
```

#### GMP

Extraction
```bash
tar -xvf gmp-6.3.0.tar.xz
cd gmp-6.3.0
```

Small fix
```bash
sed -i '/long long t1;/,+1s/()/(...)/' configure # pour gcc-15
```

Configuration
```bash
./configure --prefix=/usr    \
            --enable-cxx     \
            --disable-static \
            --docdir=/usr/share/doc/gmp-6.3.0
```

Compilation
```bash
make
make html # documentation
```

Check (important!)
```bash
make check 2>&1 | tee gmp-check-log
```

Verifier les checks
```bash
awk '/# PASS:/{total+=$3} ; END{print total}' gmp-check-log
```
> Minimum 199 tests doivent passer

Installation
```bash
make install
make install-html
```

Cleanup
```bash
cd /sources
rm -rvf gmp-6.3.0
```

#### MPFR

Extraction
```bash
tar -xvf mpfr-4.2.2.tar.xz
cd mpfr-4.2.2
```

Configuration
```bash
./configure --prefix=/usr        \
            --disable-static     \
            --enable-thread-safe \
            --docdir=/usr/share/doc/mpfr-4.2.2
```

Compilation
```bash
make
make html
```

Check (important!)
```bash
make check
```

Installation
```bash
make install
make install-html
```

Cleanup
```bash
cd /sources
rm -rvf mpfr-4.2.2
```

#### MPC

Extraction
```bash
tar -xvf mpc-1.3.1.tar.gz
cd mpc-1.3.1
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/mpc-1.3.1
```

Compilation
```bash
make
make html
```

Check
```bash
make check
```

Installation
```bash
make install
make install-html
```

Cleanup
```bash
cd /sources
rm -rvf mpc-1.3.1
```

#### Attr

Extraction
```bash
tar -xvf attr-2.5.2.tar.gz
cd attr-2.5.2
```

Configuration
```bash
./configure --prefix=/usr     \
            --disable-static  \
            --sysconfdir=/etc \
            --docdir=/usr/share/doc/attr-2.5.2
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf attr-2.5.2
```

#### Acl

Extraction
```bash
tar -xvf acl-2.3.2.tar.xz
cd acl-2.3.2
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/acl-2.3.2
```

Compilation et check
```bash
make
make check
```
> `cp.test` est connu pour fail. Pas de souci si c'est le seul  

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf acl-2.3.2
```

#### Libcap

Extraction
```bash
tar -xvf libcap-2.76.tar.xz
cd libcap-2.76
```

Preparation
```bash
sed -i '/install -m.*STA/d' libcap/Makefile
```

Compilation et check
```bash
make prefix=/usr lib=lib
make test
```

Installation
```bash
make prefix=/usr lib=lib install
```

Cleanup
```bash
cd /sources
rm -rvf libcap-2.76
```

#### Libxcrypt

Extraction
```bash
tar -xvf libxcrypt-4.4.38.tar.xz
cd libxcrypt-4.4.38
```

Configuration
```bash
./configure --prefix=/usr                \
            --enable-hashes=strong,glibc \
            --enable-obsolete-api=no     \
            --disable-static             \
            --disable-failure-tokens
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf libxcrypt-4.4.38
```

#### Shadow

Extraction
```bash
tar -xvf shadow-4.18.0.tar.xz
cd shadow-4.18.0
```

Preparation
```bash
sed -i 's/groups$(EXEEXT) //' src/Makefile.in
find man -name Makefile.in -exec sed -i 's/groups\.1 / /'   {} \;
find man -name Makefile.in -exec sed -i 's/getspnam\.3 / /' {} \;
find man -name Makefile.in -exec sed -i 's/passwd\.5 / /'   {} \;
```
> Desactive conflits et tools deja installés

Preparation bis
```bash
sed -e 's:#ENCRYPT_METHOD DES:ENCRYPT_METHOD YESCRYPT:' \
    -e 's:/var/spool/mail:/var/mail:'                   \
    -e '/PATH=/{s@/sbin:@@;s@/bin:@@}'                  \
    -i etc/login.defs
```
> Modifie le fichier `login.defs` pour utiliser `yescrypt` par défaut, et change le dossier des mails, ainsi que le PATH par défaut

Configuration
```bash
touch /usr/bin/passwd
./configure --sysconfdir=/etc   \
            --disable-static    \
            --with-{b,yes}crypt \
            --without-libbsd    \
            --with-group-name-max-length=32
```

Compilation
```bash
make
```

Installation
```bash
make exec_prefix=/usr install
make -C man install-man
```

Configuration de shadow
```bash
pwconv
grpconv
```

Parametrage
```bash
mkdir -p /etc/default
useradd -D --gid 999
sed -i '/MAIL/s/yes/no/' /etc/default/useradd
```
> Configure `/etc/default/useradd` pour définir le GID par défaut à `999` et désactiver la création des boîtes mail, puis s'assure que `/etc/group` est correctement configuré pour éviter les erreurs

Set `root` password
```bash
passwd root
```

Cleanup
```bash
cd /sources
rm -rvf shadow-4.18.0
```

#### GCC

Extraction
```bash
tar -xvf gcc-15.2.0.tar.xz
cd gcc-15.2.0
```

Changer repertoire par defaut pour les ARM
```bash
sed -e '/lp64=/s/lib64/lib/' \
    -i.orig gcc/config/aarch64/t-aarch64-linux
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
../configure --prefix=/usr            \
             LD=ld                    \
             --enable-languages=c,c++ \
             --enable-default-pie     \
             --enable-default-ssp     \
             --enable-host-pie        \
             --disable-multilib       \
             --disable-bootstrap      \
             --disable-fixincludes    \
             --with-system-zlib
```

Compilation (long!)
```bash
make
```

Preparation pour les tests
```bash
ulimit -s -H unlimited
sed -e '/cpython/d' -i ../gcc/testsuite/gcc.dg/plugin/plugin.exp
chown -R tester .
```

Check (important! et TRÈS long!)
```bash
su tester -c "PATH=$PATH make -k check"
```

Installation
```bash
make install
```

Ownership
```bash
chown -v -R root:root \
    /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include{,-fixed}
```

Liens symboliques
```bash
ln -svr /usr/bin/cpp /usr/lib
ln -sv gcc.1 /usr/share/man/man1/cc.1
ln -sfv ../../libexec/gcc/$(gcc -dumpmachine)/15.2.0/liblto_plugin.so \
        /usr/lib/bfd-plugins/
```

Sanity check
```bash
echo 'int main(){}' | cc -x c - -v -Wl,--verbose &> dummy.log
readelf -l a.out | grep ': /lib'
# Doit afficher : 
#       [Requesting program interpreter: /lib/ld-linux-aarch64.so.1]
# peut differer legerement selon l'archi
```
```bash
grep -E -o '/usr/lib.*/S?crt[1in].*succeeded' dummy.log
# Doit afficher au moins :
#    /usr/lib/gcc/aarch64-unknown-linux-gnu/15.2.0/../../../../lib/Scrt1.o succeeded
#    /usr/lib/gcc/aarch64-unknown-linux-gnu/15.2.0/../../../../lib/crti.o succeeded
#    /usr/lib/gcc/aarch64-unknown-linux-gnu/15.2.0/../../../../lib/crtn.o succeeded
# peut differer legerement selon l'archi
```
```bash
grep -B4 '^ /usr/include' dummy.log
# Doit afficher au moins :
#  include <...> search starts here:
#    /usr/lib/gcc/aarch64-unknown-linux-gnu/15.2.0/include
#    /usr/local/include
#    /usr/lib/gcc/aarch64-unknown-linux-gnu/15.2.0/include-fixed
#    /usr/include
# peut differer legerement selon l'archi
```
```bash
grep 'SEARCH.*/usr/lib' dummy.log |sed 's|; |\n|g'
# Doit afficher au moins :
#    SEARCH_DIR("/usr/aarch64-unknown-linux-gnu/lib64")
#    SEARCH_DIR("/usr/local/lib64")
#    SEARCH_DIR("/lib64")
#    SEARCH_DIR("/usr/lib64")
#    SEARCH_DIR("/usr/aarch64-unknown-linux-gnu/lib")
#    SEARCH_DIR("/usr/local/lib")
#    SEARCH_DIR("/lib")
#    SEARCH_DIR("/usr/lib");
# peut differer legerement selon l'archi
```
```bash
grep "/lib.*/libc.so.6 " dummy.log
# Doit afficher au moins :
#    attempt to open /lib/libc.so.6 succeeded
# peut differer legerement selon l'archi
```
```bash
grep found dummy.log
# Doit afficher au moins :
#    found ld-linux-aarch64.so.1 at /usr/lib/ld-linux-aarch64.so.1
# peut differer legerement selon l'archi
```
> Si quelque chose differe, c'est serieux, quelque chose s'est mal passé. Va [ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter08/gcc.html) et reprends les etapes

Final config
```bash
mkdir -pv /usr/share/gdb/auto-load/usr/lib
mv -v /usr/lib/*gdb.py /usr/share/gdb/auto-load/usr/lib
```

Cleanup
```bash
rm -v a.out dummy.log
cd /sources
rm -rvf gcc-15.2.0
```

#### Ncurses

Extraction
```bash
tar -xvf ncurses-6.5-20250809.tgz
cd ncurses-6.5-20250809
```

Configuration
```bash
./configure --prefix=/usr           \
            --mandir=/usr/share/man \
            --with-shared           \
            --without-debug         \
            --without-normal        \
            --with-cxx-shared       \
            --enable-pc-files       \
            --with-pkg-config-libdir=/usr/lib/pkgconfig
```

Compilation
```bash
make
```

Installation
```bash
make DESTDIR=$PWD/dest install
sed -e 's/^#if.*XOPEN.*$/#if 1/' \
    -i dest/usr/include/curses.h
cp --remove-destination -av dest/* /
```

Patch link
```bash
for lib in ncurses form panel menu ; do
    ln -sfv lib${lib}w.so /usr/lib/lib${lib}.so
    ln -sfv ${lib}w.pc    /usr/lib/pkgconfig/${lib}.pc
done
ln -sfv libncursesw.so /usr/lib/libcurses.so
```

Documentation
```bash
cp -v -R doc -T /usr/share/doc/ncurses-6.5-20250809
```

Cleanup
```bash
cd /sources
rm -rvf ncurses-6.5-20250809
```

#### Sed

Extraction
```bash
tar -xvf sed-4.9.tar.xz
cd sed-4.9
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation
```bash
make
make html
```

Checks
```bash
chown -R tester .
su tester -c "PATH=$PATH make check"
```

Installation
```bash
make install
install -d -m755           /usr/share/doc/sed-4.9
install -m644 doc/sed.html /usr/share/doc/sed-4.9
```

Cleanup
```bash
cd /sources
rm -rvf sed-4.9
```

#### Psmisc

Extraction
```bash
tar -xvf psmisc-23.7.tar.xz
cd psmisc-23.7
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf psmisc-23.7
```

#### Gettext

Extraction
```bash
tar -xvf gettext-0.26.tar.xz
cd gettext-0.26
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/gettext-0.26
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
chmod -v 0755 /usr/lib/preloadable_libintl.so
```

Cleanup
```bash
cd /sources
rm -rvf gettext-0.26
```

#### Bison

Extraction
```bash
tar -xvf bison-3.8.2.tar.xz
cd bison-3.8.2
```

Configuration
```bash
./configure --prefix=/usr --docdir=/usr/share/doc/bison-3.8.2
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf bison-3.8.2
```

#### Grep 

Extraction
```bash
tar -xvf grep-3.12.tar.xz
cd grep-3.12
```

Patch
```bash
sed -i "s/echo/#echo/" src/egrep.sh
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf grep-3.12
```

#### Bash

Extraction
```bash
tar -xvf bash-5.3.tar.gz
cd bash-5.3
```

Configuration
```bash
./configure --prefix=/usr             \
            --without-bash-malloc     \
            --with-installed-readline \
            --docdir=/usr/share/doc/bash-5.3
```

Compilation
```bash
make
```

Preparation pour tests
```bash
chown -R tester .
```

Tests
```bash
LC_ALL=C.UTF-8 su -s /usr/bin/expect tester << "EOF"
set timeout -1
spawn make tests
expect eof
lassign [wait] _ _ _ value
exit $value
EOF
```
> les tests vont s'effectuer dans un shell `expect` pour eviter des problemes d'interaction

Installation
```bash
make install
```

Entrer dans le nouveau shell bash
```bash
exec /usr/bin/bash --login
```

Cleanup
```bash
cd /sources
rm -rvf bash-5.3
```

#### Libtool

Extraction
```bash
tar -xvf libtool-2.5.4.tar.xz
cd libtool-2.5.4
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
rm -fv /usr/lib/libltdl.a
cd /sources
rm -rvf libtool-2.5.4
```

#### Gdbm

Extraction
```bash
tar -xvf gdbm-1.26.tar.gz
cd gdbm-1.26
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --enable-libgdbm-compat
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf gdbm-1.26
```

#### Gperf

Extraction
```bash
tar -xvf gperf-3.3.tar.gz
cd gperf-3.3
```

Configuration
```bash
./configure --prefix=/usr --docdir=/usr/share/doc/gperf-3.3
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf gperf-3.3
```

#### Expat

Extraction
```bash
tar -xvf expat-2.7.1.tar.xz
cd expat-2.7.1
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --docdir=/usr/share/doc/expat-2.7.1
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
install -v -m644 doc/*.{html,css} /usr/share/doc/expat-2.7.1
```

Cleanup
```bash
cd /sources
rm -rvf expat-2.7.1
```

#### Inetutils

Extraction
```bash
tar -xvf inetutils-2.6.tar.xz
cd inetutils-2.6
```

Compatibilité GCC
```bash
sed -i 's/def HAVE_TERMCAP_TGETENT/ 1/' telnet/telnet.c
```

Configuration
```bash
./configure --prefix=/usr        \
            --bindir=/usr/bin    \
            --localstatedir=/var \
            --disable-logger     \
            --disable-whois      \
            --disable-rcp        \
            --disable-rexec      \
            --disable-rlogin     \
            --disable-rsh        \
            --disable-servers
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
mv -v /usr/{,s}bin/ifconfig
```

Cleanup
```bash
cd /sources
rm -rvf inetutils-2.6
```

#### Less

Extraction
```bash
tar -xvf less-679.tar.gz
cd less-679
```

Configuration
```bash
./configure --prefix=/usr --sysconfdir=/etc
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf less-679
```

#### Perl

Extraction
```bash
tar -xvf perl-5.42.0.tar.xz
cd perl-5.42.0
```

Environnement
```bash
export BUILD_ZLIB=False
export BUILD_BZIP2=0
```

Configuration
```bash
sh Configure -des                                          \
             -D prefix=/usr                                \
             -D vendorprefix=/usr                          \
             -D privlib=/usr/lib/perl5/5.42/core_perl      \
             -D archlib=/usr/lib/perl5/5.42/core_perl      \
             -D sitelib=/usr/lib/perl5/5.42/site_perl      \
             -D sitearch=/usr/lib/perl5/5.42/site_perl     \
             -D vendorlib=/usr/lib/perl5/5.42/vendor_perl  \
             -D vendorarch=/usr/lib/perl5/5.42/vendor_perl \
             -D man1dir=/usr/share/man/man1                \
             -D man3dir=/usr/share/man/man3                \
             -D pager="/usr/bin/less -isR"                 \
             -D useshrplib                                 \
             -D usethreads
```

Compilation
```bash
make
```

Check
```bash
TEST_JOBS=$(nproc) make test_harness
```

Installation
```bash
make install
```

Cleanup
```bash
unset BUILD_ZLIB BUILD_BZIP2
cd /sources
rm -rvf perl-5.42.0
```

#### XML::Parser

Extraction
```bash
tar -xvf XML-Parser-2.47.tar.gz
cd XML-Parser-2.47
```

Preparation
```bash
perl Makefile.PL
```

Compilation et check
```bash
make
make test
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf XML-Parser-2.47
```

#### Intltool

Extraction
```bash
tar -xvf intltool-0.51.0.tar.gz
cd intltool-0.51.0
```

Small fix
```bash
sed -i 's:\\\${:\\\$\\{:' intltool-update.in
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
install -v -Dm644 doc/I18N-HOWTO /usr/share/doc/intltool-0.51.0/I18N-HOWTO
```

Cleanup
```bash
cd /sources
rm -rvf intltool-0.51.0
```

#### Autoconf

Extraction
```bash
tar -xvf autoconf-2.72.tar.xz
cd autoconf-2.72
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf autoconf-2.72
```

#### Automake

Extraction
```bash
tar -xvf automake-1.18.1.tar.xz
cd automake-1.18.1
```

Configuration
```bash
./configure --prefix=/usr --docdir=/usr/share/doc/automake-1.18.1
```

Compilation et check
```bash
make
make -j$(($(nproc)>4?$(nproc):4)) check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf automake-1.18.1
```

#### OpenSSL

Extraction
```bash
tar -xvf openssl-3.5.2.tar.gz
cd openssl-3.5.2
```

Configuration
```bash
./config --prefix=/usr         \
         --openssldir=/etc/ssl \
         --libdir=lib          \
         shared                \
         zlib-dynamic
```

Compilation et check
```bash
make
HARNESS_JOBS=$(nproc) make test
```

Installation
```bash
sed -i '/INSTALL_LIBS/s/libcrypto.a libssl.a//' Makefile
make MANSUFFIX=ssl install
```

Documentation
```bash
mv -v /usr/share/doc/openssl /usr/share/doc/openssl-3.5.2
cp -vfr doc/* /usr/share/doc/openssl-3.5.2
```

Cleanup
```bash
cd /sources
rm -rvf openssl-3.5.2
```

#### Libelf (de Elfutils)

Extraction
```bash
tar -xvf elfutils-0.193.tar.bz2
cd elfutils-0.193
```

Configuration
```bash
./configure --prefix=/usr        \
            --disable-debuginfod \
            --enable-libdebuginfod=dummy
```

Compilation et check
```bash
make
make check
```
> Erreur connue pour `dwarf_srclang_check` et `run-backtrace-native-core.sh`. OK si ce sont les seuls

Installation
```bash
make -C libelf install
install -vm644 config/libelf.pc /usr/lib/pkgconfig
rm /usr/lib/libelf.a
```

Cleanup
```bash
cd /sources
rm -rvf elfutils-0.193
```

#### Libffi

Extraction
```bash
tar -xvf libffi-3.5.2.tar.gz
cd libffi-3.5.2
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static \
            --with-gcc-arch=native
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf libffi-3.5.2
```

#### Sqlite

Extraction
```bash
tar -xvf sqlite-autoconf-3500400.tar.gz
cd sqlite-autoconf-3500400
```

Documentation
```bash
tar -xf ../sqlite-doc-3500400.tar.xz
```

Configuration
```bash
./configure --prefix=/usr    \
            --disable-static  \
            --enable-fts{4,5} \
            CPPFLAGS="-D SQLITE_ENABLE_COLUMN_METADATA=1 \
                      -D SQLITE_ENABLE_UNLOCK_NOTIFY=1   \
                      -D SQLITE_ENABLE_DBSTAT_VTAB=1     \
                      -D SQLITE_SECURE_DELETE=1"
```

Compilation
```bash
make
```

Installation
```bash
make install
install -v -m755 -d /usr/share/doc/sqlite-3.50.4
cp -v -R sqlite-doc-3500400/* /usr/share/doc/sqlite-3.50.4
```

Cleanup
```bash
cd /sources
rm -rvf sqlite-autoconf-3500400
```

#### Python3.13

Extraction
```bash
tar -xvf Python-3.13.7.tar.xz
cd Python-3.13.7
```

Configuration
```bash
./configure --prefix=/usr          \
            --enable-shared        \
            --with-system-expat    \
            --enable-optimizations \
            --without-static-libpython
```

Compilation et check
```bash
make
make test TESTOPTS="--timeout 120"
```

Installation
```bash
make install
```

Warning `pip3` et `python3` en silencieux
```bash
cat > /etc/pip.conf << EOF
[global]
root-user-action = ignore
disable-pip-version-check = true
EOF
```

Documentation
```bash
install -v -dm755 /usr/share/doc/python-3.13.7/html

tar --strip-components=1  \
    --no-same-owner       \
    --no-same-permissions \
    -C /usr/share/doc/python-3.13.7/html \
    -xvf ../python-3.13.7-docs-html.tar.bz2
```

Cleanup
```bash
cd /sources
rm -rvf Python-3.13.7
```

#### Flit-core

Extraction
```bash
tar -xvf flit_core-3.12.0.tar.gz
cd flit_core-3.12.0
```

Build
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist flit_core
```

Cleanup
```bash
cd /sources
rm -rvf flit_core-3.12.0
```

#### Packaging

Extraction
```bash
tar -xvf packaging-25.0.tar.gz
cd packaging-25.0
```

Compilation
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist packaging
```

Cleanup
```bash
cd /sources
rm -rvf packaging-25.0
```

#### Wheel

Extraction
```bash
tar -xvf wheel-0.46.1.tar.gz
cd wheel-0.46.1
```

Compilation
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist wheel
```

Cleanup
```bash
cd /sources
rm -rvf wheel-0.46.1
```

#### Setuptools

Extraction
```bash
tar -xvf setuptools-80.9.0.tar.gz
cd setuptools-80.9.0
```

Build
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist setuptools
```

Cleanup
```bash
cd /sources
rm -rvf setuptools-80.9.0
```

#### Ninja

Extraction
```bash
tar -xvf ninja-1.13.1.tar.gz
cd ninja-1.13.1
```

Environnement
```bash
export NINJAJOBS=4
sed -i '/int Guess/a \
  int   j = 0;\
  char* jobs = getenv( "NINJAJOBS" );\
  if ( jobs != NULL ) j = atoi( jobs );\
  if ( j > 0 ) return j;\
' src/ninja.cc
```

Build 
```bash
python3 configure.py --bootstrap --verbose
```

Installation
```bash
install -vm755 ninja /usr/bin/
install -vDm644 misc/bash-completion /usr/share/bash-completion/completions/ninja
install -vDm644 misc/zsh-completion  /usr/share/zsh/site-functions/_ninja
```

Cleanup
```bash
unset NINJAJOBS
cd /sources
rm -rvf ninja-1.13.1
```

#### Meson

Extraction
```bash
tar -xvf meson-1.8.3.tar.gz
cd meson-1.8.3
```

Compilation
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist meson
install -vDm644 data/shell-completions/bash/meson /usr/share/bash-completion/completions/meson
install -vDm644 data/shell-completions/zsh/_meson /usr/share/zsh/site-functions/_meson
```

Cleanup
```bash
cd /sources
rm -rvf meson-1.8.3
```

#### Kmod

Extraction
```bash
tar -xvf kmod-34.2.tar.xz
cd kmod-34.2
```

Dossier de build
```bash
mkdir -p build
cd       build

meson setup --prefix=/usr ..    \
            --buildtype=release \
            -D manpages=false
```

Compilation
```bash
ninja
```

Installation
```bash
ninja install
```

Cleanup
```bash
cd /sources
rm -rvf kmod-34.2
```

#### Coreutils

Extraction
```bash
tar -xvf coreutils-9.7.tar.xz
cd coreutils-9.7
```

Patches
```bash
patch -Np1 -i ../coreutils-9.7-upstream_fix-1.patch
patch -Np1 -i ../coreutils-9.7-i18n-1.patch
```

Configuration
```bash
autoreconf -fv
automake -af
FORCE_UNSAFE_CONFIGURE=1 ./configure \
            --prefix=/usr            \
            --enable-no-install-program=kill,uptime
```

Coompilation et check
```bash
make
make NON_ROOT_USERNAME=tester check-root
```

Sanity checks (optionnel)
```bash
groupadd -g 102 dummy -U tester
chown -R tester . 
su tester -c "PATH=$PATH make -k RUN_EXPENSIVE_TESTS=yes check" \
   < /dev/null
groupdel dummy
```

Installation
```bash
make install
```

Deplacer les binaires
```bash
mv -v /usr/bin/chroot /usr/sbin
mv -v /usr/share/man/man1/chroot.1 /usr/share/man/man8/chroot.8
sed -i 's/"1"/"8"/' /usr/share/man/man8/chroot.8
```

Cleanup
```bash
cd /sources
rm -rvf coreutils-9.7
```

#### Diffutils

Extraction
```bash
tar -xvf diffutils-3.12.tar.xz
cd diffutils-3.12
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf diffutils-3.12
```

#### Gawk

Extraction
```bash
tar -xvf gawk-5.3.2.tar.xz
cd gawk-5.3.2
```

Configuration
```bash
sed -i 's/extras//' Makefile.in
./configure --prefix=/usr
```

Compilation et check
```bash
make
chown -R tester .
su tester -c "PATH=$PATH make check"
```

Installation
```bash
rm -f /usr/bin/gawk-5.3.2
make install
```

Documentaion
```bash
ln -sv gawk.1 /usr/share/man/man1/awk.1
install -vDm644 doc/{awkforai.txt,*.{eps,pdf,jpg}} -t /usr/share/doc/gawk-5.3.2
```

Cleanup
```bash
cd /sources
rm -rvf gawk-5.3.2
```

#### Findutils

Extraction
```bash
tar -xvf findutils-4.10.0.tar.xz
cd findutils-4.10.0
```

Configuration
```bash
./configure --prefix=/usr --localstatedir=/var/lib/locate
```

Compilation et check
```bash
make
chown -R tester .
su tester -c "PATH=$PATH make check"
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf findutils-4.10.0
```

#### Groff

Extraction
```bash
tar -xvf groff-1.23.0.tar.gz
cd groff-1.23.0
```

Configuration
```bash
PAGE=A4 ./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf groff-1.23.0
```

#### Grub

Unset environnement (important!)
```bash
unset {C,CPP,CXX,LD}FLAGS
```

Extraction
```bash
tar -xvf grub-2.12.tar.xz
cd grub-2.12
```

Ajout fichier manquant
```bash
echo depends bli part_gpt > grub-core/extra_deps.lst
```

Configuration
```bash
./configure --prefix=/usr     \
            --sysconfdir=/etc \
            --disable-efiemu  \
            --disable-werror
```

Compilation
```bash
make
```

Installation
```bash
make install
mv -v /etc/bash_completion.d/grub /usr/share/bash-completion/completions
```

Cleanup
```bash
cd /sources
rm -rvf grub-2.12
```

#### Gzip

Extraction
```bash
tar -xvf gzip-1.14.tar.xz
cd gzip-1.14
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf gzip-1.14
```

#### IPRoute2

Extraction
```bash
tar -xvf iproute2-6.16.0.tar.xz
cd iproute2-6.16.0
```

Fix `arpd` 
```bash
sed -i /ARPD/d Makefile
rm -fv man/man8/arpd.8
```

Compilation
```bash
make NETNS_RUN_DIR=/run/netns
```

Installation
```bash
make SBINDIR=/usr/sbin install
install -vDm644 COPYING README* -t /usr/share/doc/iproute2-6.16.0
```

Cleanup
```bash
cd /sources
rm -rvf iproute2-6.16.0
```

#### Kbd

Extraction
```bash
tar -xvf kbd-2.8.0.tar.xz
cd kbd-2.8.0
```

Patch
```bash
patch -Np1 -i ../kbd-2.8.0-backspace-1.patch
```

Configuration
```bash
./configure --prefix=/usr --disable-vlock
```

Compilation
```bash
make
```

Installation
```bash
make install
cp -R -v docs/doc -T /usr/share/doc/kbd-2.8.0
```

Cleanup
```bash
cd /sources
rm -rvf kbd-2.8.0
```

#### Libpipeline

Extraction
```bash
tar -xvf libpipeline-1.5.8.tar.gz
cd libpipeline-1.5.8
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation
```bash
make
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf libpipeline-1.5.8
```

#### Make

Extraction
```bash
tar -xvf make-4.4.1.tar.gz
cd make-4.4.1
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
chown -R tester .
su tester -c "PATH=$PATH make check"
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf make-4.4.1
```

#### Patch

Extraction
```bash
tar -xvf patch-2.8.tar.xz
cd patch-2.8
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf patch-2.8
```

#### Tar

Extraction
```bash
tar -xvf tar-1.35.tar.xz
cd tar-1.35
```

Configuration
```bash
FORCE_UNSAFE_CONFIGURE=1  \
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```
> test `233` est connu pour echouer, il peut etre ignore

Installation
```bash
make install
make -C doc install-html docdir=/usr/share/doc/tar-1.35
```

Cleanup
```bash
cd /sources
rm -rvf tar-1.35
```

#### Texinfo

Extraction
```bash
tar -xvf texinfo-7.2.tar.xz
cd texinfo-7.2
```

Suppression d'un warning Perl
```bash
sed 's/! $output_file eq/$output_file ne/' -i tp/Texinfo/Convert/*.pm
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
make TEXMF=/usr/share/texmf install-tex
```

Cleanup
```bash
cd /sources
rm -rvf texinfo-7.2
```

#### Vim

Extraction
```bash
tar -xvf vim-9.1.1629.tar.gz
cd vim-9.1.1629
```

Changer location `vimrc`
```bash
echo '#define SYS_VIMRC_FILE "/etc/vimrc"' >> src/feature.h
```

Configuration
```bash
./configure --prefix=/usr
```

Compilation et check
```bash
make
chown -R tester .
sed '/test_plugin_glvs/d' -i src/testdir/Make_all.mak
su tester -c "TERM=xterm-256color LANG=en_US.UTF-8 make -j1 test" \
   &> vim-test.log
```

Installation
```bash
make install
ln -sv vim /usr/bin/vi
for L in  /usr/share/man/{,*/}man1/vim.1; do
    ln -sv vim.1 $(dirname $L)/vi.1
done
ln -sv ../vim/vim91/doc /usr/share/doc/vim-9.1.1629
```

Configuration de base
```bash
cat > /etc/vimrc << "EOF"
" Begin /etc/vimrc

" Ensure defaults are set before customizing settings, not after
source $VIMRUNTIME/defaults.vim
let skip_defaults_vim=1

set nocompatible
set backspace=2
set mouse=a
set number
syntax on
if (&term == "xterm") || (&term == "putty")
  set background=dark
endif

" End /etc/vimrc
EOF
```

Cleanup
```bash
cd /sources
rm -rvf vim-9.1.1629
```

#### MarkupSafe

Extraction
```bash
tar -xvf markupsafe-3.0.2.tar.gz
cd markupsafe-3.0.2
```

Compilation
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist Markupsafe
```

Cleanup
```bash
cd /sources
rm -rvf markupsafe-3.0.2
```

#### Jinja2

Extraction
```bash
tar -xvf jinja2-3.1.6.tar.gz
cd jinja2-3.1.6
```

Compilation
```bash
pip3 wheel -w dist --no-cache-dir --no-build-isolation --no-deps $PWD
```

Installation
```bash
pip3 install --no-index --find-links dist Jinja2
```

Cleanup
```bash
cd /sources
rm -rvf jinja2-3.1.6
```

#### Udev

Extraction
```bash
tar -xvf systemd-257.8.tar.gz
cd systemd-257.8
```

Smnall fixes
```bash
sed -e 's/GROUP="render"/GROUP="video"/' \
    -e 's/GROUP="sgx", //'               \
    -i rules.d/50-udev-default.rules.in
sed -i '/systemd-sysctl/s/^/#/' rules.d/99-systemd.rules.in
sed -e '/NETWORK_DIRS/s/systemd/udev/' \
    -i src/libsystemd/sd-network/network-util.h
```

Dossier de build + configuration
```bash
mkdir -p build
cd       build

meson setup ..                  \
      --prefix=/usr             \
      --buildtype=release       \
      -D mode=release           \
      -D dev-kvm-mode=0660      \
      -D link-udev-shared=false \
      -D logind=false           \
      -D vconsole=false
```

Helpers `udev` + Compilation
```bash
export udev_helpers=$(grep "'name' :" ../src/udev/meson.build | \
                      awk '{print $3}' | tr -d ",'" | grep -v 'udevadm')
ninja udevadm systemd-hwdb                                           \
      $(ninja -n | grep -Eo '(src/(lib)?udev|rules.d|hwdb.d)/[^ ]*') \
      $(realpath libudev.so --relative-to .)                         \
      $udev_helpers
```

Installation
```bash
install -vm755 -d {/usr/lib,/etc}/udev/{hwdb.d,rules.d,network}
install -vm755 -d /usr/{lib,share}/pkgconfig
install -vm755 udevadm                             /usr/bin/
install -vm755 systemd-hwdb                        /usr/bin/udev-hwdb
ln      -svfn  ../bin/udevadm                      /usr/sbin/udevd
cp      -av    libudev.so{,*[0-9]}                 /usr/lib/
install -vm644 ../src/libudev/libudev.h            /usr/include/
install -vm644 src/libudev/*.pc                    /usr/lib/pkgconfig/
install -vm644 src/udev/*.pc                       /usr/share/pkgconfig/
install -vm644 ../src/udev/udev.conf               /etc/udev/
install -vm644 rules.d/* ../rules.d/README         /usr/lib/udev/rules.d/
install -vm644 $(find ../rules.d/*.rules \
                      -not -name '*power-switch*') /usr/lib/udev/rules.d/
install -vm644 hwdb.d/*  ../hwdb.d/{*.hwdb,README} /usr/lib/udev/hwdb.d/
install -vm755 $udev_helpers                       /usr/lib/udev
install -vm644 ../network/99-default.link          /usr/lib/udev/network
```

Regles customs `udev`
```bash
tar -xvf ../../udev-lfs-20230818.tar.xz
make -f udev-lfs-20230818/Makefile.lfs install
```

Manpages
```bash
tar -xf ../../systemd-man-pages-257.8.tar.xz                            \
    --no-same-owner --strip-components=1                              \
    -C /usr/share/man --wildcards '*/udev*' '*/libudev*'              \
                                  '*/systemd.link.5'                  \
                                  '*/systemd-'{hwdb,udevd.service}.8

sed 's|systemd/network|udev/network|'                                 \
    /usr/share/man/man5/systemd.link.5                                \
  > /usr/share/man/man5/udev.link.5

sed 's/systemd\(\\\?-\)/udev\1/' /usr/share/man/man8/systemd-hwdb.8   \
                               > /usr/share/man/man8/udev-hwdb.8

sed 's|lib.*udevd|sbin/udevd|'                                        \
    /usr/share/man/man8/systemd-udevd.service.8                       \
  > /usr/share/man/man8/udevd.8

rm /usr/share/man/man*/systemd*
```

Unset helper
```bash
unset udev_helpers
```

Configuration
```bash
udev-hwdb update
```

Cleanup
```bash
cd /sources
rm -rvf systemd-257.8
```

#### Man-DB

Extraction
```bash
tar -xvf man-db-2.13.1.tar.xz
cd man-db-2.13.1
```

Configuration
```bash
./configure --prefix=/usr                         \
            --docdir=/usr/share/doc/man-db-2.13.1 \
            --sysconfdir=/etc                     \
            --disable-setuid                      \
            --enable-cache-owner=bin              \
            --with-browser=/usr/bin/lynx          \
            --with-vgrind=/usr/bin/vgrind         \
            --with-grap=/usr/bin/grap             \
            --with-systemdtmpfilesdir=            \
            --with-systemdsystemunitdir=
```

Compilation et check
```bash
make
make check
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf man-db-2.13.1
```

#### Procps-ng

Extraction
```bash
tar -xvf procps-ng-4.0.5.tar.xz
cd procps-ng-4.0.5
```

Configuration
```bash
./configure --prefix=/usr                           \
            --docdir=/usr/share/doc/procps-ng-4.0.5 \
            --disable-static                        \
            --disable-kill                          \
            --enable-watch8bit
```

Compilation et check
```bash
make
chown -R tester .
su tester -c "PATH=$PATH make check"
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf procps-ng-4.0.5
```

#### Util-linux

Extraction
```bash
tar -xvf util-linux-2.41.1.tar.xz
cd util-linux-2.41.1
```

Configuration
```bash
./configure --bindir=/usr/bin     \
            --libdir=/usr/lib     \
            --runstatedir=/run    \
            --sbindir=/usr/sbin   \
            --disable-chfn-chsh   \
            --disable-login       \
            --disable-nologin     \
            --disable-su          \
            --disable-setpriv     \
            --disable-runuser     \
            --disable-pylibmount  \
            --disable-liblastlog2 \
            --disable-static      \
            --without-python      \
            --without-systemd     \
            --without-systemdsystemunitdir        \
            ADJTIME_PATH=/var/lib/hwclock/adjtime \
            --docdir=/usr/share/doc/util-linux-2.41.1
```

Compilation
```bash
make
```

Tests
```bash
touch /etc/fstab
chown -R tester .
su tester -c "make -k check"
```
> `kill: decode` connnue pour fail, peut etre ignoré

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf util-linux-2.41.1
```

#### E2fsprogs

Extraction
```bash
tar -xvf e2fsprogs-1.47.3.tar.gz
cd e2fsprogs-1.47.3
```

Dossier de build
```bash
mkdir -v build
cd       build
```

Configuration
```bash
../configure --prefix=/usr       \
             --sysconfdir=/etc   \
             --enable-elf-shlibs \
             --disable-libblkid  \
             --disable-libuuid   \
             --disable-uuidd     \
             --disable-fsck
```

Compilation et check
```bash
make
make check
```
> `m_assume_storage_prezeroed` connu pour fail, peut etre ignoré

Installation
```bash
make install
```

Petit cleanup
```bash
rm -fv /usr/lib/{libcom_err,libe2p,libext2fs,libss}.a
```

MAJ `dir`
```bash
gunzip -v /usr/share/info/libext2fs.info.gz
install-info --dir-file=/usr/share/info/dir /usr/share/info/libext2fs.info
```

Documentation
```bash
makeinfo -o      doc/com_err.info ../lib/et/com_err.texinfo
install -v -m644 doc/com_err.info /usr/share/info
install-info --dir-file=/usr/share/info/dir /usr/share/info/com_err.info
```

Configuration
```bash
sed 's/metadata_csum_seed,//' -i /etc/mke2fs.conf
```

Cleanup
```bash
cd /sources
rm -rvf e2fsprogs-1.47.3
```

#### Sysklogd

Extraction
```bash
tar -xvf sysklogd-2.7.2.tar.gz
cd sysklogd-2.7.2
```

Configuration
```bash
./configure --prefix=/usr      \
            --sysconfdir=/etc  \
            --runstatedir=/run \
            --without-logger   \
            --disable-static   \
            --docdir=/usr/share/doc/sysklogd-2.7.2
```

Compilation
```bash
make
```

Installation
```bash
make install
```

Configuration de base
```bash
cat > /etc/syslog.conf << "EOF"
# Begin /etc/syslog.conf

auth,authpriv.* -/var/log/auth.log
*.*;auth,authpriv.none -/var/log/sys.log
daemon.* -/var/log/daemon.log
kern.* -/var/log/kern.log
mail.* -/var/log/mail.log
user.* -/var/log/user.log
*.emerg *

# Do not open any internet ports.
secure_mode 2

# End /etc/syslog.conf
EOF
```

Cleanup
```bash
cd /sources
rm -rvf sysklogd-2.7.2
```

#### SysVinit

Extraction
```bash
tar -xvf sysvinit-3.14.tar.xz
cd sysvinit-3.14
```

Patch
```bash
patch -Np1 -i ../sysvinit-3.14-consolidated-1.patch
```

Compilation
```bash
make
```

Installation
```bash
make install
```

Cleanup
```bash
cd /sources
rm -rvf sysvinit-3.14
```

#### Stripping

Cette section est optionnelle, elle sert a alleger les binaires en supprimant les symboles de debug (necessaires a `valgrind` ou `gdb` par exemple). Dans notre cas, il est preferable de les garder (sauf si tu debug encore au `printf` alors la tu peux faire de la place si tu veux)

#### Cleanup final

Ce fut long je t'avoue, mais au moins tout est bien installé (enfin presque). On fait un petit coup de nettoyage final

```bash
rm -rf /tmp/{*,.*}
find /usr/lib /usr/libexec -name \*.la -delete
find /usr -depth -name $(uname -m)-lfs-linux-gnu\* | xargs rm -rf
userdel -r tester
```

## Configuration système

([suite ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/chapter09/chapter09.html))

A faire au prochain reboot : 

Root
```bash
sudo su -
```

Montages
```bash
export LFS=/mnt/lfs

mkdir -pv $LFS
mount -v /dev/vdb4 $LFS
mkdir -pv $LFS/{boot,dev,proc,sys,run}
mount -v /dev/vdb2 $LFS/boot

swapon -v /dev/vdb3

mount -v --bind /dev $LFS/dev
mount -vt devpts devpts $LFS/dev/pts -o gid=5,mode=620
mount -vt proc proc $LFS/proc
mount -vt sysfs sysfs $LFS/sys
mount -vt tmpfs tmpfs $LFS/run

if [ -h $LFS/dev/shm ]; then
  mkdir -pv $LFS/$(readlink $LFS/dev/shm)
fi
```

Chroot
```bash
chroot "$LFS" /usr/bin/env -i   \
    HOME=/root                  \
    TERM="$TERM"                \
    PS1='(lfs chroot) \u:\w\$ ' \
    PATH=/usr/bin:/usr/sbin     \
    MAKEFLAGS="-j$(nproc)"      \
    TESTSUITEFLAGS="-j$(nproc)" \
    /bin/bash --login
```

Et c'est reparti
