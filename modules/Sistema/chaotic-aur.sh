#!/usr/bin/env bash
# chaotic-aur — adiciona o repositório Chaotic-AUR (Arch)
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/chaotic-aur.sh)
set -euo pipefail

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

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

# Append stdin to root-owned file (evita sudo -S + tee corromper com a senha).
sudo_append_to_file() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  if sudo test -f "$dest" 2>/dev/null; then
    sudo cat "$dest" >"$tmp"
  fi
  cat >>"$tmp"
  sudo cp "$tmp" "$dest"
  rm -f "$tmp"
}

if ! is_arch_based; then
  echo "Não é base Arch — Chaotic-AUR ignorado."
  exit 0
fi

echo "=== Adicionando Chaotic-AUR ==="

echo "→ Recebendo chave GPG..."
sudo pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
sudo pacman-key --lsign-key 3056513887B78AEB

echo "→ Instalando chaotic-keyring e chaotic-mirrorlist..."
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst'
sudo pacman -U --noconfirm 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

echo "→ Configurando /etc/pacman.conf..."
if ! grep -q '\[chaotic-aur\]' /etc/pacman.conf; then
  sudo_append_to_file /etc/pacman.conf <<'EOF'

[chaotic-aur]
SigLevel = Optional TrustedOnly
Include = /etc/pacman.d/chaotic-mirrorlist
EOF
  echo "Repositório Chaotic-AUR adicionado."
else
  echo "Chaotic-AUR já configurado."
fi

echo "→ Atualizando banco de dados..."
sudo pacman -Sy --noconfirm
ok "Chaotic-AUR pronto."