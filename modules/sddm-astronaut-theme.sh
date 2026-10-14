#!/usr/bin/env bash
# sddm-astronaut-theme — tema SDDM Astronaut (Keyitdev)
# Arch/base Arch: instala via AUR (sddm-astronaut-theme).
# Outras distros: instala manual a partir de https://github.com/Keyitdev/sddm-astronaut-theme
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/sddm-astronaut-theme.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[AVISO] %s\n" "$*" >&2; }
err()  { printf "[ERRO] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

THEME_NAME="sddm-astronaut-theme"
THEME_URL="https://github.com/Keyitdev/sddm-astronaut-theme.git"
THEME_DIR="/usr/share/sddm/themes/$THEME_NAME"

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

# Grava ficheiro em path root sem heredoc+tee (sudo -S consome stdin).
sudo_write_file() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  sudo mkdir -p "$(dirname "$dest")"
  sudo cp "$tmp" "$dest"
  rm -f "$tmp"
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

is_fedora_based() {
  [[ -f /etc/fedora-release ]] && return 0
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      fedora*|*:fedora*|rhel*|centos*|rocky*|alma*)
        return 0
        ;;
    esac
  fi
  return 1
}

is_ubuntu_based() {
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      ubuntu*|debian*|pop*|linuxmint*|zorin*|elementary*|*:ubuntu*|*:debian*)
        return 0
        ;;
    esac
  fi
  [[ -f /etc/debian_version ]] && return 0
  return 1
}

disable_other_dms() {
  for dm in lightdm gdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      log "Desativando $dm..."
      sudo systemctl disable --now "$dm" 2>/dev/null || sudo systemctl disable "$dm" || true
    fi
  done
}

configure_sddm() {
  sudo_write_file /etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=$THEME_NAME
EOF
  sudo chmod a+r /etc/sddm.conf.d/theme.conf
  # teclado virtual do tema (Qt6 VirtualKeyboard)
  sudo_write_file /etc/sddm.conf.d/virtualkbd.conf <<'EOF'
[General]
InputMethod=qtvirtualkeyboard
EOF
  sudo chmod a+r /etc/sddm.conf.d/virtualkbd.conf
  # Garantir que não há Current conflitante no sddm.conf principal
  if grep -q '^Current=' /etc/sddm.conf 2>/dev/null; then
    sudo sed -i 's/^Current=.*/Current='"$THEME_NAME"'/' /etc/sddm.conf
  fi
}

enable_sddm() {
  if systemctl is-enabled sddm &>/dev/null; then
    ok "sddm já habilitado."
  else
    sudo systemctl enable sddm || warn "Não foi possível habilitar sddm — verifique manualmente."
  fi
}

# ---------- Arch / base Arch: AUR ----------
install_arch() {
  local HELPER=""
  if command -v yay &>/dev/null; then
    HELPER="yay"
    ok "AUR helper encontrado: yay"
  elif command -v paru &>/dev/null; then
    HELPER="paru"
    ok "AUR helper encontrado: paru"
  else
    log "Nenhum AUR helper encontrado — compilando yay-bin em /tmp/yay..."
    sudo pacman -Sy --needed --noconfirm base-devel git

    local YAY_BUILD="/tmp/yay"
    rm -rf "$YAY_BUILD"
    mkdir -p "$YAY_BUILD"
    git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$YAY_BUILD/yay-bin" \
      || die "Falha ao clonar yay-bin do AUR."
    (
      cd "$YAY_BUILD/yay-bin"
      makepkg -si --noconfirm --needed
    ) || die "Falha ao compilar/instalar yay-bin."
    rm -rf "$YAY_BUILD"
    ok "yay-bin instalado — pasta $YAY_BUILD removida"
    command -v yay &>/dev/null || die "yay não disponível após a instalação."
    HELPER="yay"
  fi

  log "Instalando $THEME_NAME do AUR..."
  "$HELPER" -S --needed --noconfirm --answerdiff None --answerclean None "$THEME_NAME" \
    || die "Falha ao instalar $THEME_NAME via AUR."
}

# ---------- Outras distros: install manual ----------
install_other() {
  # dependências por família (README Keyitdev/sddm-astronaut-theme)
  local pkgs=()
  if is_fedora_based; then
    pkgs=(sddm qt6-qtsvg qt6-qtvirtualkeyboard qt6-qtmultimedia git)
    log "Instalando dependências via dnf..."
    sudo dnf install -y "${pkgs[@]}" || warn "Falha em alguma dependência — verifique manualmente."
  elif is_ubuntu_based; then
    pkgs=(sddm qt6-svg-dev qml6-module-qtquick-virtualkeyboard qt6-multimedia-dev \
      qml6-module-qtquick-controls qml6-module-qtquick-effects libxcb-cursor0 git)
    log "Instalando dependências via apt..."
    DEBIAN_FRONTEND=noninteractive sudo apt-get install -y "${pkgs[@]}" \
      || warn "Falha em alguma dependência — verifique manualmente."
  elif command -v zypper &>/dev/null; then
    pkgs=(sddm-qt6 libQt6Svg6 qt6-virtualkeyboard qt6-virtualkeyboard-imports \
      qt6-multimedia qt6-multimedia-imports git)
    log "Instalando dependências via zypper..."
    sudo zypper --non-interactive install "${pkgs[@]}" \
      || warn "Falha em alguma dependência — verifique manualmente."
  elif command -v xbps-install &>/dev/null; then
    pkgs=(sddm qt6-svg qt6-virtualkeyboard qt6-multimedia git)
    log "Instalando dependências via xbps..."
    sudo xbps-install -Sy "${pkgs[@]}" \
      || warn "Falha em alguma dependência — verifique manualmente."
  else
    die "Distro não suportada — veja https://github.com/Keyitdev/sddm-astronaut-theme"
  fi

  # clona o tema (backup se já existir)
  if [[ -d "$THEME_DIR" ]]; then
    local backup
    backup="${THEME_DIR}.bak-$(date +%Y%m%d%H%M%S)"
    log "Tema existente — backup em $backup..."
    sudo mv "$THEME_DIR" "$backup"
  fi
  sudo git clone -b master --depth 1 "$THEME_URL" "$THEME_DIR" \
    || die "Falha ao clonar $THEME_URL."
  sudo chmod -R a+rX "$THEME_DIR"

  # fontes do tema
  sudo cp -r "$THEME_DIR/Fonts/." /usr/share/fonts/
  fc-cache -f >/dev/null 2>&1 || true
  ok "Fontes do tema copiadas para /usr/share/fonts/"
}

if is_arch_based; then
  install_arch
else
  install_other
fi

disable_other_dms
configure_sddm
enable_sddm

ok "SDDM tema $THEME_NAME instalado e configurado"
