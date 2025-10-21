<img title="42_ft-linux" alt="42_ft-linux" src="./utils/banner.png" width="100%">

<br>

# `ft_linux` - Linux from scratch

Créer une distribution Linux minimale et fonctionnelle from scratch  

## Table des matières

- [Présentation du projet](#présentation-du-projet)
- [Objectifs réalisés](#objectifs-réalisés)
- [Méthodologie](#méthodologie)
- [Packages installés](#packages-installés)
- [Structure finale](#structure-finale)
- [Conformité et résultats](#conformité-et-résultats)
- [Références](#références)
- [Statut du projet](#statut-du-projet)

<br>

## Présentation du projet

Le projet **ft_linux** est une spécialisation du cursus 42 visant à construire, à partir de zéro, une distribution Linux complète et fonctionnelle.  
L’objectif est d’obtenir un système minimaliste, stable et conforme aux standards FHS, capable de compiler, démarrer et se connecter à Internet.  
Cette distribution servira ensuite de base pour tous les futurs projets liés au noyau Linux (kernel hacking, drivers, etc.).

Mon implémentation repose sur le livre officiel **Linux From Scratch – ARM64 r12.4-15** (liens [ici](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/)), publié le 5 septembre 2025.  
Toutes les étapes du livre ont été suivies à la lettre, de la création des partitions jusqu’au premier démarrage du système final.

<br>

## Objectifs réalisés

Le système construit respecte l’ensemble des exigences du sujet officiel `ft_linux v3.4` :  
- Compilation complète du **noyau Linux 6.16.1** (suffixé `-cedmulle`) depuis les sources.  
- Configuration du **bootloader GRUB 2.12** pour un démarrage UEFI.  
- Mise en place de **trois partitions** distinctes : `/boot`, `/`, et `swap`.  
- Implémentation du **module loader `udev`** pour la gestion dynamique des périphériques.  
- Utilisation de **SysVinit** pour la gestion des services système.  
- Hostname configuré en `cedmulle`.  
- Hiérarchie des répertoires conforme au standard **FHS 3.0**.  
- Connexion Internet opérationnelle depuis l’environnement final.  

Le projet a été réalisé dans une **machine virtuelle ARM64** (UTM / Ubuntu 22.04 hôte) avec un disque virtuel partitionné et monté manuellement selon la structure LFS.

<br>

## Méthodologie

Le système a été entièrement bâti manuellement, sans gestionnaire de paquets ni outils automatisés.  
Chaque package a été compilé à partir de ses sources manuellement, conformément aux instructions du livre LFS.  
Le processus s’est articulé en quatre grandes étapes :

1. **Préparation de l’environnement hôte et du disque**  
   Création des partitions `/boot`, `/`, `swap`, définition de `$LFS` et montage des systèmes virtuels (`proc`, `sysfs`, `devpts`...).

2. **Construction de la toolchain croisée**  
   Compilation de Binutils, GCC et Glibc dans un environnement isolé afin de générer les outils nécessaires à la construction du système autonome.

3. **Construction du système temporaire puis du système final**  
   Compilation des outils utilisateurs, bibliothèques et utilitaires système (bash, coreutils, gcc, util-linux, etc.).

4. **Configuration et installation du noyau**  
   Compilation du kernel 6.16.1, installation du bootloader GRUB, création de `/etc/fstab`, configuration réseau et finalisation de l’environnement de démarrage.

<br>

## Packages installés

<details>
<summary>Packages obligatoires</summary>

```plaintext
Acl  
Attr  
Autoconf  
Automake  
Bash  
Bc  
Binutils  
Bison  
Bzip2  
Check  
Coreutils  
DejaGNU  
Diffutils  
Eudev  
E2fsprogs  
Expat  
Expect  
File  
Findutils  
Flex  
Gawk  
GCC  
GDBM  
Gettext  
Glibc  
GMP  
Gperf  
Grep  
Groff  
GRUB  
Gzip  
Iana-Etc  
Inetutils  
Intltool  
IPRoute2  
Kbd  
Kmod  
Less  
Libcap  
Libpipeline  
Libtool  
M4  
Make  
Man-DB  
Man-pages  
MPC  
MPFR  
Ncurses  
Patch  
Perl  
Pkg-config  
Procps  
Psmisc  
Readline  
Sed  
Shadow  
Sysklogd  
Sysvinit  
Tar  
Tcl  
Texinfo  
Time Zone Data  
Udev-lfs Tarball  
Util-linux  
Vim  
XML::Parser  
Xz Utils  
Zlib  
```

</details>

<details>
<summary>Dépendances</summary>

```plaintext
Iana-Etc  
Lz4  
Zstd  
Pcre2  
Pkgconf  
Libxcrypt  
OpenSSL  
Libelf from Elfutils  
Libffi  
Sqlite  
Python  
Flit-Core  
Packaging  
Wheel  
Setuptools  
Ninja  
Meson  
MarkupSafe  
Jinja2  
Procps-ng  
```

</details>

<details>
<summary>Ajouts customs</summary>

```plaintext
wget  
curl  
ssh  
sudo  
git  
valgrind  
gdb  
rsync  
net-tools  
which  
fcron  
lynx  
ohmybash  
```

</details>

<br>

## Structure finale

- `/boot` – Contient le noyau `vmlinuz-6.16.1-cedmulle` et la configuration GRUB  
- `/usr/src/kernel-6.16.1` – Sources du noyau Linux  
- `/etc` – Fichiers de configuration système  
- `/dev`, `/proc`, `/sys`, `/run` – Systèmes de fichiers virtuels montés  
- `/home`, `/var`, `/tmp`, `/usr`, `/lib`, `/bin`, `/sbin` – Arborescence standard conforme au FHS  

<br>

## Conformité et résultats

Le système démarre correctement via GRUB, initialise tous les services via SysVinit, détecte les périphériques via `udev`, et permet la connexion Internet.  
Le noyau a été compilé et installé selon les conventions demandées :
```
/boot/vmlinuz-6.16.1-cedmulle
/usr/src/kernel-6.16.1
```

Les symboles de débogage ont été supprimés pour alléger le système, conformément à la section 8.86 du livre LFS.  
L’ensemble des tests critiques (Glibc, GCC, Coreutils, etc.) ont été exécutés et validés dans le chroot.

<br>

## Références

- **Sujet officiel** - [ft_linux v3.4](./utils/subject.pdf)  
- **Tutoriel utilisé** - [Linux From Scratch ARM64 r12.4-15](https://www.linuxfromscratch.org/~xry111/lfs/view/arm64/)  
- **Standard FHS** - [Filesystem Hierarchy Standard 3.0](http://refspecs.linuxfoundation.org/FHS_3.0/fhs/index.html)  

<br>

## Statut du projet

Le projet est terminé pour la partie obligatoire.  
Aucune fonctionnalité graphique ni composant bonus n’a été ajoutée à ce stade.  
Une feuille de route détaillée du processus est en cours [ici](./doc/README.md).  
A voir si je décide de custom un peu + à l'avenir

<br>

## Grade 

> En cours d'évaluation