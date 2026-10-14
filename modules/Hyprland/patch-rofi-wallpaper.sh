#!/usr/bin/env bash
# patch-rofi-wallpaper — aplica rofi-wallpaper.sh (awww/swww/swaybg) em todos os temas custom
# Standalone: conteúdo do rofi-wallpaper.sh embutido no script.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/patch-rofi-wallpaper.sh)
set -euo pipefail

CUSTOM_CACHE="${CUSTOM_CACHE:-$HOME/.cache/base-custom-repo}"

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }

THEMES=(
  theme-bamboo
  theme-edge
  theme-everforest
  theme-glass
  theme-gruvbox
  theme-orange
  theme-prateado
  theme-sonokai
)

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

patch_dir() {
  local base="$1"
  [[ -d "$base" ]] || return 0
  write_rofi_wallpaper "$base/wallpaper.sh"
  ok "wallpaper.sh → $base"
}

for theme in "${THEMES[@]}"; do
  patch_dir "$CUSTOM_CACHE/custom/$theme/rofi"
  patch_dir "$HOME/.config/custom/$theme/rofi"
done

ok "Rofi wallpaper atualizado em ${#THEMES[@]} temas (awww, swww, swaybg)"