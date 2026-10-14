#!/usr/bin/env bash
# Remove local overrides that hide Alacritty and Kitty from rofi.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/recovery-shortcuts.sh)

# set -euo pipefail  # desativado: atalho em falta não deve interromper o script

APP_DIR_LOCAL="$HOME/.local/share/applications"

log() { printf "\n[ROFI APPS] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

remove_local_desktop() {
  local filename="$1"
  local local_file="$APP_DIR_LOCAL/$filename"
  if [[ -f "$local_file" ]]; then
    rm -f -- "$local_file"
    ok "Removido: $filename"
  else
    warn "Não encontrado em local: $filename"
  fi
}

log "Restaurando atalhos ocultos"
for f in alacritty.desktop Alacritty.desktop kitty.desktop; do
  remove_local_desktop "$f"
done

log "Atualizando cache de atalhos"
update-desktop-database "$APP_DIR_LOCAL" 2>/dev/null || true
ok "Atalhos restaurados."
