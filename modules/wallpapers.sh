#!/usr/bin/env bash
# Wallpapers — copia wallpapers/ do repo para ~/Imagens/wallpapers
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/wallpapers.sh)

set -euo pipefail

DEST="$HOME/Imagens/wallpapers"
WALLS_REPO="${WALLS_REPO_URL:-https://github.com/amonetlol/wall2.git}"

# Piped (bash <(curl ...) ou curl | bash): BASH_SOURCE[0] aponta para /dev/fd/N
# ou não existe — não há cópia local, vai direto para o clone do wall2.
SRC=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" && -r "${BASH_SOURCE[0]}" ]]; then
  SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd)" || SCRIPT_DIR=""
  if [[ -n "$SCRIPT_DIR" && -d "$SCRIPT_DIR/../wallpapers" ]]; then
    SRC="$(cd "$SCRIPT_DIR/../wallpapers" && pwd)"
  fi
fi

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

mkdir -p "$(dirname "$DEST")"

copy_local_wallpapers() {
  if [[ -z "$SRC" || ! -d "$SRC" ]]; then
    return 1
  fi

  local count
  count="$(find "$SRC" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | wc -l)"
  if [[ "$count" -eq 0 ]]; then
    return 1
  fi

  log "Copiando $count wallpaper(s) de $SRC -> $DEST"
  mkdir -p "$DEST"
  cp -a "$SRC/." "$DEST/"
  ok "Wallpapers copiados para $DEST"
  return 0
}

clone_remote_wallpapers() {
  if [[ -d "$DEST/.git" ]]; then
    log "Atualizando wall2 em $DEST"
    git -C "$DEST" pull --ff-only 2>/dev/null || warn "git pull falhou — verifique manualmente"
    ok "Wallpapers em $DEST"
    return 0
  fi

  if [[ -e "$DEST" && ! -d "$DEST/.git" ]]; then
    local backup="${DEST}.bak-$(date +%Y%m%d-%H%M%S)"
    warn "Destino existe — backup para $backup"
    mv "$DEST" "$backup"
  fi

  if ! command -v git >/dev/null 2>&1; then
    warn "git não encontrado — copie wallpapers manualmente para $DEST"
    return 1
  fi

  log "Clonando $WALLS_REPO -> $DEST"
  if GIT_TERMINAL_PROMPT=0 git clone --depth 1 "$WALLS_REPO" "$DEST"; then
    ok "Wallpapers clonados em $DEST"
    return 0
  fi

  warn "Falha ao clonar wall2"
  return 1
}

if copy_local_wallpapers; then
  exit 0
fi

warn "Pasta local wallpapers/ vazia ou ausente — tentando wall2..."
if clone_remote_wallpapers; then
  exit 0
fi

printf "[ERRO] Sem wallpapers: falha no clone de %s\n" "$WALLS_REPO" >&2
exit 1
