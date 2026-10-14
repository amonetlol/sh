#!/usr/bin/env bash
# fonts — fontes via pacman (Arch) + fontes do repo amonetlol/dot → ~/.fonts
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/fonts.sh)
set -euo pipefail

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"

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

install_pacman_fonts() {
  sudo pacman -S --needed --noconfirm ttf-0xproto-nerd otf-geist-mono-nerd ttf-terminus-nerd fontconfig
  ok "ttf-0xproto-nerd + otf-geist-mono-nerd"
}

install_dot_repo_fonts() {
  if ! command -v git >/dev/null 2>&1; then
    warn "git não encontrado — fontes do repo dot ignoradas"
    return 0
  fi

  local tmp
  tmp="$(mktemp -d)"
  log "Clonando fontes do repo dot (sparse, pode demorar)..."
  if ! git clone --depth=1 --filter=blob:none --sparse "$DOT_REPO" "$tmp/dot" 2>/dev/null; then
    warn "Falha ao clonar $DOT_REPO — fontes dot ignoradas"
    rm -rf "$tmp"
    return 0
  fi
  git -C "$tmp/dot" sparse-checkout set dotfiles/fonts/.fonts

  local src="$tmp/dot/dotfiles/fonts/.fonts"
  if [[ ! -d "$src" ]]; then
    log "dotfiles/fonts/.fonts ausente no repositório dot"
    rm -rf "$tmp"
    return 0
  fi

  mkdir -p "$HOME/.fonts"
  cp -a "$src/." "$HOME/.fonts/"
  ok "dot → ~/.fonts ($(find "$HOME/.fonts" -type f | wc -l) ficheiros)"
  rm -rf "$tmp"
}

if is_arch_based; then
  install_pacman_fonts
  install_dot_repo_fonts
elif is_fedora_based || is_ubuntu_based; then
  log "Base $( (is_fedora_based && echo fedora) || echo ubuntu ) — pacman ignorado, usando fontes dot."
  install_dot_repo_fonts
else
  log "Base desconhecida — usando fontes dot."
  install_dot_repo_fonts
fi

fc-cache -fv "$HOME/.fonts" 2>/dev/null || fc-cache -fv
ok "fontconfig atualizado"