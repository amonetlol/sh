#!/usr/bin/env bash
# pacotes_ubuntu — pacotes essenciais para Ubuntu / base Debian
# Equivalente ao pacotes_arch.sh (Arch). Sem herdr-bin e yay-bin (exclusivos de Arch/AUR).
# Pacotes não presentes no apt (starship, zoxide, eza, procs, lazygit, fastfetch, nerd fonts)
# são instalados via GitHub releases / npm / sparse clone do repo dot.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_ubuntu.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[AVISO] %s\n" "$*" >&2; }
err()  { printf "[ERRO] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

BIN_DIR="$HOME/.local/bin"
DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"
GH_API="https://api.github.com/repos"

# ---------- Ubuntu / base Debian ----------
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
  dpkg -s "$1" &>/dev/null
}

is_ubuntu_based || die "Não é base Ubuntu/Debian — script ignorado."
require_not_root

mkdir -p "$BIN_DIR"

case "$(uname -m)" in
  x86_64)  ARCH="x86_64"; DEB_ARCH="amd64" ;;
  aarch64) ARCH="aarch64"; DEB_ARCH="aarch64" ;;
  *)       ARCH=""; DEB_ARCH="" ;;
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

# ---------- apt ----------
log "Atualizando lista de pacotes (apt-get update)..."
sudo apt-get update -qq

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
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y "${missing[@]}" \
    || warn "Falha em algum pacote do grupo '$label' — verifique manualmente."
}

# ---------- Base (base-devel → build-essential; procs vai para extras) ----------
install_group "base" \
  build-essential \
  git \
  wget \
  curl \
  unzip \
  zip \
  p7zip-full \
  tar \
  rsync \
  nano \
  vim \
  neovim \
  bash-completion \
  less \
  wl-clipboard \
  xclip

# ---------- Shell / CLI (eza, fastfetch, starship, zoxide, lazygit vão para extras) ----------
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

# ---------- Build / dev (snap-pac é exclusivo do Arch → snapper) ----------
install_group "build/dev" \
  pkg-config \
  jq \
  bc \
  findutils \
  coreutils \
  snapper \
  intel-microcode

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

# ---------- Fontes / sistema / desktop (nerd fonts via repo dot em extras) ----------
install_group "fontes/sistema" \
  fontconfig \
  fonts-noto-core \
  fonts-noto-color-emoji \
  iputils-ping \
  net-tools \
  mesa

# ---------- Apps (visualizadores imagem/docs + editor; Ubuntu 24.04+) ----------
install_group "apps visualizadores/editor" \
  loupe \
  papers \
  xed

# ---------- Desktop apps (apt → fallback) ----------
log "Instalando apps de desktop (blackbox-terminal, ulauncher)..."
if pkg_installed blackbox || [[ -x "$BIN_DIR/blackbox" ]]; then
  ok "blackbox-terminal já instalado."
else
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y blackbox-terminal 2>/dev/null \
    || warn "blackbox-terminal indisponível no apt — instale via flatpak (com.raggesilver.BlackBox) ou build manual."
fi
if pkg_installed ulauncher; then
  ok "ulauncher já instalado."
else
  DEBIAN_FRONTEND=noninteractive sudo apt-get install -y ulauncher 2>/dev/null || true
  if ! pkg_installed ulauncher; then
    if [[ -n "$DEB_ARCH" ]]; then
      tmpdeb="$(mktemp -d)"
      if gh_fetch_latest "Ulauncher/Ulauncher" "ulauncher_.*\.deb" "$tmpdeb/ulauncher.deb"; then
        sudo apt-get install -y "$tmpdeb/ulauncher.deb" 2>/dev/null \
          && ok "ulauncher instalado via GitHub release." \
          || warn "Falha ao instalar o .deb do ulauncher — use o PPA ppa:agornostal/ulauncher."
      fi
      rm -rf "$tmpdeb"
    else
      warn "ulauncher não instalado (arquitetura não suportada)."
    fi
  fi
fi

# ---------- Extras: ferramentas ausentes no apt ----------
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

# starship (instalador oficial)
if command_available starship; then
  ok "starship já instalado."
else
  log "Instalando starship em $BIN_DIR..."
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$BIN_DIR" \
    && ok "starship instalado." \
    || warn "Falha ao instalar starship."
fi

# zoxide (instalador oficial)
if command_available zoxide; then
  ok "zoxide já instalado."
else
  log "Instalando zoxide em $BIN_DIR..."
  curl -sSfL https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | sh -s -- -b "$BIN_DIR" \
    && ok "zoxide instalado." \
    || warn "Falha ao instalar zoxide."
fi

# eza (GitHub release: eza_x86_64-unknown-linux-gnu.tar.gz / eza_aarch64-unknown-linux-gnu.tar.gz)
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
elif [[ -n "$ARCH" ]] && command -v unzip &>/dev/null; then
  tmp="$(mktemp -d)"
  if gh_fetch_latest "dalance/procs" "procs-v.*-${ARCH}-linux.zip" "$tmp/procs.zip"; then
    unzip -oq "$tmp/procs.zip" -d "$tmp"
    cp "$tmp/procs" "$BIN_DIR/procs"
    chmod +x "$BIN_DIR/procs"
    ok "procs instalado em $BIN_DIR/procs"
  fi
  rm -rf "$tmp"
elif [[ -n "$ARCH" ]]; then
  warn "procs não instalado — unzip indisponível."
fi

# lazygit (lazygit_*_Linux_x86_64.tar.gz)
if command_available lazygit; then
  ok "lazygit já instalado."
else
  install_gh_bin "lazygit" "jesseduffield/lazygit" "lazygit_.*_Linux_${ARCH}.tar.gz" "lazygit"
fi

# fastfetch (deb do GitHub release: fastfetch-linux-amd64.deb)
if command_available fastfetch; then
  ok "fastfetch já instalado."
elif pkg_installed fastfetch; then
  ok "fastfetch já instalado."
elif [[ -n "$DEB_ARCH" ]]; then
  tmpdeb="$(mktemp -d)"
  if gh_fetch_latest "fastfetch-cli/fastfetch" "fastfetch-linux-${DEB_ARCH}\.deb" "$tmpdeb/fastfetch.deb"; then
    sudo apt-get install -y "$tmpdeb/fastfetch.deb" 2>/dev/null \
      && ok "fastfetch instalado via GitHub release." \
      || warn "Falha ao instalar o .deb do fastfetch."
  fi
  rm -rf "$tmpdeb"
else
  warn "fastfetch não instalado (arquitetura não suportada)."
fi

# tree-sitter-cli e prettier (npm global, não existem no apt)
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
if [[ ! -d "$HOME/.fonts/0xProto" ]] && ! ls "$HOME/.fonts"/*0xProto* "$HOME/.fonts"/*Geist* "$HOME/.fonts"/*Terminus* &>/dev/null; then
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

# ---------- Aliases de binários (fdfind→fd, batcat→bat) ----------
if [[ -x "$(command -v fdfind 2>/dev/null || true)" ]] && [[ ! -e "$BIN_DIR/fd" ]]; then
  ln -sf "$(command -v fdfind)" "$BIN_DIR/fd"
  ok "Alias criado: fd -> fdfind"
fi
if command -v batcat &>/dev/null && [[ ! -e "$BIN_DIR/bat" ]]; then
  ln -sf "$(command -v batcat)" "$BIN_DIR/bat"
  ok "Alias criado: bat -> batcat"
fi

# ---------- fontconfig ----------
if fc-cache -fv "$HOME/.fonts" &>/dev/null || fc-cache -fv &>/dev/null; then
  ok "fontconfig atualizado"
fi

ok "pacotes_ubuntu finalizado"