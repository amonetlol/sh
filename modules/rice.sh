#!/usr/bin/env bash
# rice — temas GTK, cursor e ícones (standalone)
# Baixa os assets diretamente do repo amonetlol/dot (Assets) e instala em ~/.themes e ~/.icons.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/rice.sh)
set -euo pipefail

DOT_ASSETS="${DOT_ASSETS:-https://github.com/amonetlol/dot/raw/main/Assets}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sh-assets"

THEMES_DIR="$HOME/.themes"
ICONS_DIR="$HOME/.icons"

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

require_not_root() {
  if [[ "${EUID}" -eq 0 ]]; then
    fail "Não rode este script como root. Use seu usuário normal com sudo."
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

install_rice_dependencies() {
  local base missing=()
  base="$(detect_distro_base)"

  case "$base" in
    arch)
      command -v unzip >/dev/null 2>&1 || missing+=(unzip)
      command -v xz >/dev/null 2>&1 || missing+=(xz)
      pacman -Q gtk3 >/dev/null 2>&1 || missing+=(gtk3)
      if [[ ${#missing[@]} -gt 0 ]]; then
        sudo pacman -Sy --needed --noconfirm "${missing[@]}"
      fi
      ;;
    fedora)
      command -v unzip >/dev/null 2>&1 || missing+=(unzip)
      command -v tar >/dev/null 2>&1 || missing+=(tar)
      command -v xz >/dev/null 2>&1 || missing+=(xz)
      rpm -q gtk3 >/dev/null 2>&1 || missing+=(gtk3)
      if [[ ${#missing[@]} -gt 0 ]]; then
        sudo dnf install -y "${missing[@]}"
      fi
      ;;
    ubuntu)
      command -v unzip >/dev/null 2>&1 || missing+=(unzip)
      command -v tar >/dev/null 2>&1 || missing+=(tar)
      command -v xz >/dev/null 2>&1 || missing+=(xz-utils)
      dpkg -l libgtk-3-0 >/dev/null 2>&1 || missing+=(libgtk-3-0)
      if [[ ${#missing[@]} -gt 0 ]]; then
        sudo apt-get update -qq
        DEBIAN_FRONTEND=noninteractive sudo apt-get install -y "${missing[@]}"
      fi
      ;;
    *)
      echo "Base não suportada para Rice: $base" >&2
      return 1
      ;;
  esac
}

download_asset() {
  local file="$1"
  local dest="$CACHE_DIR/$file"
  if [[ -f "$dest" ]]; then
    ok "$file (já existe em cache)"
    return 0
  fi
  mkdir -p "$CACHE_DIR"
  log "Baixando $file..."
  curl -fL "$DOT_ASSETS/$file" -o "$dest"
  ok "$file"
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

echo "Base — Rice — temas GTK, cursor e ícones ($(detect_distro_base))"

require_not_root

echo "=== Verificando dependências ==="
install_rice_dependencies

echo "=== Criando diretórios ==="
mkdir -p "$THEMES_DIR"
mkdir -p "$ICONS_DIR"
ok "Diretório criado/verificado: ~/.themes"
ok "Diretório criado/verificado: ~/.icons"

extract_archive() {
  local archive_file="$1"
  local destination="$2"
  local label="$3"

  if [[ ! -f "$archive_file" ]]; then
    warn "Arquivo não encontrado: $archive_file"
    warn "Pulando: $label"
    return 0
  fi

  log "Instalando $label..."
  log "Arquivo: $archive_file"
  log "Destino: $destination"

  case "$archive_file" in
    *.zip)
      unzip -o -q "$archive_file" -d "$destination"
      ;;
    *.tar.xz)
      tar -xJf "$archive_file" -C "$destination"
      ;;
    *.tar.gz|*.tgz)
      tar -xzf "$archive_file" -C "$destination"
      ;;
    *.tar)
      tar -xf "$archive_file" -C "$destination"
      ;;
    *)
      warn "Formato não suportado: $archive_file"
      return 0
      ;;
  esac

  ok "$label instalado em $destination"
}

install_catppuccin_theme() {
  local archive_file="$1"
  local folder_inside_zip="$2"
  local final_folder_name="$3"
  local themes_dir="$4"

  local tmp_dir="/tmp/catppuccin-theme-extractor"
  local final_dest="$themes_dir/$final_folder_name"

  if [[ ! -f "$archive_file" ]]; then
    warn "Arquivo não encontrado: $archive_file"
    warn "Pulando: Tema $final_folder_name"
    return 0
  fi

  log "Instalando Tema Catppuccin ($final_folder_name)..."
  log "Arquivo: $archive_file"
  log "Destino: $final_dest"

  rm -rf "$tmp_dir"
  mkdir -p "$tmp_dir"
  unzip -o -q "$archive_file" -d "$tmp_dir"

  rm -rf "$final_dest"
  cp -r "$tmp_dir/$folder_inside_zip" "$final_dest"

  rm -rf "$tmp_dir"

  ok "Tema $final_folder_name instalado com sucesso!"
}

echo "=== Baixando assets (repo dot) ==="
download_asset "Manhattan.zip"
download_asset "Qogir-cursors.tar.xz"
download_asset "MacTahoe.tar.xz"
download_asset "catppuccin-mocha-blue-standard+default.zip"
download_asset "catppuccin-frappe-blue-standard+default.zip"

echo "=== Instalando temas GTK ==="
extract_archive "$CACHE_DIR/Manhattan.zip" "$THEMES_DIR" "Tema Manhattan"
install_catppuccin_theme "$CACHE_DIR/catppuccin-mocha-blue-standard+default.zip" "catppuccin-mocha-blue-standard+default" "catppuccin-mocha-blue" "$THEMES_DIR"
install_catppuccin_theme "$CACHE_DIR/catppuccin-frappe-blue-standard+default.zip" "catppuccin-frappe-blue-standard+default" "catppuccin-frappe-blue" "$THEMES_DIR"

echo "=== Instalando cursor ==="
extract_archive "$CACHE_DIR/Qogir-cursors.tar.xz" "$ICONS_DIR" "Cursor Qogir"

echo "=== Instalando ícones ==="
extract_archive "$CACHE_DIR/MacTahoe.tar.xz" "$ICONS_DIR" "Ícones MacTahoe"

echo "=== Atualizando cache de ícones ==="
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  find "$ICONS_DIR" -mindepth 1 -maxdepth 1 -type d | while read -r icon_theme; do
    if [[ -f "$icon_theme/index.theme" ]]; then
      log "Atualizando cache: $icon_theme"
      gtk-update-icon-cache -f -t "$icon_theme" >/dev/null 2>&1 || warn "Não foi possível atualizar cache de: $icon_theme"
    fi
  done
else
  warn "gtk-update-icon-cache não encontrado. Pulando cache de ícones."
fi

echo "=== Aplicando temas GTK ==="
if [[ -x "$HOME/.config/hypr/scripts/gtkthemes" ]]; then
  "$HOME/.config/hypr/scripts/gtkthemes"
else
  warn "~/.config/hypr/scripts/gtkthemes ausente — rode o módulo hypr-temas para aplicar automaticamente."
fi

echo "=== RICE FINALIZADO ==="

cat <<EOF
Rice instalado.

Assets em cache: $CACHE_DIR
  Manhattan.zip
  Qogir-cursors.tar.xz
  MacTahoe.tar.xz
  catppuccin-mocha-blue-standard+default.zip
  catppuccin-frappe-blue-standard+default.zip

Verifique no nwg-look:

  Tema GTK: Manhattan || catppuccin-mocha-blue || catppuccin-frappe-blue
  Cursor: Qogir
  Ícones: MacTahoe
EOF

ok "Temas, cursor e ícones processados."