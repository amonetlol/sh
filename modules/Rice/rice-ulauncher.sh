#!/usr/bin/env bash
# rice-ulauncher — temas Catppuccin Frappe (sapphire e blue) + autostart em modo daemon
# O ulauncher inicia junto com o sistema sem exibir janela (ulauncher start = daemon),
# pronto para receber o atalho (ulauncher toggle).
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/rice-ulauncher.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

UL_THEMES_DIR="${HOME}/.config/ulauncher/user-themes"
UL_SETTINGS="${HOME}/.config/ulauncher/settings.json"
AUTOSTART_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/autostart"
AUTOSTART_FILE="${AUTOSTART_DIR}/ulauncher.desktop"

THEME_DEFAULT="Catppuccin-Frappe-Sapphire"
THEME_ALT="Catppuccin-Frappe-Blue"

# ============================================================
# DEPENDÊNCIAS (instale antes se necessário):
#   Arch:   sudo pacman -S ulauncher python (ulauncher já vem nos pacotes do módulo pacotes_arch)
#   Ubuntu: sudo apt install ulauncher python3
#   Fedora: sudo dnf install ulauncher python3
# ============================================================

if ! command -v ulauncher &>/dev/null; then
  warn "ulauncher não encontrado — instalando os temas mesmo assim (aplicam após instalar o ulauncher)."
fi

if ! command -v python3 &>/dev/null; then
  warn "python3 não encontrado — não é possível instalar os temas."
  exit 1
fi

mkdir -p "$UL_THEMES_DIR"

# ---------- Temas Catppuccin ----------
log "Instalando tema Catppuccin Frappe (accent: sapphire)..."
python3 <(curl -fsSL https://raw.githubusercontent.com/catppuccin/ulauncher/main/install.py) -f frappe -a sapphire \
  && ok "Tema instalado: $THEME_DEFAULT" \
  || warn "Falha ao instalar o tema $THEME_DEFAULT"

log "Instalando tema Catppuccin Frappe (accent: blue)..."
python3 <(curl -fsSL https://raw.githubusercontent.com/catppuccin/ulauncher/main/install.py) -f frappe -a blue \
  && ok "Tema instalado: $THEME_ALT" \
  || warn "Falha ao instalar o tema $THEME_ALT"

# ---------- Tema ativo (settings.json) ----------
log "Definindo tema ativo: $THEME_DEFAULT (para usar o $THEME_ALT, mude em Preferences > Appearance)"
if [[ -f "$UL_SETTINGS" ]]; then
  python3 - "$UL_SETTINGS" "$THEME_DEFAULT" <<'PYEOF'
import json
import sys

path, theme = sys.argv[1], sys.argv[2]
with open(path) as f:
    data = json.load(f)
data["theme-name"] = theme
with open(path, "w") as f:
    json.dump(data, f, indent=4, sort_keys=True)
PYEOF
  ok "settings.json atualizado (theme-name: $THEME_DEFAULT)"
else
  printf '{\n    "theme-name": "%s"\n}\n' "$THEME_DEFAULT" > "$UL_SETTINGS"
  ok "settings.json criado (theme-name: $THEME_DEFAULT)"
fi

# ---------- Autostart em modo daemon (sem popup no login) ----------
log "Configurando autostart do ulauncher em modo daemon..."
mkdir -p "$AUTOSTART_DIR"

# Sobrescreve autostart legado (v5 usava ulauncher-toggle, que abre a janela)
cat > "$AUTOSTART_FILE" <<'EOF'
[Desktop Entry]
Type=Application
Name=Ulauncher (daemon)
Comment=Ulauncher em modo daemon — invisível no login, acione pelo atalho
Icon=ulauncher
Exec=ulauncher start
TryExec=ulauncher
Terminal=false
NoDisplay=true
X-GNOME-Autostart-enabled=true
EOF
ok "Autostart criado: $AUTOSTART_FILE (Exec=ulauncher start — daemon sem janela)"

# ---------- Resumo ----------
ok "RICE ULAUNCHER FINALIZADO"
cat <<EOF

Resumo:
  Temas instalados : $THEME_DEFAULT, $THEME_ALT
  Tema ativo       : $THEME_DEFAULT
  Autostart        : daemon (sem popup no login)
  Atalho           : configure em Preferences > Hotkey
                     (o atalho mostra a janela; 'ulauncher toggle' também)

Se o ulauncher estiver rodando, reinicie-o para aplicar o tema:
  pkill -f ulauncher; ulauncher start &
EOF