#!/usr/bin/env bash
# pacotes_fedora — pacotes essenciais para Fedora
# Equivalente ao pacotes_arch.sh / pacotes_ubuntu.sh (sem herdr-bin e yay-bin, exclusivos de Arch/AUR).
# Pacotes ausentes nos repos (eza, procs, lazygit, starship, zoxide, tree-sitter-cli, prettier,
# nerd fonts) são instalados via GitHub releases / npm / sparse clone do repo dot.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_fedora.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[AVISO] %s\n" "$*" >&2; }
err()  { printf "[ERRO] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

BIN_DIR="$HOME/.local/bin"
DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"
GH_API="https://api.github.com/repos"

# ---------- Fedora / base RHEL ----------
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

require_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    die "Não rode este script como root. Use seu usuário normal com sudo."
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
  rpm -q "$1" &>/dev/null
}

is_fedora_based || die "Não é base Fedora — script ignorado."
require_not_root

mkdir -p "$BIN_DIR"

case "$(uname -m)" in
  x86_64)  ARCH="x86_64" ;;
  aarch64) ARCH="aarch64" ;;
  *)       ARCH="" ;;
esac

# Baixa o asset mais recente que casa com o padrão (GitHub latest release)
gh_fetch_latest() {
  local repo="$1" pattern="$2" dest="$3" url
  url="$(curl -fsSL "${GH_API}/${repo}/releases/latest" 2>/dev/null \
    | grep -o "https://[^\"]*${pattern}" | head -n1 || true)"
  if [[ -z "$url" ]]; then
    warn "Asset não encontrado: ${repo} (${pattern})"
    return 1
  fi
  log "Baixando $(basename "$url")..."
  curl -fL "$url" -o "$dest"
}

command_available() {
  command -v "$1" &>/dev/null && return 0
  [[ -x "$BIN_DIR/$1" ]] && return 0
  return 1
}

# ---------- dnf ----------
log "Instalando grupos e pacotes via dnf..."

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
  sudo dnf install -y "${missing[@]}" \
    || warn "Falha em algum pacote do grupo '$label' — verifique manualmente."
}

# ---------- Base (base-devel → gcc/make; procs vai para extras) ----------
install_group "base" \
  gcc \
  gcc-c++ \
  make \
  git \
  wget \
  curl \
  unzip \
  zip \
  p7zip \
  p7zip-plugins \
  tar \
  rsync \
  nano \
  vim \
  neovim \
  bash-completion \
  less \
  wl-clipboard \
  xclip

# ---------- Shell / CLI (eza, starship, zoxide, lazygit, procs vão para extras) ----------
install_group "shell/cli" \
  fd-find \
  ripgrep \
  fzf \
  duf \
  btop \
  htop \
  tree \
  tldr \
  bat

# ---------- Build / dev (snap-pac é exclusivo do Arch) ----------
install_group "build/dev" \
  cmake \
  pkgconf \
  jq \
  bc \
  findutils \
  coreutils

# ---------- Neovim / dev stack (tree-sitter-cli e prettier via npm em extras) ----------
install_group "nvim/dev stack" \
  nodejs \
  npm \
  lua5.1 \
  luarocks \
  python3 \
  python3-pip \
  python3-pynvim \
  pipenv \
  virtualenv

# ---------- Fontes / sistema (nerd fonts via repo dot em extras) ----------
install_group "fontes/sistema" \
  fontconfig \
  google-noto-sans-vf-fonts \
  google-noto-emoji-fonts \
  iputils \
  net-tools \
  mesa-dri-drivers

# ---------- Apps (visualizadores imagem/docs; loupe e papers) ----------
install_group "apps visualizadores" \
  loupe \
  papers

# ---------- Desktop apps (podem não existir nos repos oficiais) ----------
install_group "desktop apps" \
  blackbox-terminal \
  ulauncher \
  xed

# ---------- Extras: ferramentas ausentes nos repos ----------
install_gh_bin() {
  local name="$1" repo="$2" pattern="$3" post="$4"
  if command_available "$name"; then
    ok "$name já instalado."
    return 0
  fi
  if [[ -z "$ARCH" ]]; then
    warn "$name não instalado (arquitetura $(uname -m) não suportada)."
    return 0
  fi
  local tmp tarball
  tmp="$(mktemp -d)"
  tarball="$tmp/dl.tar.gz"
  # shellcheck disable=SC2086
  if gh_fetch_latest "$repo" "$pattern" "$tarball"; then
    log "Extraindo $name -> $BIN_DIR"
    mkdir -p "$tmp/out"
    tar -xzf "$tarball" -C "$tmp/out"
    if [[ -n "$post" ]]; then
      cp "$tmp/out/$post" "$BIN_DIR/$name"
    else
      cp "$tmp/out/$name" "$BIN_DIR/$name"
    fi
    chmod +x "$BIN_DIR/$name"
    ok "$name instalado em $BIN_DIR/$name"
  fi
  rm -rf "$tmp"
}

# starship (tentativa dnf → instalador oficial)
if command_available starship; then
  ok "starship já instalado."
elif pkg_installed starship; then
  ok "starship já instalado."
else
  log "Instalando starship em $BIN_DIR..."
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" \
    && ok "starship instalado." \
    || warn "Falha ao instalar starship."
fi

# zoxide (tentativa dnf → instalador oficial)
if command_available zoxide; then
  ok "zoxide já instalado."
else
  log "Instalando zoxide em $BIN_DIR..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- -b "$BIN_DIR" \
    && ok "zoxide instalado." \
    || warn "Falha ao instalar zoxide."
fi

# eza (GitHub release: eza_x86_64-unknown-linux-gnu.tar.gz)
if command_available eza; then
  ok "eza já instalado."
elif [[ -n "$ARCH" ]]; then
  tmp="$(mktemp -d)"
  if gh_fetch_latest "eza-community/eza" "eza_${ARCH}-unknown-linux-gnu.tar.gz" "$tmp/eza.tar.gz"; then
    tar -xzf "$tmp/eza.tar.gz" -C "$tmp"
    cp "$tmp/eza" "$BIN_DIR/eza" 2>/dev/null \
      || find "$tmp" -name eza -type f -exec cp {} "$BIN_DIR/eza" \;
    chmod +x "$BIN_DIR/eza"
    ok "eza instalado em $BIN_DIR/eza"
  fi
  rm -rf "$tmp"
fi

# procs (procs-v*-x86_64-linux.zip) — usa unzip
if command_available procs; then
  ok "procs já instalado."
elif [[ -n "$ARCH" ]]; then
  tmp="$(mktemp -d)"
  if gh_fetch_latest "dalance/procs" "procs-v.*-${ARCH}-linux.zip" "$tmp/procs.zip"; then
    unzip -oq "$tmp/procs.zip" -d "$tmp"
    cp "$tmp/procs" "$BIN_DIR/procs"
    chmod +x "$BIN_DIR/procs"
    ok "procs instalado em $BIN_DIR/procs"
  fi
  rm -rf "$tmp"
fi

# lazygit (lazygit_*_Linux_x86_64.tar.gz)
if command_available lazygit; then
  ok "lazygit já instalado."
else
  install_gh_bin "lazygit" "jesseduffield/lazygit" "lazygit_.*_Linux_${ARCH}.tar.gz" "lazygit"
fi

# fastfetch (tentativa dnf → GitHub release)
if command_available fastfetch; then
  ok "fastfetch já instalado."
elif pkg_installed fastfetch; then
  ok "fastfetch já instalado."
elif [[ -n "$ARCH" ]]; then
  install_gh_bin "fastfetch" "fastfetch-cli/fastfetch" "fastfetch-linux-${ARCH}.tar.gz" "fastfetch"
fi

# tree-sitter-cli e prettier (npm global, não existem nos repos)
if command -v npm &>/dev/null; then
  if command_available tree-sitter || npm ls -g tree-sitter-cli &>/dev/null; then
    ok "tree-sitter-cli já instalado."
  else
    log "Instalando tree-sitter-cli via npm..."
    sudo npm install -g tree-sitter-cli \
      && ok "tree-sitter-cli instalado." \
      || warn "Falha ao instalar tree-sitter-cli (npm)."
  fi
  if npm ls -g prettier &>/dev/null; then
    ok "prettier já instalado."
  else
    log "Instalando prettier via npm..."
    sudo npm install -g prettier \
      && ok "prettier instalado." \
      || warn "Falha ao instalar prettier (npm)."
  fi
else
  warn "npm ausente — tree-sitter-cli e prettier não instalados."
fi

# Nerd fonts (0xProto, Geist, Terminus) via sparse clone do repo dot → ~/.fonts
if ! ls "$HOME/.fonts"/*0xProto* "$HOME/.fonts"/*Geist* "$HOME/.fonts"/*Terminus* &>/dev/null; then
  if command -v git &>/dev/null; then
    tmp="$(mktemp -d)"
    log "Clonando fontes nerd do repo dot (sparse, pode demorar)..."
    if git clone --depth=1 --filter=blob:none --sparse "$DOT_REPO" "$tmp/dot" 2>/dev/null \
      && git -C "$tmp/dot" sparse-checkout set dotfiles/fonts/.fonts \
      && [[ -d "$tmp/dot/dotfiles/fonts/.fonts" ]]; then
      mkdir -p "$HOME/.fonts"
      cp -a "$tmp/dot/dotfiles/fonts/.fonts/." "$HOME/.fonts/"
      ok "Nerd fonts -> ~/.fonts"
    else
      warn "Falha ao clonar fontes do repo dot."
    fi
    rm -rf "$tmp"
  else
    warn "git ausente — nerd fonts não instaladas."
  fi
else
  ok "Nerd fonts já presentes em ~/.fonts."
fi

# ---------- fontconfig ----------
if fc-cache -fv "$HOME/.fonts" &>/dev/null || fc-cache -fv &>/dev/null; then
  ok "fontconfig atualizado"
fi

ok "pacotes_fedora finalizado"