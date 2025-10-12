## Prérequis

Téléchargement de l'image Ubuntu ARMv8
https://cdimage.ubuntu.com/releases/22.04/release/ubuntu-22.04.5-live-server-arm64.iso

Installation de la VM sur UTM
Create > Virtualize (CPU Architecture) > ajouter le ISO

Installation de Ubuntu
> Suivre les etapes d'installation classique

Installation SSH
```bash
sudo su
apt-get update
apt-get upgrade -y
apt-get install -y openssh-server
exec <&-
ip address | grep inet
```

Connexion en SSH
```bash
ssh cedmulle@192.168.64.6
```
> Nous passerons maintenant toutes les commandes en SSH (plus confortable)

Installation des prérequis
```bash
sudo apt-get update -y
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get autoremove --purge -y </dev/null
sudo apt-get autoclean -y </dev/null
sudo apt-get clean -y </dev/null
sudo rm -rf /bin/sh
sudo ln -s /usr/bin/bash /bin/sh
sudo apt-get install apt-file automake build-essential git liblocale-msgfmt-perl locales-all parted bison make patch texinfo gawk vim g++ bash gzip binutils findutils gawk gcc libc6 grep gzip m4 make patch perl sed tar texinfo xz-utils bison curl libncurses-dev flex bison openssl libssl-dev dkms libelf-dev libudev-dev libpci-dev libiberty-dev autoconf --fix-missing -y
```

Lister les disques
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
```

Exemple de sortie
```bash
NAME                       SIZE TYPE MOUNTPOINT
sr0                       1024M rom
vda                         32G disk
├─vda1                       1G part /boot/efi
├─vda2                       2G part /boot
└─vda3                    28.9G part
  └─ubuntu--vg-ubuntu--lv 14.5G lvm  /
```

Arreter la VM
```bash
sudo poweroff
```

Ajouter un nouveau disque virtuel dans UTM
```plaintext
Paramètres > Lecteurs > Nouveau...
	•	Amovible?  : désactivé
	•	Interface : VirtIO
	•	Type d'image : Image disque
	•	Taille : 32 Go
```

<br>

## Partitions

Redemarrer la VM, se reconnecter en SSH et lister les disques
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT
```

Exemple de sortie
```bash
NAME                       SIZE TYPE MOUNTPOINT
sr0                       1024M rom
vda                         32G disk
├─vda1                       1G part /boot/efi
├─vda2                       2G part /boot
└─vda3                    28.9G part
  └─ubuntu--vg-ubuntu--lv 14.5G lvm  /
vdb                         32G disk
```
> Notre nouveau disque est bien présent (vdb)

Nettoyer le nouveau disque
```bash
wipefs -a /dev/vdb
```

Lancer fdisk pour partitionner le disque
```bash
fdisk /dev/vdb
```

Dans fdisk, créer les partitions nécessaires

- Créer partition 1 (EFI)
```bash
g			# créer une table de partition GPT
n			# nouvelle partition
<ENTRÉE>	# numéro de partition par défaut
<ENTRÉE>	# premier secteur par défaut
+512M		# taille : 512 Mo
t			# changer le type de partition
1			# code EFI System (FAT32)
```

- Créer partition 2 (/boot)
```bash
n			# nouvelle partition
<ENTRÉE>	# numéro de partition par défaut
<ENTRÉE>	# premier secteur par défaut
+200M		# taille : 200 Mo
t			# changer le type de partition
2			# numéro de la partition
20			# type Linux filesystem /boot
```

- Créer partition 3 (swap)
```bash
n			# nouvelle partition
<ENTRÉE>	# numéro de partition par défaut
<ENTRÉE>	# premier secteur par défaut
+4G			# taille : 4 Go
t			# changer le type de partition
3			# type Linux swap
19			# type Linux swap
```

- Créer partition 4 (root)
```bash
n			# nouvelle partition
<ENTRÉE>	# numéro de partition par défaut
<ENTRÉE>	# premier secteur par défaut
<ENTRÉE>	# dernier secteur par défaut
```

- Vérifier la table de partition et enregistrer
```bash
p			# afficher la table de partition
w			# écrire la table de partition et quitter
```

<details>
<summary>Exemple de sortie</summary>

- Exemple de sortie
```plaintext
Welcome to fdisk (util-linux 2.37.2).
Changes will remain in memory only, until you decide to write them.
Be careful before using the write command.

Device does not contain a recognized partition table.
Created a new DOS disklabel with disk identifier 0x28e1a6c8.

Command (m for help): g
Created a new GPT disklabel (GUID: BB719C85-3CE3-0844-80B1-82C2A2F8D4D9).

Command (m for help): n
Partition number (1-128, default 1):
First sector (2048-67108830, default 2048):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (2048-67108830, default 67108830): +512M

Created a new partition 1 of type 'Linux filesystem' and of size 512 MiB.

Command (m for help): t
Selected partition 1
Partition type or alias (type L to list all): 1
Changed type of partition 'Linux filesystem' to 'EFI System'.

Command (m for help): n
Partition number (2-128, default 2):
First sector (1050624-67108830, default 1050624):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (1050624-67108830, default 67108830): +200M

Created a new partition 2 of type 'Linux filesystem' and of size 200 MiB.

Command (m for help): t
Partition number (1,2, default 2): 2
Partition type or alias (type L to list all): 20

Changed type of partition 'Linux filesystem' to 'Linux filesystem'.

Command (m for help): n
Partition number (3-128, default 3):
First sector (1460224-67108830, default 1460224):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (1460224-67108830, default 67108830): +4G

Created a new partition 3 of type 'Linux filesystem' and of size 4 GiB.

Command (m for help): t
Partition number (1-3, default 3): 3
Partition type or alias (type L to list all): 19

Changed type of partition 'Linux filesystem' to 'Linux swap'.

Command (m for help): n
Partition number (4-128, default 4):
First sector (9848832-67108830, default 9848832):
Last sector, +/-sectors or +/-size{K,M,G,T,P} (9848832-67108830, default 67108830):

Created a new partition 4 of type 'Linux filesystem' and of size 27.3 GiB.

Command (m for help): p
Disk /dev/vdb: 32 GiB, 34359738368 bytes, 67108864 sectors
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: BB719C85-3CE3-0844-80B1-82C2A2F8D4D9

Device       Start      End  Sectors  Size Type
/dev/vdb1     2048  1050623  1048576  512M EFI System
/dev/vdb2  1050624  1460223   409600  200M Linux filesystem
/dev/vdb3  1460224  9848831  8388608    4G Linux swap
/dev/vdb4  9848832 67108830 57259999 27.3G Linux filesystem

Command (m for help): w
The partition table has been altered.
Calling ioctl() to re-read partition table.
Syncing disks.
```
</details>

Verifier les partitions
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE /dev/vdb
```

Exemple de sortie
```bash
NAME                       SIZE TYPE MOUNTPOINT
vdb                         32G disk
├─vdb1                     512M part
├─vdb2                     200M part
├─vdb3                       4G part
└─vdb4                    27.3G part
```
> Nos partitions sont bien créées (vdb1, vdb2, vdb3, vdb4)

Installer outils de formatage FAT
```bash
apt-get install dosfstools -y
```

Formater les partitions créées
```bash
mkfs.vfat -F32 /dev/vdb1        # EFI (obligatoire pour UEFI ARM64)
mkfs.ext2 -v /dev/vdb2          # /boot
mkswap /dev/vdb3                # swap
mkfs.ext4 -v /dev/vdb4          # / (root)
```

Vérifier les systèmes de fichiers
```bash
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE /dev/vdb
```

Exemple de sortie
```bash
NAME   UUID                                 FSTYPE  SIZE
vdb                                                  32G
├─vdb1 ADB6-12C0                            vfat    512M
├─vdb2 41502ba2-469c-4b17-93cb-838eed971fb6 ext2    200M
├─vdb3 86596d24-e9f8-49ad-9067-c86455d0f449 swap      4G
└─vdb4 fca32065-40c1-479a-8b4e-614688decac8 ext4   27.3G
```
> Nous voyons maintenant que les FSTYPE sont bien passés de `part` à `vfat`, `ext2`, `swap` et `ext4`

<br>

## Préparation

Monter les nouvelles partitions
```bash
# 1) Monter la racine LFS
mkdir -pv /mnt/lfs
mount -v /dev/vdb4 /mnt/lfs

# 2) Monter /boot et l’ESP (EFI)
mkdir -pv /mnt/lfs/boot
mount -v /dev/vdb2 /mnt/lfs/boot

mkdir -pv /mnt/lfs/boot/efi
mount -v /dev/vdb1 /mnt/lfs/boot/efi

# 3) Activer le swap
swapon /dev/vdb3
```

Verifier les montages
```bash
lsblk -o NAME,MOUNTPOINT,FSTYPE,SIZE /dev/vdb
```

Exemple de sortie
```bash
NAME   MOUNTPOINT        FSTYPE  SIZE
vdb                               32G
├─vdb1 /mnt/lfs/boot/efi vfat    512M
├─vdb2 /mnt/lfs/boot     ext2    200M
├─vdb3 [SWAP]            swap      4G
└─vdb4 /mnt/lfs          ext4   27.3G
```
> Nos montages sont corrects

Verifier que le répertoire LFS est vide
```bash
ls -lRa /mnt/lfs
```

Exemple de sortie
```bash
/mnt/lfs:
total 12
drwxr-xr-x 3 root root 4096 Oct  9 09:21 .
drwxr-xr-x 3 root root 4096 Oct  9 09:14 ..
drwxr-xr-x 3 root root 4096 Oct  9 09:21 boot

/mnt/lfs/boot:
total 12
drwxr-xr-x 3 root root 4096 Oct  9 09:21 .
drwxr-xr-x 3 root root 4096 Oct  9 09:21 ..
drwxr-xr-x 2 root root 4096 Jan  1  1970 efi

/mnt/lfs/boot/efi:
total 8
drwxr-xr-x 2 root root 4096 Jan  1  1970 .
drwxr-xr-x 3 root root 4096 Oct  9 09:21 ..
```
> Le répertoire LFS est bien vide

<br>

## Téléchargements

Créer le repértoire sources
```bash
mkdir -pv /mnt/lfs/sources
chmod -v a+wt /mnt/lfs/sources
```
> Le bit `t` dans les permissions permet d'empêcher un utilisateur de supprimer ou renommer un fichier dans ce répertoire, à moins qu'il en soit le propriétaire.

Telecharger la liste des paquets + leurs checksums
```bash
cd ~
# source : linuxfromscratch.org
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/sources_list.txt -o sources_list.txt
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/sources_list_md5.txt -o sources_list_md5.txt
```

Verifier leurs présence
```bash
ls -l sources_list.txt sources_list_md5.txt
```

Télécharger les paquets
```bash
wget --input-file=sources_list.txt --continue --directory-prefix=/mnt/lfs/sources
```
> Cette étape prends un moment, va te chercher un café, prendre l'air, faire une sieste, etc.

Vérifier les checksums
```bash
cp sources_list_md5.txt /mnt/lfs/sources/md5sums
pushd /mnt/lfs/sources
md5sum -c md5sums
popd
```
> Tout les fichiers doivent être OK. Si ce n'est pas le cas, vérifier que vous avez bien la dernière version de la liste des paquets, et relancer le téléchargement des paquets :  
https://www.linuxfromscratch.org/lfs/downloads/stable/md5sums  
https://www.linuxfromscratch.org/lfs/downloads/stable/wget-list  

## Préparation du LFS

Creer les repertoires necessaires
```bash
mkdir -pv /mnt/lfs/tools
ln -sv /mnt/lfs/tools /
# Dossiers de base
mkdir -pv /mnt/lfs/{etc,var}
mkdir -pv /mnt/lfs/usr/{bin,lib,sbin}
```

Config les liens de compatibilité du futur lfs
```bash
for i in bin lib sbin; do
  ln -sv usr/$i /mnt/lfs/$i
done
```

Creer le groupe et l'utilisateur LFS
```bash
# 1. creer le groupe
groupadd lfs
# 2. creer l'utilisateur
useradd -s /bin/bash -g lfs -m -k /dev/null lfs
# 3. definir le mot de passe
echo -e "lfs\nlfs" | passwd lfs
# 4. definir l'ownership
chown -v lfs /mnt/lfs/tools
chown -v lfs /mnt/lfs/sources
chown -v lfs /mnt/lfs/{usr,lib,var,etc,bin,sbin}
chown -v lfs /mnt/lfs/usr/{bin,lib,sbin}
```

Check que tout se soit bien passé
```bash
getent passwd lfs
getent group lfs
ls -ld /mnt/lfs/tools
ls -ld /mnt/lfs/sources 
ls -ld /mnt/lfs/{usr,lib,var,etc,bin,sbin}
ls -ld /mnt/lfs/usr/{bin,lib,sbin}
```

## Configuration de l'environnement (User `lfs`)

Passer en utilisateur LFS
```bash
su - lfs
```

Configurer l'environnement
```bash
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
```
(suite...)
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

Recharger le profile et définir MAKEFLAGS
```bash
source ~/.bash_profile
export MAKEFLAGS='-j$(nproc)'
exec <&-
```
> Le `-j$(nproc)` permet d'utiliser tous les coeurs CPU pour la compilation  
> Si erreur `bash: /bin/sh: No such file or directory`, c'est que le `ln -s /usr/bin/bash /bin/sh` n'a pas été fait  
> le `exec <&-` permet de fermer STDIN, nécessaire pour certaines commandes comme `passwd`  

Check de l'environnement
```bash
echo "$LFS"        # doit afficher /mnt/lfs
echo "$LFS_TGT"    # doit afficher aarch64-lfs-linux-gnu
which bash         # /usr/bin/bash
which env          # /usr/bin/env
echo "$PATH"       # doit commencer par /mnt/lfs/tools/bin:/usr/bin
```

## Configuration de l'environnement (User `root`)

Revenir en root
```bash
exit # si tu es en lfs, ctrl+D marche aussi bien
[ -f ~/.bash_profile ] && cp -a ~/.bash_profile ~/.bash_profile.bak
[ -f ~/.bashrc ] && cp -a ~/.bashrc ~/.bashrc.bak
```
> toujours une petite sauvegarde avant de modifier  

Creer profil minimal pour root
```bash
cat > ~/.bash_profile << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF
```
(suite...)
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

Recharger le profile et définir MAKEFLAGS
```bash
source ~/.bash_profile
export MAKEFLAGS='-j$(nproc)'
exec <&-
```

Check de l'environnement
```bash
echo "$LFS"       # /mnt/lfs
echo "$LFS_TGT"   # aarch64-lfs-linux-gnu
echo "$PATH"      # /mnt/lfs/tools/bin:/usr/bin
```

Toujours en root
```bash
export PATH=/usr/sbin:/sbin:$PATH
echo "dash dash/sh boolean false" | debconf-set-selections
DEBIAN_FRONTEND=noninteractive dpkg-reconfigure dash
```
> Pour utiliser bash comme shell par défaut et pas dash (plus limité)

Installation des paquets indispensables
```bash
apt-get update && apt-get upgrade -y
apt-get install -y gawk
apt-get install -y bison
apt-get install -y build-essential
```

Verifier versions outils hôtes
```bash
curl -fsSL http://www.linuxfromscratch.org/lfs/view/stable/chapter02/hostreqs.html \
  | grep -A53 "# Simple script to list version numbers of critical development tools" \
  | sed 's:</code>::g' | sed 's:&gt;:>:g' | sed 's:&lt;:<:g' | sed 's:&amp;:\&:g' \
  | sed 's:failed:not OK:g' > /root/version-check.sh

bash /root/version-check.sh | tee /root/version-check.log
bash /root/version-check.sh | grep -i "not OK" || echo "Tout bon brother"
```

## Création du système temporaire

Repasser en utilisateur LFS (et quelques checks, jsuis parano)
```bash
sudo su - lfs
```

Check de l'environnement
```bash
echo "$LFS"       # doit afficher /mnt/lfs
echo "$LFS_TGT"   # doit afficher aarch64-lfs-linux-gnu
echo "$PATH"      # doit commencer par /mnt/lfs/tools/bin:/usr/bin
```

> Chaque installation qui va suivre peut prendre un moment, va te chercher un autre café

Installation de `binutils`
```bash
cd $LFS/sources
# telecharger script d'install (custom, mais tu peux refaire la meme a partir du tuto dans linuxfromscratch.org, etape 5.2)
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/scripts/00-binutils.sh -o 00-binutils.sh
chmod +x 00-binutils.sh
time ./00-binutils.sh
```
> build > compile > install > check > cleanup

Supprimer le script d'installation
```bash
rm -v $LFS/sources/00-binutils.sh
```

Installation de `gcc`
```bash
cd $LFS/sources
# telecharger script d'install (custom, mais tu peux refaire la meme a partir du tuto dans linuxfromscratch.org, etape 5.3)
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/scripts/01-gcc.sh -o 01-gcc.sh
chmod +x 01-gcc.sh
time ./01-gcc.sh
```
> build > compile > install > check > cleanup

Supprimer le script d'installation
```bash
rm -v $LFS/sources/01-gcc.sh
```

Installation de `linux-headers`
```bash
cd $LFS/sources
# telecharger script d'install (custom, mais tu peux refaire la meme a partir du tuto dans linuxfromscratch.org, etape 5.4)
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/scripts/02-linux_api_headers.sh -o 02-linux_api_headers.sh
chmod +x 02-linux_api_headers.sh
time ./02-linux_api_headers.sh
```

Supprimer le script d'installation
```bash
rm -v $LFS/sources/02-linux_api_headers.sh
```

Installation de `glibc`
```bash
cd $LFS/sources
# telecharger script d'install (custom, mais tu peux refaire la meme a partir du tuto dans linuxfromscratch.org, etape 5.5)
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/scripts/03-glibc.sh -o 03-glibc.sh
chmod +x 03-glibc.sh
time ./03-glibc.sh
```
> build > compile > install > check > cleanup

Supprimer le script d'installation
```bash
rm -v $LFS/sources/03-glibc.sh
```

Installation de `libstdc++`
```bash
cd $LFS/sources
# telecharger script d'install (custom, mais tu peux refaire la meme a partir du tuto dans linuxfromscratch.org, etape 5.6)
curl -fsSL https://raw.githubusercontent.com/aceyzz/ft_linux/refs/heads/main/project/scripts/04-libstdcpp.sh -o 04-libstdcpp.sh
chmod +x 04-libstdcpp.sh
time ./04-libstdcpp.sh
```
> build > compile > install > check > cleanup

Supprimer le script d'installation
```bash
rm -v $LFS/sources/04-libstdcpp.sh
```
