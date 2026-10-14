#!/usr/bin/env bash
# hypr-temas — clone amonetlol/custom e executa install.sh + install_hypr.sh + patches
# Standalone: patches de gtkthemes e rofi-wallpaper embutidos (mesmos do patch-hypr-scripts.sh e patch-rofi-wallpaper.sh).
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/hypr-temas.sh)
set -euo pipefail

CUSTOM_REPO="${CUSTOM_REPO:-https://github.com/amonetlol/custom.git}"
CUSTOM_CACHE="${CUSTOM_CACHE:-$HOME/.cache/base-custom-repo}"
GTK_LINE='exec-once = ~/.config/hypr/scripts/gtkthemes'

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

if ! command -v git >/dev/null 2>&1; then
  fail "git não encontrado."
fi

if [[ -d "$CUSTOM_CACHE/.git" ]]; then
  log "Atualizando cache custom: $CUSTOM_CACHE"
  git -C "$CUSTOM_CACHE" pull --ff-only 2>/dev/null || log "git pull falhou — usando cache local"
else
  mkdir -p "$(dirname "$CUSTOM_CACHE")"
  log "Clonando $CUSTOM_REPO -> $CUSTOM_CACHE"
  git clone --depth 1 "$CUSTOM_REPO" "$CUSTOM_CACHE"
fi

# ---------- gtkthemes (embutido) ----------
write_gtkthemes() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'GTKTHEMES_EOF'
#!/usr/bin/env bash
# GTK / icons / cursor / font defaults

THEME='catppuccin-frappe-blue'
ICONS='MacTahoe-dark'
FONT='0xProto Nerd Font Propo 12'
CURSOR='Qogir-cursors'

SCHEMA='gsettings set org.gnome.desktop.interface'

theme_ready() {
  [[ -d "$HOME/.themes/$THEME" || -d "/usr/share/themes/$THEME" ]]
}

icons_ready() {
  [[ -d "$HOME/.icons/$ICONS" || -d "/usr/share/icons/$ICONS" ]]
}

cursor_ready() {
  [[ -d "$HOME/.icons/$CURSOR" || -d "/usr/share/icons/$CURSOR" ]]
}

apply_themes() {
  if theme_ready; then
    ${SCHEMA} gtk-theme "$THEME"
  else
    echo "[gtkthemes] Tema GTK ausente: $THEME — rode o módulo Rice" >&2
  fi

  if icons_ready; then
    ${SCHEMA} icon-theme "$ICONS"
  else
    echo "[gtkthemes] Ícones ausentes: $ICONS — rode o módulo Rice" >&2
  fi

  if cursor_ready; then
    ${SCHEMA} cursor-theme "$CURSOR"
  else
    echo "[gtkthemes] Cursor ausente: $CURSOR — rode o módulo Rice" >&2
  fi

  ${SCHEMA} font-name "$FONT"
}

apply_themes
GTKTHEMES_EOF
  chmod +x "$dest"
}

patch_hypr_scripts() {
  local dest="$1"
  write_gtkthemes "$dest/gtkthemes"
  ok "scripts → $dest"
}

ensure_gtkthemes_exec() {
  local conf="$1"
  [[ -f "$conf" ]] || return 0

  if grep -qF 'scripts/gtkthemes' "$conf"; then
    ok "exec-once gtkthemes já em $conf"
    return 0
  fi

  if grep -q '^### AUTOSTART ###' "$conf"; then
    sed -i "/^### AUTOSTART ###/a $GTK_LINE" "$conf"
  else
    printf '\n%s\n%s\n' '#################' '### AUTOSTART ###' >>"$conf"
    printf '%s\n' "$GTK_LINE" >>"$conf"
  fi
  ok "exec-once gtkthemes adicionado em $conf"
}

# ---------- rofi-wallpaper (embutido) ----------
write_rofi_wallpaper() {
  local dest="$1"
  mkdir -p "$(dirname "$dest")"
  cat > "$dest" <<'ROFIWALL_EOF'
#!/usr/bin/env bash
# Rofi wallpaper picker — backends: awww, swww, swaybg
set -euo pipefail

ROFI_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WALLPAPER_DIR="$HOME/Imagens/wallpapers"
THEME="$ROFI_DIR/wallpaper.rasi"

apply_wallpaper() {
  local wp="$1"

  if command -v awww >/dev/null 2>&1; then
    awww img "$wp" --transition-type grow --transition-fps 60
    return 0
  fi

  if command -v swww >/dev/null 2>&1; then
    if ! pgrep -x swww-daemon >/dev/null 2>&1; then
      swww-daemon &
      sleep 0.3
    fi
    swww img "$wp" --transition-type grow --transition-fps 60 2>/dev/null || \
      swww img "$wp" --resize crop
    return 0
  fi

  if command -v swaybg >/dev/null 2>&1; then
    pkill -x swaybg 2>/dev/null || true
    nohup swaybg -i "$wp" -m fill >/dev/null 2>&1 &
    return 0
  fi

  return 1
}

[[ -d "$WALLPAPER_DIR" ]] || { notify-send "Wallpaper" "Pasta não encontrada: $WALLPAPER_DIR"; exit 1; }

mapfile -t files < <(
  find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) \
    -printf '%f\n' 2>/dev/null | sort -V
)

# macOS/BSD find não tem -printf
if [[ ${#files[@]} -eq 0 ]]; then
  while IFS= read -r f; do
    files+=("$(basename "$f")")
  done < <(find "$WALLPAPER_DIR" -maxdepth 1 -type f \
    \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | sort -V)
fi

if [[ ${#files[@]} -eq 0 ]]; then
  notify-send "Wallpaper" "Nenhuma imagem em $WALLPAPER_DIR"
  exit 1
fi

selected="$(
  {
    for f in "${files[@]}"; do
      printf '%s\0icon\x1f%s\n' "$f" "$WALLPAPER_DIR/$f"
    done
  } | rofi -dmenu -i -theme "$THEME"
)"

[[ -z "$selected" ]] && exit 0

if [[ -f "$selected" ]]; then
  wp="$selected"
elif [[ -f "$WALLPAPER_DIR/$selected" ]]; then
  wp="$WALLPAPER_DIR/$selected"
else
  notify-send "Wallpaper" "Arquivo não encontrado: $selected"
  exit 1
fi

if ! apply_wallpaper "$wp"; then
  notify-send -u low "Wallpaper" "Nenhum backend encontrado (awww, swww, swaybg)"
  exit 1
fi

notify-send -u low "Wallpaper" "Aplicado: $(basename "$wp")" 2>/dev/null || true
ROFIWALL_EOF
  chmod +x "$dest"
}

patch_rofi_wallpaper() {
  local theme base
  local themes=(
    theme-bamboo
    theme-edge
    theme-everforest
    theme-glass
    theme-gruvbox
    theme-orange
    theme-prateado
    theme-sonokai
  )
  for theme in "${themes[@]}"; do
    base="$CUSTOM_CACHE/custom/$theme/rofi"
    [[ -d "$base" ]] || continue
    write_rofi_wallpaper "$base/wallpaper.sh"
    ok "wallpaper.sh → $base"
    base="$HOME/.config/custom/$theme/rofi"
    [[ -d "$base" ]] || continue
    write_rofi_wallpaper "$base/wallpaper.sh"
    ok "wallpaper.sh → $base"
  done
}

log "Executando install.sh"
bash "$CUSTOM_CACHE/install.sh"

log "Instalando scripts Hypr (gtkthemes)"
patch_hypr_scripts "$HOME/.config/hypr/scripts"
patch_hypr_scripts "$CUSTOM_CACHE/hypr/scripts"
ensure_gtkthemes_exec "$HOME/.config/hypr/hyprland.conf"
ensure_gtkthemes_exec "$CUSTOM_CACHE/hypr/hyprland.conf"

log "Executando install_hypr.sh"
bash "$CUSTOM_CACHE/install_hypr.sh"

log "Reaplicando scripts Hypr"
patch_hypr_scripts "$HOME/.config/hypr/scripts"
patch_hypr_scripts "$CUSTOM_CACHE/hypr/scripts"
ensure_gtkthemes_exec "$HOME/.config/hypr/hyprland.conf"
ensure_gtkthemes_exec "$CUSTOM_CACHE/hypr/hyprland.conf"

log "Aplicando rofi wallpaper (awww, swww, swaybg)"
patch_rofi_wallpaper

[[ -d "$HOME/.config/hypr" ]] || fail "Hypr não instalado em ~/.config/hypr"
ok "Hypr + temas instalados em ~/.config/hypr e ~/.config/custom"