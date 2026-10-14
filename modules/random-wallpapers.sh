#!/usr/bin/env bash
# random-wallpapers — instala ~/.bin/random-wallpaper.sh e o timer systemd do usuário
# Standalone: script de wallpaper e units systemd embutidos (a cada 5 minutos via awww).
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/random-wallpapers.sh)
set -euo pipefail

BIN_DIR="${HOME}/.bin"
UNIT_DIR="${XDG_CONFIG_HOME:-${HOME}/.config}/systemd/user"
DEST_SCRIPT="${BIN_DIR}/random-wallpaper.sh"
DEST_SERVICE="${UNIT_DIR}/random-wallpaper.service"
DEST_TIMER="${UNIT_DIR}/random-wallpaper.timer"

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }

mkdir -p "$BIN_DIR" "$UNIT_DIR"

# ---------- script de wallpaper (embutido) ----------
cat > "$DEST_SCRIPT" <<'WALLSCRIPT_EOF'
#!/usr/bin/env bash

WALLPAPER_DIR="$HOME/Imagens/wallpapers"

if ! command -v awww >/dev/null 2>&1; then
    echo "Erro: awww não encontrado no sistema."
    exit 1
fi

if [[ ! -d "$WALLPAPER_DIR" ]]; then
    echo "Erro: pasta não encontrada: $WALLPAPER_DIR"
    exit 1
fi

WALLPAPER="$(
    find "$WALLPAPER_DIR" -type f \( \
        -iname "*.jpg" -o \
        -iname "*.jpeg" -o \
        -iname "*.png" \
    \) | shuf -n 1
)"

if [[ -z "$WALLPAPER" ]]; then
    echo "Erro: nenhuma imagem .jpg, .jpeg ou .png encontrada em $WALLPAPER_DIR"
    exit 1
fi

awww img "$WALLPAPER"

echo "Wallpaper definido:"
echo "$WALLPAPER"
WALLSCRIPT_EOF
sed -i 's/\r$//' "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT"

# ---------- service (embutido) ----------
cat > "$DEST_SERVICE" <<'SERVICE_EOF'
[Unit]
Description=Wallpaper aleatório (awww)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.bin/random-wallpaper.sh
Environment=XDG_RUNTIME_DIR=/run/user/%U
SERVICE_EOF
sed -i 's/\r$//' "$DEST_SERVICE"

# ---------- timer (embutido) ----------
cat > "$DEST_TIMER" <<'TIMER_EOF'
[Unit]
Description=Timer wallpaper aleatório (5 minutos)

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
TIMER_EOF
sed -i 's/\r$//' "$DEST_TIMER"

export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"

systemctl --user daemon-reload

for old in randow-wallpapers.service random-wallpapers.service \
  randow-wallpapers.timer random-wallpapers.timer; do
  systemctl --user disable --now "$old" 2>/dev/null || true
done

systemctl --user enable --now random-wallpaper.timer
systemctl --user start random-wallpaper.service

echo "Instalado: ${DEST_SCRIPT}"
echo "Serviço: ${DEST_SERVICE}"
echo "Timer: ${DEST_TIMER}"
systemctl --user --no-pager --full status random-wallpaper.service || true