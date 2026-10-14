#!/usr/bin/env bash
# kitty — instala config kitty a partir do repo amonetlol/dot
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/kitty.sh)
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

dot_install_config() {
  local rel_src="$1"
  local dest="$2"
  local src="$DOT_CACHE/$rel_src"

  dot_ensure_repo

  if [[ ! -d "$src" ]]; then
    fail "Origem não encontrada: $src"
  fi

  dot_backup_path "$dest"
  mkdir -p "$dest"
  dot_copy_tree "$src" "$dest"
  ok "Instalado: $dest ($(find "$dest" -type f | wc -l) ficheiros)"
}

dot_install_config "dotfiles/kitty/.config/kitty" "$HOME/.config/kitty"