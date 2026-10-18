#!/usr/bin/env bash
# binds_gnome-kde — keybinds para GNOME ou KDE (detecta a DE e aplica a config correta)
# Standalone: sem dependência de lib/common.sh.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/binds_gnome-kde.sh)
#
# GNOME: gsettings (custom keybindings via media-keys)
#   Close window : Alt+Q, Super+Q
#   Terminal     : Alt+Return, Super+Return (Blackbox ou gnome-terminal)
#   Firefox      : Alt+W, Super+W
#   Nautilus     : Alt+E, Super+E
#   Rofi    : Alt+D, Super+D
#
# KDE Plasma: kglobalshortcutsrc (~/.config/kglobalshortcutsrc)
#   Close window : Alt+Q, Super+Q (kwin "Window Close")
#   Terminal     : Alt+Return, Super+Return (konsole)
#   Firefox      : Alt+W, Super+W
#   Dolphin      : Alt+E, Super+E
#   Rofi    : Alt+D, Super+D
set -euo pipefail

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[WARN] %s\n" "$*" >&2; }
err()  { printf "[ERR] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

require_arch() {
  if [[ -f /etc/arch-release ]]; then
    return 0
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*) return 0 ;;
    esac
  fi
  die "This script requires Arch Linux."
}

detect_de() {
  local de="${XDG_CURRENT_DESKTOP:-}"
  case "${de,,}" in
    *gnome*) echo "gnome"; return 0 ;;
    *kde*|*plasma*) echo "kde"; return 0 ;;
  esac
  # Fallback: processos rodando
  if pgrep -x gnome-shell &>/dev/null; then
    echo "gnome"; return 0
  fi
  if pgrep -x kwin_x11 &>/dev/null || pgrep -x kwin_wayland &>/dev/null \
    || pgrep -f kded6 &>/dev/null || pgrep -f kded5 &>/dev/null; then
    echo "kde"; return 0
  fi
  echo "unknown"
}

# ---------- Firefox (substitui o Brave do script original) ----------
FIREFOX_CMD="firefox"
if ! command -v firefox &>/dev/null; then
  if command -v firefox-esr &>/dev/null; then
    FIREFOX_CMD="firefox-esr"
  elif command -v firefox-nightly &>/dev/null; then
    FIREFOX_CMD="firefox-nightly"
  elif command -v firefox-bin &>/dev/null; then
    FIREFOX_CMD="firefox-bin"
  else
    warn "firefox not found — keybind will be set anyway"
  fi
fi

ROFI_CMD="rofi -show drun"
command -v rofi &>/dev/null || warn "rofi not found — keybind will be set anyway"

require_arch

# ============================================================
# GNOME
# ============================================================
apply_gnome() {
  local TERMINAL_CMD="blackbox-terminal"
  if ! command -v "$TERMINAL_CMD" &>/dev/null; then
    if command -v blackbox &>/dev/null; then
      TERMINAL_CMD="blackbox"
    else
      TERMINAL_CMD="gnome-terminal"
    fi
  fi

  local NAUTILUS_CMD="nautilus"
  if ! command -v nautilus &>/dev/null; then
    if command -v gio &>/dev/null; then
      NAUTILUS_CMD="gio launch org.gnome.Nautilus"
    else
      warn "nautilus not found — keybind will be set anyway"
    fi
  fi

  local CUSTOM_SCHEMA="org.gnome.settings-daemon.plugins.media-keys"
  local CUSTOM_BASE="/org/gnome/settings-daemon/plugins/media-keys/custom-keybindings"

  set_custom_binding() {
    local id="$1"
    local name="$2"
    local command="$3"
    local binding="$4"
    local path="${CUSTOM_BASE}/${id}/"

    gsettings set "${CUSTOM_SCHEMA}.custom-keybinding:${path}" name "$name"
    gsettings set "${CUSTOM_SCHEMA}.custom-keybinding:${path}" command "$command"
    gsettings set "${CUSTOM_SCHEMA}.custom-keybinding:${path}" binding "$binding"
  }

  register_custom_paths() {
    local paths=("$@")
    local joined=""
    local p
    for p in "${paths[@]}"; do
      joined+="'${p}',"
    done
    joined="[${joined%,}]"
    gsettings set "${CUSTOM_SCHEMA}" custom-keybindings "$joined"
  }

  log "Setting window close keybinds (Alt+Q, Super+Q)..."
  gsettings set org.gnome.desktop.wm.keybindings close "['<Alt>q', '<Super>q']"

  log "Configuring custom application keybinds..."
  register_custom_paths \
    "${CUSTOM_BASE}/blackbox-alt/" \
    "${CUSTOM_BASE}/blackbox-super/" \
    "${CUSTOM_BASE}/firefox-alt/" \
    "${CUSTOM_BASE}/firefox-super/" \
    "${CUSTOM_BASE}/nautilus-alt/" \
    "${CUSTOM_BASE}/nautilus-super/" \
    "${CUSTOM_BASE}/rofi-alt/" \
    "${CUSTOM_BASE}/rofi-super/" \
    "${CUSTOM_BASE}/monitor-alt/" \
    "${CUSTOM_BASE}/monitor-super/"

  set_custom_binding "blackbox-alt" "Open Blackbox (Alt+Return)" "$TERMINAL_CMD" "<Alt>Return"
  set_custom_binding "blackbox-super" "Open Blackbox (Super+Return)" "$TERMINAL_CMD" "<Super>Return"
  set_custom_binding "firefox-alt" "Open Firefox (Alt+W)" "$FIREFOX_CMD" "<Alt>w"
  set_custom_binding "firefox-super" "Open Firefox (Super+W)" "$FIREFOX_CMD" "<Super>w"
  set_custom_binding "nautilus-alt" "Open Nautilus (Alt+E)" "$NAUTILUS_CMD" "<Alt>e"
  set_custom_binding "nautilus-super" "Open Nautilus (Super+E)" "$NAUTILUS_CMD" "<Super>e"
  set_custom_binding "rofi-alt" "Open Rofi (Alt+D)" "$ROFI_CMD" "<Alt>d"
  set_custom_binding "monitor-alt" "Monitor (Alt+M)" "$HOME/.local/bin/mon --gnome" "<Alt>m"
  set_custom_binding "monitor-super" "Monitor (Super+M)" "$HOME/.local/bin/mon --gnome" "<Super>m"
  set_custom_binding "rofi-super" "Open Rofi (Super+D)" "$ROFI_CMD" "<Super>d"

  # dconf mirrors for robustness
  dconf write /org/gnome/desktop/wm/keybindings/close "['<Alt>q', '<Super>q']" 2>/dev/null || true

  ok "GNOME keybinds configured"
  printf '  Close window : Alt+Q, Super+Q\n'
  printf '  Terminal     : Alt+Return, Super+Return (%s)\n' "$TERMINAL_CMD"
  printf '  Browser      : Alt+W, Super+W (%s)\n' "$FIREFOX_CMD"
  printf '  File manager : Alt+E, Super+E (%s)\n' "$NAUTILUS_CMD"
  printf '  Rofi    : Alt+D, Super+D\n'
}

# ============================================================
# KDE Plasma
# ============================================================
apply_kde() {
  local KGLOBAL="$HOME/.config/kglobalshortcutsrc"
  local APPS_DIR="$HOME/.local/share/applications"
  local TERMINAL_CMD="blackbox-terminal"
  if ! command -v "$TERMINAL_CMD" &>/dev/null; then
    if command -v blackbox &>/dev/null; then
      TERMINAL_CMD="blackbox"
    else
      warn "Black Box not found — terminal keybind target unavailable"
    fi
  fi
  local FILEMANAGER_CMD="dolphin"

  command -v "$TERMINAL_CMD" &>/dev/null || warn "konsole not found — keybind will be set anyway"
  command -v "$FILEMANAGER_CMD" &>/dev/null || warn "dolphin not found — keybind will be set anyway"

  # Edita grupo INI (arquivo simples, estilo kglobalshortcutsrc)
  ini_set() {
    local file="$1" section="$2" key="$3" value="$4"
    local tmp in_sec=0 found=0 line
    mkdir -p "$(dirname "$file")"
    touch "$file"
    tmp="$(mktemp)"
    while IFS= read -r line || [[ -n "$line" ]]; do
      if [[ "$line" =~ ^\[.*\]$ ]]; then
        if [[ "$in_sec" -eq 1 && "$found" -eq 0 ]]; then
          printf '%s=%s\n' "$key" "$value" >> "$tmp"
          found=1
        fi
        if [[ "$line" == "[$section]" ]]; then
          in_sec=1
        else
          in_sec=0
        fi
        printf '%s\n' "$line" >> "$tmp"
        continue
      fi
      if [[ "$in_sec" -eq 1 && "$line" == "$key="* ]]; then
        found=1
        printf '%s=%s\n' "$key" "$value" >> "$tmp"
      else
        printf '%s\n' "$line" >> "$tmp"
      fi
    done < "$file"
    if [[ "$found" -eq 0 ]]; then
      if [[ "$in_sec" -eq 0 ]]; then
        printf '\n[%s]\n' "$section" >> "$tmp"
      fi
      printf '%s=%s\n' "$key" "$value" >> "$tmp"
    fi
    mv "$tmp" "$file"
  }

  # Cria .desktop em ~/.local/share/applications e registra o atalho em
  # kglobalshortcutsrc [services][<id>.desktop] (mesmo formato do kmenuedit)
  set_kde_custom_binding() {
    local id="$1"
    local name="$2"
    local command="$3"
    local binding="$4"
    local desktop="$APPS_DIR/${id}.desktop"

    cat > "$desktop" <<EOF
[Desktop Entry]
Type=Application
Name=$name
Exec=$command
NoDisplay=true
EOF

    ini_set "$KGLOBAL" "services][${id}.desktop" "_launch" "$binding"
    ok "KDE shortcut: $binding -> $command ($id)"
  }

  log "Setting window close keybinds (Alt+Q, Super+Q)..."
  ini_set "$KGLOBAL" "kwin" "Window Close" $'Alt+Q\tSuper+Q,Alt+F4,Close Window'

  log "Configuring custom application keybinds..."
  set_kde_custom_binding "blackbox-alt" "Open Black Box (Alt+Return)" "$TERMINAL_CMD" "Alt+Return"
  set_kde_custom_binding "blackbox-super" "Open Black Box (Super+Return)" "$TERMINAL_CMD" "Meta+Return"
  ini_set "$KGLOBAL" "services][konsole-alt.desktop" "_launch" ""
  ini_set "$KGLOBAL" "services][konsole-super.desktop" "_launch" ""
  set_kde_custom_binding "firefox-alt" "Open Firefox (Alt+W)" "$FIREFOX_CMD" "Alt+W"
  set_kde_custom_binding "firefox-super" "Open Firefox (Super+W)" "$FIREFOX_CMD" "Meta+W"
  set_kde_custom_binding "dolphin-alt" "Open Dolphin (Alt+E)" "$FILEMANAGER_CMD" "Alt+E"
  set_kde_custom_binding "dolphin-super" "Open Dolphin (Super+E)" "$FILEMANAGER_CMD" "Meta+E"
  set_kde_custom_binding "monitor-alt" "Monitor (Alt+M)" "$HOME/.local/bin/mon --kde" "Alt+M"
  set_kde_custom_binding "monitor-super" "Monitor (Super+M)" "$HOME/.local/bin/mon --kde" "Meta+M"
  set_kde_custom_binding "rofi-alt" "Open Rofi (Alt+D)" "$ROFI_CMD" "Alt+D"
  set_kde_custom_binding "rofi-super" "Open Rofi (Super+D)" "$ROFI_CMD" "Meta+D"

  # Reconstrói cache de aplicações e recarrega os atalhos
  log "Rebuilding application cache and reloading shortcuts..."
  kbuildsycoca6 &>/dev/null 2>&1 || kbuildsycoca5 &>/dev/null 2>&1 || true

  if command -v qdbus &>/dev/null; then
    qdbus org.kde.KWin /KWin reconfigure 2>/dev/null || true
  elif command -v qdbus6 &>/dev/null; then
    qdbus6 org.kde.KWin /KWin reconfigure 2>/dev/null || true
  fi
  systemctl --user restart plasma-kglobalaccel.service 2>/dev/null || true

  ok "KDE keybinds configured"
  printf '  Close window : Alt+Q, Super+Q\n'
  printf '  Terminal     : Alt+Return, Super+Return (%s)\n' "$TERMINAL_CMD"
  printf '  Browser      : Alt+W, Super+W (%s)\n' "$FIREFOX_CMD"
  printf '  File manager : Alt+E, Super+E (%s)\n' "$FILEMANAGER_CMD"
  printf '  Rofi    : Alt+D, Super+D\n'
}

DE="$(detect_de)"
log "Detected desktop environment: $DE"

case "$DE" in
  gnome) apply_gnome ;;
  kde)   apply_kde ;;
  *)
    die "Desktop environment not detected (GNOME or KDE required). Set XDG_CURRENT_DESKTOP and run again."
    ;;
esac