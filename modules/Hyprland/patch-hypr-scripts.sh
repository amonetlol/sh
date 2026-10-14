#!/usr/bin/env bash
# patch-hypr-scripts — instala scripts (gtkthemes) em ~/.config/hypr e garante exec-once no hyprland.conf
# Standalone: conteúdo do gtkthemes embutido no script.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/patch-hypr-scripts.sh)
set -euo pipefail

CUSTOM_CACHE="${CUSTOM_CACHE:-$HOME/.cache/base-custom-repo}"
GTK_LINE='exec-once = ~/.config/hypr/scripts/gtkthemes'

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }

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

deploy_scripts() {
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

deploy_scripts "$HOME/.config/hypr/scripts"
deploy_scripts "$CUSTOM_CACHE/hypr/scripts"

ensure_gtkthemes_exec "$HOME/.config/hypr/hyprland.conf"
ensure_gtkthemes_exec "$CUSTOM_CACHE/hypr/hyprland.conf"

ok "Hypr scripts e gtkthemes configurados"