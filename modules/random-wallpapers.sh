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

# O timer pode sobreviver a trocas de sessao; leia o ambiente do login ativo.
session_env=$(python3 - <<'PY_SESSION'
import os, pathlib, shlex, subprocess
uid = str(os.getuid())
def run(*args):
    return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL)
sessions = []
for line in run("loginctl", "list-sessions", "--no-legend", "--no-pager").splitlines():
    sid = line.split()[0]
    try:
        props = dict(item.split("=", 1) for item in run(
            "loginctl", "show-session", sid,
            "-p", "User", "-p", "Active", "-p", "Type", "-p", "Desktop", "-p", "Scope"
        ).splitlines() if "=" in item)
    except subprocess.CalledProcessError:
        continue
    if props.get("User") == uid and props.get("Active") == "yes" and props.get("Type") in ("wayland", "x11"):
        sessions.append((sid, props))
if not sessions:
    print("available=no")
    raise SystemExit
sid, props = sessions[0]
candidates = []
keys = ("DISPLAY", "WAYLAND_DISPLAY", "XAUTHORITY", "DBUS_SESSION_BUS_ADDRESS",
        "XDG_CURRENT_DESKTOP", "XDG_SESSION_DESKTOP", "XDG_RUNTIME_DIR")
for proc in pathlib.Path("/proc").iterdir():
    if not proc.name.isdigit():
        continue
    try:
        if str(proc.stat().st_uid) != uid:
            continue
        env = dict(item.split("=", 1) for item in (proc / "environ").read_bytes().decode(
            errors="surrogateescape").split("\0") if "=" in item)
        scope = props.get("Scope", "")
        same_session = env.get("XDG_SESSION_ID") == sid or (
            scope and ("/" + scope) in (proc / "cgroup").read_text())
        # UWSM move aplicativos para o user manager, fora do scope do login.
        if not same_session:
            continue
        score = int(bool(env.get("WAYLAND_DISPLAY"))) * 4 + int(bool(env.get("DISPLAY"))) * 2
        candidates.append((score, int(proc.name), env))
    except (OSError, ValueError):
        continue
merged = {}
for _, _, env in sorted(candidates):
    merged.update({key: env[key] for key in keys if env.get(key)})
merged["XDG_SESSION_TYPE"] = props["Type"]
merged["XDG_SESSION_ID"] = sid
if props.get("Desktop"):
    merged["XDG_CURRENT_DESKTOP"] = props["Desktop"]
if props["Type"] == "wayland" and not merged.get("WAYLAND_DISPLAY"):
    # O ambiente importado pelo compositor cobre sessoes UWSM.
    fallback = dict(item.split("=", 1) for item in run(
        "systemctl", "--user", "show-environment").splitlines() if "=" in item)
    display = fallback.get("WAYLAND_DISPLAY", "")
    runtime = merged.get("XDG_RUNTIME_DIR", "/run/user/" + uid)
    if display and (pathlib.Path(runtime) / display).is_socket():
        merged["WAYLAND_DISPLAY"] = display
print("available=yes")
for key, value in merged.items():
    print("export " + key + "=" + shlex.quote(value))
PY_SESSION
)
unset DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP XDG_SESSION_DESKTOP XDG_SESSION_TYPE
eval "$session_env"
if [[ "$available" != yes ]]; then
    echo "random-wallpaper: nenhuma sessao grafica ativa; aguardando o timer."
    exit 0
fi

wallpaper_dir="$HOME/Imagens/wallpapers"
[[ -d "$wallpaper_dir" ]] || exit 0
wallpaper=$(find "$wallpaper_dir" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) | shuf -n 1)
[[ -n "$wallpaper" ]] || exit 0
de="${XDG_CURRENT_DESKTOP:-${XDG_SESSION_DESKTOP:-}}"

set_wayland_wallpaper() {
    [[ -n "${WAYLAND_DISPLAY:-}" ]] || { echo "random-wallpaper: WAYLAND_DISPLAY ausente" >&2; return 1; }
    command -v awww >/dev/null || { echo "random-wallpaper: awww nao encontrado" >&2; return 1; }
    if ! awww query >/dev/null 2>&1; then
        command -v awww-daemon >/dev/null || return 1
        awww-daemon >/dev/null 2>&1 < /dev/null &
        for attempt in {1..30}; do
            awww query >/dev/null 2>&1 && break
            sleep 0.1
        done
    fi
    awww img "$wallpaper"
}
set_x11_wallpaper() {
    [[ -n "${DISPLAY:-}" ]] || { echo "random-wallpaper: DISPLAY ausente" >&2; return 1; }
    feh --no-fehbg --no-xinerama --bg-fill "$wallpaper"
}
case "${de,,}" in
    *gnome*)
        uri=$(python3 -c 'from pathlib import Path; import sys; print(Path(sys.argv[1]).resolve().as_uri())' "$wallpaper")
        gsettings set org.gnome.desktop.background picture-uri "$uri"
        gsettings set org.gnome.desktop.background picture-uri-dark "$uri"
        ;;
    *kde*|*plasma*)
        plasma-apply-wallpaperimage "$wallpaper"
        ;;
    *qtile*)
        set_x11_wallpaper
        ;;
    *)
        if [[ "${XDG_SESSION_TYPE:-}" == wayland ]]; then
            set_wayland_wallpaper
        else
            set_x11_wallpaper
        fi
        ;;
esac
printf 'random-wallpaper: sessao=%s desktop=%s imagem=%s\n' "$XDG_SESSION_ID" "$de" "$wallpaper"
WALLSCRIPT_EOF
sed -i 's/\r$//' "$DEST_SCRIPT"
chmod +x "$DEST_SCRIPT"

# ---------- service (embutido) ----------
cat > "$DEST_SERVICE" <<'SERVICE_EOF'
[Unit]
Description=Wallpaper aleatorio (sessao grafica ativa)
After=graphical-session.target

[Service]
Type=oneshot
ExecStart=%h/.bin/random-wallpaper.sh
Environment=XDG_RUNTIME_DIR=/run/user/%U
# Preserve o daemon awww iniciado pelo script ate o encerramento do user manager.
KillMode=process
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