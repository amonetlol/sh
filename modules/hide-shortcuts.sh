#!/usr/bin/env bash
# Hide noisy .desktop entries from rofi (vendored from amonetlol/dot 07-hide_shortcuts.sh)
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/hide-shortcuts.sh)

# set -euo pipefail  # desativado: atalho em falta não deve interromper o script
# set -uo pipefail

APP_DIR_SYSTEM="/usr/share/applications"
APP_DIR_LOCAL="$HOME/.local/share/applications"

log() { printf "\n[ROFI APPS] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

mkdir -p "$APP_DIR_LOCAL"

set_nodisplay_true() {
  local file="$1"
  sed -i '/^NoDisplay=/d' "$file"
  if grep -q '^\[Desktop Action' "$file"; then
    sed -i '/^\[Desktop Action/i NoDisplay=true' "$file"
  else
    sed -i '/^\[Desktop Entry\]/a NoDisplay=true' "$file"
  fi
}

hide_desktop_by_name() {
  local wanted_name="$1"
  local found=0
  while IFS= read -r desktop_file; do
    local filename local_file
    filename="$(basename "$desktop_file")"
    local_file="$APP_DIR_LOCAL/$filename"
    if [[ "$(readlink -f "$desktop_file")" != "$(readlink -f "$local_file")" ]]; then
      cp "$desktop_file" "$local_file"
    else
      ok "Já está em local: $filename"
    fi
    set_nodisplay_true "$local_file"
    ok "Ocultado: $wanted_name -> $filename"
    found=1
  done < <(grep -rilE "^Name(\[[^]]+\])?=${wanted_name}$" "$APP_DIR_SYSTEM" "$APP_DIR_LOCAL" 2>/dev/null || true)
  [[ "$found" -eq 0 ]] && warn "Não encontrado: $wanted_name"
}

hide_desktop_by_filename() {
  local filename="$1"
  local system_file="$APP_DIR_SYSTEM/$filename"
  local local_file="$APP_DIR_LOCAL/$filename"
  if [[ -f "$system_file" ]]; then
    cp "$system_file" "$local_file"
  elif [[ -f "$local_file" ]]; then
    :
  else
    warn "Não encontrado por arquivo: $filename"
    return
  fi
  set_nodisplay_true "$local_file"
  ok "Ocultado: $filename"
}

rename_desktop_by_name() {
  local old_name="$1" new_name="$2" found=0
  while IFS= read -r desktop_file; do
    local filename local_file
    filename="$(basename "$desktop_file")"
    local_file="$APP_DIR_LOCAL/$filename"
    if [[ "$(readlink -f "$desktop_file")" != "$(readlink -f "$local_file")" ]]; then
      cp "$desktop_file" "$local_file"
    else
      ok "Já está em local: $filename"
    fi
    if grep -q '^Name=' "$local_file"; then
      sed -i "s/^Name=.*/Name=${new_name}/" "$local_file"
    else
      printf '\nName=%s\n' "$new_name" >>"$local_file"
    fi
    sed -i '/^Name\[pt_BR\]=/d' "$local_file"
    sed -i '/^Name\[pt\]=/d' "$local_file"
    ok "Renomeado: $old_name -> $new_name"
    found=1
  done < <(grep -rilE "^Name(\[[^]]+\])?=${old_name}$" "$APP_DIR_SYSTEM" "$APP_DIR_LOCAL" 2>/dev/null || true)
  [[ "$found" -eq 0 ]] && warn "Não encontrado para renomear: $old_name"
}

log "Ocultando atalhos indesejados"
for name in btop "foot client" "foot server" "Hardware Locality lstopo" \
  "Navegador de servidores SSH do avahi" "Navegador de servidores VNC do avahi" \
  "Navegador Zeroconf do avahi" Neovim "Preferências do Thunar" \
  "Qt V4L2 vídeo capture utility" Rofi "Rofi Theme Selector" Vim xgps xgpsspeed \
  "Utilitário de teste V4L2" Micro Alacritty "Qt6 Settings" "Qt5 Settings" \
  "SchedExt GUI Manager" "Sobre o Xfce" Htop CMake "Btrfs Assistant" "CachyOS Hello" \
  "Qt Widgets Designer" "Qt Linguist" "Qt D-Bus Viewer" "Qt Assistant"; do
  hide_desktop_by_name "$name"
done

for f in btop.desktop footclient.desktop foot-server.desktop avahi-discover.desktop \
  bvnc.desktop bssh.desktop nvim.desktop vim.desktop rofi.desktop rofi-theme-selector.desktop \
  micro.desktop Alacritty.desktop alacritty.desktop lstopo.desktop qv4l2.desktop qvidcap.desktop \
  xgps.desktop xgpsspeed.desktop thunar-settings.desktop qt6ct.desktop qt5ct.desktop \
  org.cachyos.scx-manager.desktop xfce4-about.desktop htop.desktop cmake-gui.desktop \
  btrfs-assistant.desktop cachyos-hello.desktop designer.desktop linguist.desktop \
  qdbusviewer.desktop assistant.desktop; do
  hide_desktop_by_filename "$f"
done

log "Renomeando Thunar"
rename_desktop_by_name "Gerenciador de Arquivos Thunar" "Thunar"
rename_desktop_by_name "Thunar File Manager" "Thunar"

if [[ -f "$APP_DIR_SYSTEM/thunar.desktop" ]]; then
  if [[ "$(readlink -f "$APP_DIR_SYSTEM/thunar.desktop")" != "$(readlink -f "$APP_DIR_LOCAL/thunar.desktop")" ]]; then
    cp "$APP_DIR_SYSTEM/thunar.desktop" "$APP_DIR_LOCAL/thunar.desktop"
  else
    ok "Thunar já presente em local"
  fi
  if grep -q '^Name=' "$APP_DIR_LOCAL/thunar.desktop"; then
    sed -i 's/^Name=.*/Name=Thunar/' "$APP_DIR_LOCAL/thunar.desktop"
  else
    printf '\nName=Thunar\n' >>"$APP_DIR_LOCAL/thunar.desktop"
  fi
  sed -i '/^Name\[pt_BR\]=/d' "$APP_DIR_LOCAL/thunar.desktop"
  sed -i '/^Name\[pt\]=/d' "$APP_DIR_LOCAL/thunar.desktop"
  ok "Thunar ajustado via thunar.desktop"
fi

log "Atualizando cache de atalhos"
update-desktop-database "$APP_DIR_LOCAL" 2>/dev/null || true
ok "Atalhos ajustados."
