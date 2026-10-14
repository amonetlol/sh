#!/usr/bin/env bash
# rice-base-kde — rice para KDE Plasma (Arch / base Arch como CachyOS)
#
# Configs aplicadas:
#   Cores              : nordic-bluish (EliverLara/Nordic)
#   Estilo do app      : breeze
#   Estilo do plasma   : Layan (vinceliuice/Layan-kde)
#   Decoração janela   : Layan (aurorae, via Layan-kde)
#   Ícones             : MacTahoe-nord (vinceliuice/MacTahoe-icon-theme -t nord)
#   Ponteiros          : Oxygen_Zion (pacote oxygen — KDE4 Oxygen)
#   Tela de apresentação: CachyOS-Nord (CachyOS/CachyOS-Nord-KDE, splash)
#
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/rice-base-kde.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
die()  { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

SRC_ROOT="${HOME}/.local/src/rice-kde"
LOOKFEEL_DIR="$HOME/.local/share/plasma/look-and-feel"
SCHEMES_DIR="$HOME/.local/share/color-schemes"
ICONS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/icons"

# sudo com suporte a INSTALL_SUDO_PASSWORD / SUDO_ASKPASS
sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    if [[ "$1" == "-S" || "$1" == "-A" || "$1" == "-n" || "$1" == "-v" ]]; then
      command sudo "$@"
    else
      command sudo -H "$@"
    fi
    return $?
  fi
  if [[ -n "${INSTALL_SUDO_PASSWORD:-}" ]]; then
    printf '%s\n' "$INSTALL_SUDO_PASSWORD" | command sudo -S "$@"
  elif [[ -n "${SUDO_ASKPASS:-}" ]]; then
    export DISPLAY="${DISPLAY:-:0}"
    command sudo -A "$@"
  else
    command sudo "$@"
  fi
}

is_arch_based() {
  [[ -f /etc/arch-release ]] && return 0
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*)
        return 0
        ;;
    esac
  fi
  return 1
}

require_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "Execute como usuário normal, não como root (temas vão para ~/.local)."
  fi
}

is_arch_based || die "Não é base Arch — script ignorado."
require_not_root

# ---------- Ferramentas KDE ----------
if command -v kwriteconfig6 &>/dev/null; then
  KW="kwriteconfig6"
elif command -v kwriteconfig5 &>/dev/null; then
  KW="kwriteconfig5"
else
  die "kwriteconfig6/kwriteconfig5 não encontrado — Plasma KDE necessário."
fi

# kw file group key value
kw_set() {
  "$KW" --file "$1" --group "$2" --key "$3" "$4"
}

clone_or_update() {
  local url="$1" dest="$2"
  mkdir -p "$(dirname "$dest")"
  if [[ -d "${dest}/.git" ]]; then
    log "Atualizando $(basename "$dest") (git pull --ff-only)"
    git -C "$dest" pull --ff-only || warn "git pull falhou — usando clone local"
  elif [[ -e "$dest" ]]; then
    die "Existe $dest mas não é um repositório git. Remova essa pasta e rode de novo."
  else
    log "Clonando $(basename "$dest")"
    git clone "$url" "$dest"
  fi
}

# ---------- Dependências ----------
log "Instalando dependências (git, oxygen)..."
sudo pacman -Sy --needed --noconfirm git oxygen || warn "Falha no pacman — continuando"

# oxygen: contém os cursores KDE4 (Oxygen_White, Oxygen_Zion, ...)
if [[ -d "/usr/share/icons/Oxygen_Zion" ]]; then
  ok "Cursor Oxygen_Zion disponível (pacote oxygen)."
else
  warn "Oxygen_Zion não encontrado em /usr/share/icons — o pacote oxygen instalou? Aplicando mesmo assim."
fi

# ---------- Download dos temas ----------
clone_or_update "https://github.com/vinceliuice/Layan-kde.git" "${SRC_ROOT}/Layan-kde"
clone_or_update "https://github.com/EliverLara/Nordic.git" "${SRC_ROOT}/Nordic"
clone_or_update "https://github.com/vinceliuice/MacTahoe-icon-theme.git" "${SRC_ROOT}/MacTahoe-icon-theme"
clone_or_update "https://github.com/CachyOS/CachyOS-Nord-KDE.git" "${SRC_ROOT}/CachyOS-Nord-KDE"

# ---------- Instalação ----------
log "Instalando Layan-kde (plasma style, aurorae, kvantum, lookandfeel)..."
(
  cd "${SRC_ROOT}/Layan-kde"
  ./install.sh
) || warn "install.sh do Layan-kde falhou — verifique manualmente"

log "Instalando cores nordic-bluish (Nordic)..."
mkdir -p "$SCHEMES_DIR"
cp -f "${SRC_ROOT}/Nordic/kde/colorschemes/nordicbluish.colors" "$SCHEMES_DIR/nordic-bluish.colors"
# Plasma 5 usa extensão .colorscheme
cp -f "${SRC_ROOT}/Nordic/kde/colorschemes/nordicbluish.colors" "$SCHEMES_DIR/nordic-bluish.colorscheme"
ok "Esquema de cores: nordic-bluish"

log "Instalando ícones MacTahoe-nord..."
(
  cd "${SRC_ROOT}/MacTahoe-icon-theme"
  ./install.sh -t nord
) || warn "install.sh do MacTahoe falhou — verifique manualmente"

log "Instalando splash CachyOS-Nord..."
mkdir -p "$LOOKFEEL_DIR"
rm -rf "${LOOKFEEL_DIR}/com.cachyos.ddh4r4m.nord"
cp -a "${SRC_ROOT}/CachyOS-Nord-KDE/plasma/look-and-feel/CachyOS-Nord" \
  "${LOOKFEEL_DIR}/com.cachyos.ddh4r4m.nord"
ok "Look-and-feel do splash instalado: com.cachyos.ddh4r4m.nord"

# ---------- Aplicação ----------
log "Aplicando configurações do KDE..."

# Cores: nordic-bluish
if command -v plasma-apply-colorscheme &>/dev/null; then
  plasma-apply-colorscheme nordic-bluish 2>/dev/null \
    && ok "Cores aplicadas: nordic-bluish" \
    || { kw_set kdeglobals General ColorScheme nordic-bluish; ok "Cores configuradas via kdeglobals."; }
else
  kw_set kdeglobals General ColorScheme nordic-bluish
  ok "Cores configuradas via kdeglobals."
fi

# Estilo do aplicativo: breeze
kw_set kdeglobals KDE widgetStyle breeze
ok "Estilo do aplicativo: breeze"

# Estilo do plasma: Layan
if command -v plasma-apply-desktoptheme &>/dev/null; then
  plasma-apply-desktoptheme Layan 2>/dev/null \
    && ok "Estilo do plasma aplicado: Layan" \
    || { kw_set plasmarc Theme name Layan; ok "Estilo do plasma configurado via plasmarc."; }
else
  kw_set plasmarc Theme name Layan
  ok "Estilo do plasma configurado via plasmarc."
fi

# Decoração da janela: Layan (aurorae)
if command -v plasma-apply-windowdecoration &>/dev/null; then
  plasma-apply-windowdecoration Layan 2>/dev/null \
    && ok "Decoração da janela aplicada: Layan" \
    || {
      kw_set kwinrc org.kde.kdecoration2 library org.kde.breeze
      kw_set kwinrc org.kde.kdecoration2 theme __aurorae__svg__Layan
      ok "Decoração da janela configurada via kwinrc."
    }
else
  kw_set kwinrc org.kde.kdecoration2 library org.kde.breeze
  kw_set kwinrc org.kde.kdecoration2 theme __aurorae__svg__Layan
  ok "Decoração da janela configurada via kwinrc."
fi

# Ícones: MacTahoe-nord
kw_set kdeglobals Icons Theme MacTahoe-nord
ok "Ícones: MacTahoe-nord"

# Ponteiros: Oxygen_Zion
if command -v plasma-apply-cursortheme &>/dev/null; then
  plasma-apply-cursortheme Oxygen_Zion 2>/dev/null \
    && ok "Ponteiros aplicados: Oxygen_Zion" \
    || { kw_set kcminputrc Mouse cursorTheme Oxygen_Zion; ok "Ponteiros configurados via kcminputrc."; }
else
  kw_set kcminputrc Mouse cursorTheme Oxygen_Zion
  ok "Ponteiros configurados via kcminputrc."
fi

# Tela de apresentação: CachyOS-Nord (splash)
kw_set ksplashrc KSplash Engine KSplashQML
kw_set ksplashrc KSplash Theme com.cachyos.ddh4r4m.nord
ok "Tela de apresentação: CachyOS-Nord (com.cachyos.ddh4r4m.nord)"

# Recarrega decoração do KWin
if command -v qdbus &>/dev/null; then
  qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
elif command -v qdbus6 &>/dev/null; then
  qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
fi

ok "RICE KDE FINALIZADO — deslogue/logue para ver splash e cursor em todas as telas"
cat <<EOF

Resumo:
  Cores               : nordic-bluish
  Estilo do aplicativo: breeze
  Estilo do plasma    : Layan
  Decoração da janela : Layan (aurorae)
  Ícones              : MacTahoe-nord
  Ponteiros           : Oxygen_Zion
  Splash              : CachyOS-Nord

Fontes em: ${SRC_ROOT}
EOF