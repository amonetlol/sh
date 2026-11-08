#!/usr/bin/env bash
# sublime-text — Sublime Text 4, tema Catppuccin Frappe e fonte CodeNewRoman
# Arch: repositório oficial stable. NixOS: o pacote sublime4 vem do rice nixos;
# este módulo ainda aplica tema e fonte.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/sublime-text.sh)
set -euo pipefail

DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"
CATPPUCCIN_REPO="${CATPPUCCIN_REPO:-https://github.com/catppuccin/sublime-text.git}"
FONT_FAMILY="CodeNewRoman Nerd Font"
SUBLIME_PACKAGES="${XDG_CONFIG_HOME:-$HOME/.config}/sublime-text/Packages"

log() { printf "[*] %s\n" "$*"; }
ok() { printf "[OK] %s\n" "$*"; }
warn() { printf "[AVISO] %s\n" "$*"; }
fail() { printf "[ERRO] %s\n" "$*" >&2; exit 1; }

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

is_arch_based() {
  [[ -f /etc/arch-release ]] && return 0
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*) return 0 ;;
    esac
  fi
  return 1
}

is_nixos() {
  [[ -f /etc/NIXOS || -f /etc/nixos/configuration.nix ]]
}

work="$(mktemp -d)"
trap 'rm -rf -- "$work"' EXIT

install_sublime_arch() {
  if ! grep -q '^\[sublime-text\]' /etc/pacman.conf 2>/dev/null; then
    log "Adicionando o repositório oficial stable do Sublime Text"
    curl -fL --retry 3 -o "$work/sublimehq-pub.gpg" https://download.sublimetext.com/sublimehq-pub.gpg
    sudo pacman-key --add "$work/sublimehq-pub.gpg" || true
    sudo pacman-key --lsign-key 8A8F901A || true
    printf '\n[sublime-text]\nServer = https://download.sublimetext.com/arch/stable/x86_64\n' | sudo tee -a /etc/pacman.conf >/dev/null
  fi
  sudo pacman -Sy --needed --noconfirm sublime-text
  ok "Sublime Text 4 (canal stable)"
}

install_codenewroman() {
  if fc-list : family 2>/dev/null | grep -q 'CodeNewRoman Nerd Font'; then
    ok "Fonte já instalada: $FONT_FAMILY"
    return 0
  fi
  command -v git >/dev/null || fail "git não encontrado para baixar a CodeNewRoman."
  log "Baixando CodeNewRoman Nerd Font do repositório dot"
  git clone --depth 1 --filter=blob:none --sparse "$DOT_REPO" "$work/dot"
  git -C "$work/dot" sparse-checkout set dotfiles/fonts/.fonts/CodeNewRoman
  local src="$work/dot/dotfiles/fonts/.fonts/CodeNewRoman"
  [[ -d $src ]] || fail "CodeNewRoman não encontrada em $DOT_REPO"
  mkdir -p "$HOME/.local/share/fonts/CodeNewRoman"
  cp -a "$src/." "$HOME/.local/share/fonts/CodeNewRoman/"
  fc-cache -f "$HOME/.local/share/fonts" >/dev/null || fc-cache -f >/dev/null || true
  ok "Fonte instalada: $FONT_FAMILY"
}

install_catppuccin() {
  mkdir -p "$SUBLIME_PACKAGES"
  local dest="$SUBLIME_PACKAGES/Catppuccin"
  if [[ -d $dest/.git ]]; then
    log "Atualizando tema Catppuccin"
    git -C "$dest" pull --ff-only || warn "git pull do tema falhou — usando a cópia local"
  else
    rm -rf "$dest"
    git clone --depth 1 "$CATPPUCCIN_REPO" "$dest"
  fi
  [[ -f "$dest/build/Catppuccin Frappe.sublime-color-scheme" ]] || fail "O tema não contém Catppuccin Frappe."
  ok "Tema Catppuccin em $dest"
}

write_preferences() {
  mkdir -p "$SUBLIME_PACKAGES/User"
  python3 - "$SUBLIME_PACKAGES/User/Preferences.sublime-settings" "$FONT_FAMILY" <<'PY'
import json, sys
from pathlib import Path
path, font = Path(sys.argv[1]), sys.argv[2]
data = {}
if path.exists():
    try:
        data = json.loads(path.read_text())
    except json.JSONDecodeError:
        data = {}
data["color_scheme"] = "Packages/Catppuccin/build/Catppuccin Frappe.sublime-color-scheme"
data["theme"] = "Adaptive.sublime-theme"
data["font_face"] = font
data.setdefault("font_size", 13)
path.write_text(json.dumps(data, indent=4, ensure_ascii=False) + "\n")
PY
  ok "Preferências: Catppuccin Frappe + $FONT_FAMILY"
}

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  fail "Execute como usuário comum."
fi
command -v git >/dev/null || fail "git não encontrado."
command -v python3 >/dev/null || fail "python3 não encontrado."

if is_arch_based; then
  install_sublime_arch
elif is_nixos; then
  if command -v subl >/dev/null 2>&1; then
    ok "NixOS: sublime4 já está no sistema"
  else
    warn "NixOS: instale pkgs.sublime4 pelo rice nixos. Tema e fonte serão aplicados mesmo assim."
  fi
elif ! command -v subl >/dev/null 2>&1; then
  warn "Distro sem instalador de Sublime neste módulo. Tema e fonte serão aplicados se o editor já existir."
fi

install_codenewroman
install_catppuccin
write_preferences
ok "Sublime Text 4 com Catppuccin Frappe e CodeNewRoman. Reabra o editor se ele já estava aberto."
