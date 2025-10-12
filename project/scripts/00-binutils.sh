#!/bin/bash
set -euo pipefail

# ---- UI ----
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RESET='\033[0m'
info(){ echo -e "${YELLOW}[INFO]${RESET} $*"; }
ok(){   echo -e "${GREEN}[OK]${RESET}   $*"; }
err(){  echo -e "${RED}[ERROR]${RESET} $*"; }

# ---- Garde-fous ----
[ "${LFS:-}" ] || { err "LFS variable not set"; exit 1; }
[ "${LFS_TGT:-}" ] || { err "LFS_TGT variable not set"; exit 1; }
case ":${PATH}:" in
  *:"$LFS/tools/bin":* ) : ;;
  * ) info "PATH ne commence pas par $LFS/tools/bin (ok, mais recommandé)";;
esac
if [ "$(id -u)" = "0" ]; then
  err "Ne PAS lancer en root. Utilise 'sudo su - lfs'."
  exit 1
fi

PKG=binutils-2.45
SRC_DIR="$LFS/sources"
BUILD_DIR="$SRC_DIR/$PKG/build"

cd "$SRC_DIR"

# ---- Déballage propre ----
rm -rf "$PKG" 2>/dev/null || true
tar -xf "$PKG.tar.xz"
cd "$PKG"
mkdir -v build
cd build

# ---- Configure / Build / Install ----
info "Configure $PKG (pass 1)"
../configure \
  --prefix="$LFS/tools" \
  --with-sysroot="$LFS" \
  --target="$LFS_TGT"   \
  --disable-nls         \
  --disable-werror

info "Compile $PKG"
make -j"$(nproc)"

info "Install $PKG"
make install

# ---- Vérifs essentielles ----
AS_BIN="$LFS/tools/bin/${LFS_TGT}-as"
LD_BIN="$LFS/tools/bin/${LFS_TGT}-ld"

[ -x "$AS_BIN" ] || { err "as introuvable: $AS_BIN"; exit 1; }
[ -x "$LD_BIN" ] || { err "ld introuvable: $LD_BIN"; exit 1; }

"$AS_BIN" --version | head -n1
"$LD_BIN" --version | head -n1

ok "Binutils (pass 1) installé avec succès."

# ---- Nettoyage (laisser les sources intactes si tu préfères) ----
cd "$SRC_DIR"
rm -rf "$PKG"

ok "Nettoyage terminé."
