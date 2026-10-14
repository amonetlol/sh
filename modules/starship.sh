#!/usr/bin/env bash
# starship — instala o binário e as configs starship do repo amonetlol/dot
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/starship.sh)
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

if ! command -v starship >/dev/null 2>&1; then
  log "Instalando starship em ~/.local/bin..."
  mkdir -p "$HOME/.local/bin"
  curl -fsSL https://starship.rs/install.sh | sh -s -- -y -b "$HOME/.local/bin"
  ok "starship instalado em $HOME/.local/bin/starship"
else
  ok "starship já instalado: $(command -v starship)"
fi

dot_ensure_repo
src="$DOT_CACHE/dotfiles/starship/.config"
if [[ ! -d "$src" ]]; then
  fail "Origem não encontrada: $src"
fi

mkdir -p "$HOME/.config"
for file in "$src"/*; do
  [[ -f "$file" ]] || continue
  dest="$HOME/.config/$(basename "$file")"
  dot_backup_path "$dest"
  cp -a "$file" "$dest"
  ok "Copiado: $dest"
done