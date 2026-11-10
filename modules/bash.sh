#!/usr/bin/env bash
# bash — instala aliases/funções + .bashrc (starship nord ativo) + ~/.bin
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/bash.sh)
set -euo pipefail

DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"
DOT_CACHE="${DOT_CACHE:-$HOME/.cache/base-dot-repo}"

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

dot_backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local backup="${path}.bak-$(date +%Y%m%d-%H%M%S)"
    log "Backup: $path -> $backup"
    mv "$path" "$backup"
  fi
}

dot_copy_tree() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$src/" "$dest/"
  else
    cp -a "$src/." "$dest/"
  fi
}

dot_ensure_repo() {
  if ! command -v git >/dev/null 2>&1; then
    fail "git não encontrado."
  fi

  if [[ -d "$DOT_CACHE/.git" ]]; then
    log "Atualizando cache dot: $DOT_CACHE"
    git -C "$DOT_CACHE" pull --ff-only 2>/dev/null || warn "git pull falhou — usando cache local"
    return 0
  fi

  mkdir -p "$(dirname "$DOT_CACHE")"
  log "Clonando $DOT_REPO -> $DOT_CACHE"
  git clone --depth 1 "$DOT_REPO" "$DOT_CACHE"
}

dot_install_home_files() {
  local rel_src="$1"
  shift
  local files=("$@")
  local src_dir="$DOT_CACHE/$rel_src"
  local file src dest

  if [[ ! -d "$src_dir" ]]; then
    fail "Origem não encontrada: $src_dir"
  fi

  for file in "${files[@]}"; do
    src="$src_dir/$file"
    dest="$HOME/$file"
    if [[ ! -f "$src" ]]; then
      fail "Arquivo não encontrado: $src"
    fi
    dot_backup_path "$dest"
    cp -a "$src" "$dest"
    # repo dot pode ter fim de linha Windows (CRLF) — converte para LF
    sed -i 's/\r$//' "$dest" 2>/dev/null || true
    ok "Copiado: $dest"
  done
}

dot_install_bin() {
  local src="$DOT_CACHE/dotfiles/bin/.bin"
  local dest="$HOME/.bin"

  if [[ ! -d "$src" ]]; then
    fail "Origem não encontrada: $src"
  fi

  dot_backup_path "$dest"
  mkdir -p "$(dirname "$dest")"
  dot_copy_tree "$src" "$dest"
  # normaliza fim de linha (repo dot pode ter CRLF)
  find "$dest" -type f -exec sed -i 's/\r$//' {} + 2>/dev/null || true
  find "$dest" -type f -exec chmod +x {} + 2>/dev/null || true
  ok "Instalado: $dest ($(find "$dest" -maxdepth 1 -type f | wc -l) scripts)"
}

dot_ensure_repo

# Usa a mesma deteccao carregada pelo .bashrc, antes de instalar os arquivos.
FUNCTIONS_SRC="$DOT_CACHE/dotfiles/bash/.functions"
[[ -f "$FUNCTIONS_SRC" ]] || fail "Arquivo nao encontrado: $FUNCTIONS_SRC"
source <(sed 's/\r$//' "$FUNCTIONS_SRC")
DISTRO="$(detect_distro)"
files=(".bashrc" ".aliases" ".functions" ".bash_profile")
case "$DISTRO" in
  arch|debian|fedora|fedora-silverblue|mocaccino|gentoo|calculate|nixos|opensuse|openmandriva|slackware|salix|solus|void|freebsd|kali|antix|cento_os|calamaro)
    files+=(".aliases-$DISTRO")
    log "Distro detectada: $DISTRO"
    ;;
  rocky)
    files+=(".aliases-distro")
    log "Distro detectada: $DISTRO (aliases genericos .aliases-distro)"
    ;;
  *)
    files+=(".aliases-distro")
    warn "Distro nao reconhecida ($DISTRO); instalando aliases genericos (.aliases-distro)."
    ;;
esac

dot_install_home_files "dotfiles/bash" "${files[@]}"
dot_install_bin
