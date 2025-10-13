> Je travaille ce projet sur un MacBook Pro M3 Max 36go (2023) avec macOS Tahoe 26.1. Ma solution pour manager mes VMs est [UTM](https://mac.getutm.app/). Il se peut que certaines configurations soient différentes sur d'autres systèmes d'exploitation.  

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
#   aarch64-lfs-linux-gnu # peut varier selon l'archi
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
rm -rf binutils-2.45
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
rm -rf gcc-15.2.0
```
