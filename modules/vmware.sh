#!/usr/bin/env bash
# vmware — open-vm-tools quando rodando dentro de VMware (Arch / Fedora / Ubuntu)
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/vmware.sh)
set -euo pipefail

warn() { printf "[AVISO] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }

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

detect_distro_base() {
  if [[ -f /etc/arch-release ]]; then
    echo "arch"; return 0
  fi
  if [[ -f /etc/fedora-release ]]; then
    echo "fedora"; return 0
  fi
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*) echo "arch"; return 0 ;;
      fedora*|*:fedora*|rhel*|centos*|rocky*|alma*) echo "fedora"; return 0 ;;
      ubuntu*|debian*|pop*|linuxmint*|zorin*|elementary*|*:ubuntu*|*:debian*) echo "ubuntu"; return 0 ;;
    esac
  fi
  [[ -f /etc/debian_version ]] && { echo "ubuntu"; return 0; }
  echo "unknown"
}

is_vmware() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    [[ "$(systemd-detect-virt)" == "vmware" ]] && return 0
  fi
  grep -qi vmware /sys/class/dmi/id/product_name 2>/dev/null && return 0
  grep -qi vmware /sys/class/dmi/id/sys_vendor 2>/dev/null && return 0
  return 1
}

if ! is_vmware; then
  echo "Não é VMware — open-vm-tools ignorado."
  exit 0
fi

BASE="$(detect_distro_base)"
echo "VMware detectado — instalando open-vm-tools (base: $BASE)..."

case "$BASE" in
  arch)
    if ! sudo pacman -S --needed --noconfirm open-vm-tools gtkmm3 fuse2 fuse3; then
      warn "open-vm-tools falhou (mirrors?) — continuando sem vmtoolsd"
      exit 0
    fi
    ;;
  fedora)
    if ! sudo dnf install -y open-vm-tools open-vm-tools-desktop; then
      warn "open-vm-tools falhou — continuando sem vmtoolsd"
      exit 0
    fi
    ;;
  ubuntu)
    if ! sudo apt-get update -qq; then
      warn "apt-get update falhou"
      exit 0
    fi
    if ! sudo apt-get install -y open-vm-tools open-vm-tools-desktop; then
      warn "open-vm-tools falhou — continuando sem vmtoolsd"
      exit 0
    fi
    ;;
  *)
    echo "Base não suportada ($BASE) — VMware ignorado."
    exit 0
    ;;
esac

sudo systemctl enable --now vmtoolsd 2>/dev/null || \
  sudo systemctl enable --now open-vm-tools 2>/dev/null || \
  warn "serviço vmtoolsd não ativado"
ok "open-vm-tools configurado."