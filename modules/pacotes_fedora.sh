#!/usr/bin/env bash
# pacotes_fedora — pacotes essenciais para Fedora
# Equivalente ao pacotes_arch (sem yay-bin e sem herdr-bin): tudo via dnf,
# exceto starship/eza/zoxide/lazygit/tree-sitter-cli/prettier, que não existem
# nos repos do Fedora (vêm de GitHub Releases/npm). Fontes ficam no fonts.sh.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_fedora.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[AVISO] %s\n" "$*" >&2; }
err()  { printf "[ERRO] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# ---------- Fedora / base Fedora ----------
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

# ---------- dnf ----------
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
  if sudo dnf install -y "${missing[@]}"; then
    return 0
  fi
  # um pacote ruim não derruba o grupo — tenta isoladamente
  warn "Falha em algum pacote do grupo '$label' — tentando pacote por pacote..."
  for pkg in "${missing[@]}"; do
    sudo dnf install -y "$pkg" || warn "$pkg não pôde ser instalado — verifique manualmente."
  done
}

log "Sincronizando banco de dados do dnf..."
sudo dnf makecache || warn "makecache falhou — seguindo com o cache atual."

# ---------- Base ----------
log "Garantindo grupo development-tools (base-devel do Fedora)..."
sudo dnf group install -y development-tools \
  || warn "Falha no grupo development-tools — verifique manualmente."

install_group "base" \
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
  procs \
  less

# ---------- Shell / CLI ----------
# starship, eza, zoxide, lazygit e tree-sitter-cli não estão no dnf → extras adiante
install_group "shell/cli (dnf)" \
  fzf \
  ripgrep \
  fd-find \
  bat \
  btop \
  htop \
  tree \
  duf \
  fastfetch \
  tldr

# ---------- Build / dev ----------
install_group "build/dev" \
  gcc \
  make \
  cmake \
  pkgconf-pkg-config \
  jq \
  bc \
  findutils \
  coreutils \
  microcode_ctl

# ---------- Neovim / dev stack ----------
install_group "nvim/dev stack" \
  nodejs \
  npm \
  lua \
  luarocks \
  python3 \
  python3-pip \
  python3-neovim \
  pipenv \
  python3-virtualenv

# ---------- Fontes / sistema / desktop ----------
install_group "fontes/sistema" \
  fontconfig \
  google-noto-fonts \
  google-noto-emoji-fonts \
  hostname \
  telnet \
  mesa

# ---------- Desktop apps ----------
install_group "desktop apps" \
  blackbox-terminal \
  ulauncher

# ---------- Fora do dnf (GitHub Releases / npm) ----------
gh_latest_tag() {
  curl -fsSL "https://api.github.com/repos/$1/releases/latest" \
    | grep -oP '"tag_name":\s*"\K[^"]+' | head -n1
}

install_from_tarball() {
  local name="$1" url="$2" bin="$3"
  if command -v "$bin" &>/dev/null; then
    ok "$name já instalado."
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  log "Baixando $name..."
  if ! curl -fL "$url" -o "$tmp/dl.tar.gz"; then
    warn "$name: falha no download — verifique manualmente."
    rm -rf "$tmp"
    return 0
  fi
  if ! tar -xzf "$tmp/dl.tar.gz" -C "$tmp"; then
    warn "$name: falha ao extrair."
    rm -rf "$tmp"
    return 0
  fi
  local src
  src="$(find "$tmp" -type f -name "$bin" | head -n1)"
  if [[ -z "$src" ]]; then
    warn "$name: binário '$bin' não encontrado no arquivo."
    rm -rf "$tmp"
    return 0
  fi
  sudo install -m 0755 "$src" "/usr/local/bin/$bin"
  rm -rf "$tmp"
  ok "$name instalado em /usr/local/bin/$bin"
}

install_single_gz() {
  # tree-sitter-cli: asset único gzip (tree-sitter-linux-x64.gz)
  local name="$1" url="$2" bin="$3"
  if command -v "$bin" &>/dev/null; then
    ok "$name já instalado."
    return 0
  fi
  local tmp
  tmp="$(mktemp -d)"
  log "Baixando $name..."
  if ! curl -fL "$url" -o "$tmp/dl.gz"; then
    warn "$name: falha no download — verifique manualmente."
    rm -rf "$tmp"
    return 0
  fi
  gunzip -c "$tmp/dl.gz" > "$tmp/$bin"
  sudo install -m 0755 "$tmp/$bin" "/usr/local/bin/$bin"
  rm -rf "$tmp"
  ok "$name instalado em /usr/local/bin/$bin"
}

install_cli_extras() {
  local tag ver

  install_from_tarball "starship" \
    "https://github.com/starship/starship/releases/latest/download/starship-x86_64-unknown-linux-gnu.tar.gz" \
    "starship"

  install_from_tarball "eza" \
    "https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz" \
    "eza"

  tag="$(gh_latest_tag ajeetdsouza/zoxide || true)"
  if [[ -n "${tag:-}" ]]; then
    install_from_tarball "zoxide" \
      "https://github.com/ajeetdsouza/zoxide/releases/download/${tag}/zoxide-${tag}-x86_64-unknown-linux-musl.tar.gz" \
      "zoxide"
  else
    warn "zoxide: não foi possível obter a versão latest — verifique manualmente."
  fi

  tag="$(gh_latest_tag jesseduffield/lazygit || true)"
  if [[ -n "${tag:-}" ]]; then
    ver="${tag#v}"
    install_from_tarball "lazygit" \
      "https://github.com/jesseduffield/lazygit/releases/download/${tag}/lazygit_${ver}_Linux_x86_64.tar.gz" \
      "lazygit"
  else
    warn "lazygit: não foi possível obter a versão latest — verifique manualmente."
  fi

  install_single_gz "tree-sitter-cli" \
    "https://github.com/tree-sitter/tree-sitter/releases/latest/download/tree-sitter-linux-x64.gz" \
    "tree-sitter"

  # prettier não está no dnf — usa npm global
  if command -v prettier &>/dev/null; then
    ok "prettier já instalado."
  elif command -v npm &>/dev/null; then
    log "Instalando prettier via npm..."
    sudo npm install -g prettier || warn "prettier: falha na instalação via npm."
  else
    warn "prettier: npm não disponível — verifique manualmente."
  fi
}

install_cli_extras

ok "pacotes_fedora finalizado"
