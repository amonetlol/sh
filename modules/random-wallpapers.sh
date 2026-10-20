#!/usr/bin/env bash
# random-wallpapers — instala ~/.bin/random-wallpaper.sh e o timer systemd do usuário
# Standalone: script de wallpaper e units systemd embutidos (a cada 5 minutos).
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
set -euo pipefail

wallpaper_dir="$HOME/Imagens/wallpapers"
[[ -d "$wallpaper_dir" ]] || exit 0
wallpaper=$(find "$wallpaper_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)
[[ -n "$wallpaper" ]] || exit 0

de="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-}}"

set_wayland_wallpaper() {
  if [[ -z "${WAYLAND_DISPLAY:-}" ]]; then
    echo "random-wallpaper: WAYLAND_DISPLAY nao definido" >&2
    return 1
  fi
  if ! command -v awww >/dev/null 2>&1; then
    echo "Erro: awww nao encontrado no sistema." >&2
    return 1
  fi
  awww img "$wallpaper"
}

set_x11_wallpaper() {
  if [[ -z "${DISPLAY:-}" ]]; then
    echo "random-wallpaper: DISPLAY nao definido" >&2
    return 1
  fi
  if ! command -v feh >/dev/null 2>&1; then
    echo "Erro: feh nao encontrado no sistema." >&2
    return 1
  fi
  feh --no-fehbg --no-xinerama --bg-fill "$wallpaper"
}

de=$(printf '%s' "$de" | tr '[:upper:]' '[:lower:]')
case "$de" in
  *gnome*)
    uri=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$wallpaper")
    gsettings set org.gnome.desktop.background picture-uri "$uri"
    gsettings set org.gnome.desktop.background picture-uri-dark "$uri" 2>/dev/null || true
    ;;
  *kde*|*plasma*)
    if command -v plasma-apply-wallpaperimage >/dev/null 2>&1; then
      plasma-apply-wallpaperimage "$wallpaper"
    else
      exit 0
    fi
    ;;
  *qtile*|*x11*)
    set_x11_wallpaper
    ;;
  *niri*|*hyprland*|*wayland*|*sway*)
    set_wayland_wallpaper
    ;;
  *)
    if [[ -n "${WAYLAND_DISPLAY:-}" ]]; then
      set_wayland_wallpaper
    elif [[ -n "${DISPLAY:-}" ]]; then
      set_x11_wallpaper
    else
      exit 0
    fi
    ;;
esac
WALLSCRIPT_EOF
sed -i 's/\r$//' "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT"

# ---------- service (embutido) ----------
cat > "$DEST_SERVICE" <<'SERVICE_EOF'
[Unit]
Description=Wallpaper aleatório (DE atual)
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

for name in DISPLAY XAUTHORITY WAYLAND_DISPLAY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE; do
  value=$(printenv "$name" 2>/dev/null || true)
  if [[ -n "$value" ]]; then
    systemctl --user import-environment "$name"
  fi
done

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