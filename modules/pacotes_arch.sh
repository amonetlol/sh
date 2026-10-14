#!/usr/bin/env bash
# pacotes_arch — pacotes essenciais para Arch / base Arch (CachyOS, Manjaro, EndeavourOS, Garuda)
# Verifica yay ou paru; se não houver, compila e instala yay-bin em /tmp/yay e remove a pasta depois.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_arch.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[AVISO] %s\n" "$*" >&2; }
err()  { printf "[ERRO] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ---------- Arch / base Arch ----------
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
    die "Não rode este script como root — makepkg não permite root. Use seu usuário normal com sudo."
  fi
}

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

pkg_installed() {
  pacman -Q "$1" &>/dev/null
}

is_arch_based || die "Não é base Arch — script ignorado."
require_not_root

# ---------- yay ou paru ----------
HELPER=""
if command -v yay &>/dev/null; then
  HELPER="yay"
  ok "AUR helper encontrado: yay"
elif command -v paru &>/dev/null; then
  HELPER="paru"
  ok "AUR helper encontrado: paru"
else
  log "Nenhum AUR helper encontrado — compilando yay-bin em /tmp/yay..."

  # base-devel e git são necessários para compilar o yay-bin
  log "Garantindo base-devel e git..."
  sudo pacman -Sy --needed --noconfirm base-devel git

  YAY_BUILD="/tmp/yay"
  rm -rf "$YAY_BUILD"
  mkdir -p "$YAY_BUILD"

  if ! git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$YAY_BUILD/yay-bin"; then
    die "Falha ao clonar yay-bin do AUR."
  fi

  log "Compilando e instalando yay-bin (makepkg)..."
  (
    cd "$YAY_BUILD/yay-bin"
    makepkg -si --noconfirm --needed
  ) || die "Falha ao compilar/instalar yay-bin."

  rm -rf "$YAY_BUILD"
  ok "yay-bin instalado — pasta $YAY_BUILD removida"

  command -v yay &>/dev/null || die "yay não disponível após a instalação."
  HELPER="yay"
fi

HELPER_CMD=("$HELPER" -S --needed --noconfirm --answerdiff None --answerclean None)

install_group() {
  local label="$1"
  shift
  local missing=()
  local pkg
  for pkg in "$@"; do
    if pkg_installed "$pkg"; then
      ok "$pkg já instalado."
    else
      missing+=("$pkg")
    fi
  done
  if [[ ${#missing[@]} -eq 0 ]]; then
    ok "$label — nada a fazer."
    return 0
  fi
  log "Instalando ($label): ${missing[*]}"
  "${HELPER_CMD[@]}" "${missing[@]}" \
    || warn "Falha em algum pacote do grupo '$label' — verifique manualmente."
}

log "Sincronizando banco de dados do pacman..."
sudo pacman -Sy --noconfirm

# ---------- Base ----------
install_group "base" \
  base-devel \
  git \
  wget \
  curl \
  unzip \
  zip \
  p7zip \
  tar \
  rsync \
  nano \
  vim \
  neovim \
  bash-completion \
  procs \
  less

# ---------- Shell / CLI ----------
install_group "shell/cli" \
  starship \
  zoxide \
  eza \
  fd \
  ripgrep \
  fzf \
  duf \
  fastfetch \
  btop \
  htop \
  tree \
  tldr \
  lazygit \
  bat

# ---------- Build / dev ----------
install_group "build/dev" \
  gcc \
  make \
  cmake \
  pkgconf \
  jq \
  bc \
  findutils \
  coreutils \
  intel-ucode \
  snap-pac

# ---------- Neovim / dev stack ----------
install_group "nvim/dev stack" \
  nodejs \
  npm \
  lua51 \
  luarocks \
  python \
  python-pip \
  python-pynvim \
  python-pipenv \
  tree-sitter-cli \
  python-virtualenv \
  prettier

# ---------- Fontes / sistema / desktop ----------
install_group "fontes/sistema" \
  fontconfig \
  noto-fonts \
  noto-fonts-emoji \
  inetutils \
  mesa \
  ttf-geist \
  ttf-geist-mono \
  otf-geist-mono-nerd \
  ttf-0xproto-nerd \
  ttf-terminus-nerd

# ---------- Desktop apps ----------
install_group "desktop apps" \
  blackbox-terminal \
  ulauncher \
  herdr-bin

ok "pacotes_arch finalizado (helper: $HELPER)"