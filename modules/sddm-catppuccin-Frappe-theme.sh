#!/usr/bin/env bash
# sddm-theme — SDDM Catppuccin Frappe Blue (Arch)
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/sddm-theme.sh)
set -euo pipefail

ok() { printf "[OK] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

# sudo com suporte a INSTALL_SUDO_PASSWORD / SUDO_ASKPASS
sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    if [[ "$1" == "-S" || "$1" == "-A" || "$1" == "-n" || "$1" == "-v" ]]; then
      command sudo "$@"
    else
      command sudo -H "$@"
    fi
    return $?
  fi
  if [[ -n "${INSTALL_SUDO_PASSWORD:-}" ]]; then
    printf '%s\n' "$INSTALL_SUDO_PASSWORD" | command sudo -S "$@"
  elif [[ -n "${SUDO_ASKPASS:-}" ]]; then
    export DISPLAY="${DISPLAY:-:0}"
    command sudo -A "$@"
  else
    command sudo "$@"
  fi
}

# Grava ficheiro em path root sem heredoc+tee (sudo -S consome stdin).
sudo_write_file() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  sudo mkdir -p "$(dirname "$dest")"
  sudo cp "$tmp" "$dest"
  rm -f "$tmp"
}

is_arch_based() {
  [[ -f /etc/arch-release ]] && return 0
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*)
        return 0
        ;;
    esac
  fi
  return 1
}

if ! is_arch_based; then
  echo "Não é base Arch — SDDM theme ignorado."
  exit 0
fi

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sh-assets"
THEME_NAME="catppuccin-frappe-blue"
SDDM_THEMES="/usr/share/sddm/themes"
THEME_URL="https://github.com/catppuccin/sddm/releases/download/v1.1.2/catppuccin-frappe-blue-sddm.zip"

disable_other_dms() {
  for dm in lightdm gdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      echo "Desativando $dm..."
      sudo systemctl disable --now "$dm" 2>/dev/null || sudo systemctl disable "$dm" || true
    fi
  done
}

install_theme() {
  local zip="$CACHE_DIR/catppuccin-frappe-blue-sddm.zip"
  local tmp
  if [[ ! -f "$zip" ]]; then
    mkdir -p "$CACHE_DIR"
    curl -fL "$THEME_URL" -o "$zip"
  fi
  tmp="$(mktemp -d)"
  unzip -oq "$zip" -d "$tmp"
  sudo rm -rf "$SDDM_THEMES/$THEME_NAME"
  # zip contém catppuccin-frappe-blue/ — mover para themes sem aninhar
  if [[ -d "$tmp/$THEME_NAME" ]]; then
    sudo mv "$tmp/$THEME_NAME" "$SDDM_THEMES/$THEME_NAME"
  else
    sudo mkdir -p "$SDDM_THEMES/$THEME_NAME"
    sudo mv "$tmp"/* "$SDDM_THEMES/$THEME_NAME/"
  fi
  rm -rf "$tmp"
  [[ -f "$SDDM_THEMES/$THEME_NAME/Main.qml" ]] || {
    echo "ERRO: Main.qml não encontrado em $SDDM_THEMES/$THEME_NAME"
    exit 1
  }
}

configure_sddm() {
  sudo_write_file /etc/sddm.conf.d/theme.conf <<EOF
[Theme]
Current=$THEME_NAME
EOF
  sudo chmod a+r /etc/sddm.conf.d/theme.conf
  # Garantir que não há Current conflitante no sddm.conf principal
  if grep -q '^Current=' /etc/sddm.conf 2>/dev/null; then
    sudo sed -i 's/^Current=.*/Current='"$THEME_NAME"'/' /etc/sddm.conf
  fi
}

sudo pacman -S --needed --noconfirm sddm qt6-svg qt6-declarative 2>/dev/null || \
  sudo pacman -S --needed --noconfirm sddm qt6-svg
disable_other_dms
install_theme
configure_sddm
sudo systemctl enable sddm
ok "SDDM tema $THEME_NAME instalado ($(ls "$SDDM_THEMES/$THEME_NAME/Main.qml" 2>/dev/null && echo OK))"