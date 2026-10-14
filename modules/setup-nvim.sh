#!/usr/bin/env bash
# Neovim: clone direto de amonetlol/nvim → ~/.config/nvim e /root/.config/nvim
# (sem matugen / theme engine). Instala para o usuário atual E para o root.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/setup-nvim.sh)
set -euo pipefail

NVIM_REPO="https://github.com/amonetlol/nvim.git"

log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

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

# Instala/atualiza o clone do nvim para um config base (ex.: $HOME/.config ou /root/.config)
# $1 = prefixo de comando opcional ("" para o usuário, "sudo" para o root)
# $2 = config base (XDG_CONFIG_HOME do alvo)
install_nvim_for() {
  local prefix="$1"
  local config_base="$2"
  local nvim_dir="${config_base}/nvim"
  local themes_dir="${config_base}/themes/nvim"

  # Legado: symlink ~/.config/nvim → ~/.config/themes/nvim
  if $prefix test -L "$nvim_dir"; then
    log "Removendo symlink legado $nvim_dir"
    $prefix rm -f "$nvim_dir"
  fi

  if $prefix test -d "$themes_dir"; then
    log "Removendo $themes_dir (legado theme engine)"
    $prefix rm -rf "$themes_dir"
  fi

  if $prefix test -e "$nvim_dir" && ! $prefix test -d "$nvim_dir/.git"; then
    warn "$nvim_dir existe mas não é um clone git — movendo para ${nvim_dir}.bak"
    $prefix mv "$nvim_dir" "${nvim_dir}.bak"
  fi

  if $prefix test -d "$nvim_dir/.git"; then
    log "Atualizando $nvim_dir"
    $prefix git -C "$nvim_dir" pull --ff-only 2>/dev/null \
      || warn "git pull falhou — verifique manualmente"
  else
    log "Clonando $NVIM_REPO → $nvim_dir"
    $prefix rm -rf "$nvim_dir"
    $prefix git clone --depth=1 "$NVIM_REPO" "$nvim_dir"
  fi

  ok "nvim em $nvim_dir"
}

# ---------- Usuário atual ----------
install_nvim_for "" "${XDG_CONFIG_HOME:-$HOME/.config}"

# ---------- Root (apenas se não somos root) ----------
if [[ "${EUID}" -eq 0 ]]; then
  ok "Rodando como root — instalação do root já coberta."
elif sudo test -d /root 2>/dev/null; then
  log "Instalando também para root (/root/.config/nvim)..."
  install_nvim_for "sudo" "/root/.config"
else
  warn "Diretório /root inacessível via sudo — instalação para root ignorada."
fi

# Instala os pacotes apenas se for Arch-based
if is_arch_based; then
  if command -v yay >/dev/null 2>&1; then
    yay -S --needed --noconfirm \
      nodejs npm \
      lua51 luarocks \
      python python-pip python-pynvim python-pipenv python-virtualenv \
      tree-sitter-cli prettier \
      || warn "Falha ao instalar pacotes com yay (verifique manualmente)"
  else
    warn "yay não encontrado — instale os pacotes manualmente se necessário"
  fi
fi

ok "setup-nvim finalizado — rode :Lazy sync na primeira abertura"