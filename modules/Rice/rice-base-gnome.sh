#!/usr/bin/env bash
# rice-base.sh
#
# Uso:
#   bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/rice-base.sh)
#
# Instala e aplica, no usuario atual (sem root para os temas):
#   GTK    WhiteSur  -> ~/.themes
#          Padrao upstream: Light e Dark, opacidade normal e solid.
#          Pastas: WhiteSur-Light, WhiteSur-Dark, WhiteSur-Light-solid, WhiteSur-Dark-solid
#          Libadwaita: ./install.sh -l (grava ~/.config/gtk-4.0). Depois
#          gtk.css e apontado para gtk-Dark.css.
#          Tema aplicado: WhiteSur-Dark
#   Icones MacTahoe  -> ~/.local/share/icons
#          Padrao upstream: MacTahoe, MacTahoe-light, MacTahoe-dark
#          Tema aplicado: MacTahoe-dark
#   Cursor Vimix     -> ~/.local/share/icons
#          Pastas: Vimix-cursors e Vimix-white-cursors
#          Cursor aplicado: Vimix-cursors
#
# Distros: Arch (pacman), Fedora (dnf), Ubuntu/Debian (apt-get), openSUSE
# Tumbleweed/Leap (zypper --non-interactive), via ID e ID_LIKE.
# Fontes em ~/.local/src/rice-base (git pull --ff-only se o clone ja existir).
set -euo pipefail

SRC_ROOT="${HOME}/.local/src/rice-base"
GTK_THEME="WhiteSur-Dark"
ICON_THEME="MacTahoe-dark"
CURSOR_THEME="Vimix-cursors"
CURSOR_SIZE="24"

log() { printf '\n==> %s\n' "$*"; }
die() { printf 'ERRO: %s\n' "$*" >&2; exit 1; }

if [[ "${EUID}" -eq 0 ]]; then
  die "Execute como usuario normal, nao como root. Os temas vao para ~/.themes e ~/.local/share/icons."
fi

if [[ ! -r /etc/os-release ]]; then
  die "Nao encontrei /etc/os-release. Este script cobre Arch, Fedora e Ubuntu/Debian."
fi

# shellcheck disable=SC1091
source /etc/os-release

detect_family() {
  local id="${ID:-}" like=" ${ID_LIKE:-} "
  case "${id}" in
    arch|archlinux) printf 'arch'; return 0 ;;
    fedora) printf 'fedora'; return 0 ;;
    ubuntu|debian|linuxmint|pop|neon|elementary) printf 'debian'; return 0 ;;
    opensuse-tumbleweed|opensuse-leap|opensuse|suse) printf 'opensuse'; return 0 ;;
  esac
  if [[ "${like}" == *" arch "* || "${like}" == *" archlinux "* ]]; then
    printf 'arch'; return 0
  fi
  if [[ "${like}" == *" fedora "* ]]; then
    printf 'fedora'; return 0
  fi
  if [[ "${like}" == *" ubuntu "* || "${like}" == *" debian "* ]]; then
    printf 'debian'; return 0
  fi
  if [[ "${like}" == *" suse "* || "${like}" == *" opensuse "* ]]; then
    printf 'opensuse'; return 0
  fi
  return 1
}

FAMILY="$(detect_family)" || die "Distro nao suportada (ID=${ID:-?} ID_LIKE=${ID_LIKE:-}). Este script cobre Arch, Fedora, Ubuntu/Debian e openSUSE."

log "Distro: ${PRETTY_NAME:-$ID} (familia ${FAMILY})"

need_sudo() {
  if ! command -v sudo >/dev/null 2>&1; then
    die "sudo nao encontrado. Instale os pacotes do tema manualmente e rode de novo."
  fi
}

install_packages() {
  log "Instalando dependencias (${FAMILY})"
  need_sudo
  case "${FAMILY}" in
    arch)
      # Nomes usados pelo proprio install.sh do WhiteSur (libs/lib-install.sh)
      # e pelo README: sassc, glib2 (glib-compile-resources), libxml2 (xmllint).
      # optipng e inkscape: deps opcionais de render do README.
      # gtk-engine-murrine: motor GTK2. gtk-update-icon-cache: chamado pelo MacTahoe.
      sudo pacman -S --needed --noconfirm \
        git sassc glib2 libxml2 optipng inkscape gtk-engine-murrine gtk-update-icon-cache
      ;;
    fedora)
      sudo dnf install -y \
        git sassc glib2-devel libxml2 optipng inkscape gtk-murrine-engine gtk3
      ;;
    debian)
      sudo apt-get update
      local glib_pkg="libglib2.0-dev-bin"
      local major="${VERSION_ID%%.*}"
      # README: Ubuntu >= 20.04 usa libglib2.0-dev-bin;
      # Ubuntu 18.04, Debian 10 e Linux Mint 19 usam libglib2.0-dev.
      if [[ "${major}" =~ ^[0-9]+$ ]]; then
        if [[ "${ID}" == "ubuntu" && "${major}" -lt 20 ]] \
          || [[ "${ID}" == "debian" && "${major}" -lt 11 ]] \
          || [[ "${ID}" == "linuxmint" && "${major}" -lt 20 ]]; then
          glib_pkg="libglib2.0-dev"
        fi
      fi
      sudo apt-get install -y \
        git sassc "${glib_pkg}" libglib2.0-bin libxml2-utils \
        optipng inkscape gtk2-engines-murrine gtk-update-icon-cache
      ;;
    opensuse)
      sudo zypper --non-interactive install --auto-agree-with-licenses \
        git sassc glib2-devel libxml2-tools optipng inkscape \
        gtk2-engine-murrine gtk3
      ;;
  esac
}

clone_or_update() {
  local url="$1" dest="$2"
  mkdir -p "${SRC_ROOT}"
  if [[ -d "${dest}/.git" ]]; then
    log "Atualizando $(basename "${dest}") (git pull --ff-only)"
    git -C "${dest}" pull --ff-only
  elif [[ -e "${dest}" ]]; then
    die "Existe ${dest} mas nao e um repositorio git. Remova ou mova essa pasta e rode de novo."
  else
    log "Clonando $(basename "${dest}")"
    git clone "${url}" "${dest}"
  fi
}

merge_ini_key() {
  local file="$1" key="$2" value="$3" only_if_missing="$4"
  local tmp in_settings=0 found=0 line
  mkdir -p "$(dirname "${file}")"
  tmp="$(mktemp)"
  if [[ -f "${file}" ]]; then
    while IFS= read -r line || [[ -n "${line}" ]]; do
      if [[ "${line}" =~ ^\[.*\]$ ]]; then
        if [[ "${in_settings}" -eq 1 && "${found}" -eq 0 ]]; then
          printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
          found=1
        fi
        if [[ "${line}" == "[Settings]" ]]; then
          in_settings=1
        else
          in_settings=0
        fi
        printf '%s\n' "${line}" >> "${tmp}"
        continue
      fi
      if [[ "${in_settings}" -eq 1 && "${line}" == "${key}="* ]]; then
        found=1
        if [[ "${only_if_missing}" -eq 1 ]]; then
          printf '%s\n' "${line}" >> "${tmp}"
        else
          printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
        fi
      else
        printf '%s\n' "${line}" >> "${tmp}"
      fi
    done < "${file}"
    if [[ "${found}" -eq 0 ]]; then
      if [[ "${in_settings}" -eq 0 ]]; then
        printf '\n[Settings]\n' >> "${tmp}"
      fi
      printf '%s=%s\n' "${key}" "${value}" >> "${tmp}"
    fi
  else
    printf '[Settings]\n%s=%s\n' "${key}" "${value}" > "${tmp}"
  fi
  mv "${tmp}" "${file}"
}

apply_settings() {
  local ini size_now
  log "Aplicando tema para o usuario ${USER}"

  if [[ ! -d "${HOME}/.themes/${GTK_THEME}" ]]; then
    die "Pasta do tema GTK nao encontrada: ${HOME}/.themes/${GTK_THEME}"
  fi
  if [[ ! -d "${HOME}/.local/share/icons/${ICON_THEME}" ]]; then
    die "Pasta de icones nao encontrada: ${HOME}/.local/share/icons/${ICON_THEME}"
  fi
  if [[ ! -d "${HOME}/.local/share/icons/${CURSOR_THEME}" ]]; then
    die "Pasta do cursor nao encontrada: ${HOME}/.local/share/icons/${CURSOR_THEME}"
  fi

  if command -v gsettings >/dev/null 2>&1 \
    && gsettings list-schemas 2>/dev/null | grep -qx 'org.gnome.desktop.interface'; then
    gsettings set org.gnome.desktop.interface gtk-theme "${GTK_THEME}"
    gsettings set org.gnome.desktop.interface icon-theme "${ICON_THEME}"
    gsettings set org.gnome.desktop.interface cursor-theme "${CURSOR_THEME}"
    if gsettings list-keys org.gnome.desktop.interface 2>/dev/null | grep -qx color-scheme; then
      gsettings set org.gnome.desktop.interface color-scheme prefer-dark
    fi
    size_now=""
    if command -v dconf >/dev/null 2>&1; then
      size_now="$(dconf read /org/gnome/desktop/interface/cursor-size || true)"
    fi
    if [[ -z "${size_now}" ]]; then
      gsettings set org.gnome.desktop.interface cursor-size "${CURSOR_SIZE}"
      log "cursor-size definido para ${CURSOR_SIZE}"
    else
      log "cursor-size ja estava definido (${size_now}); mantido"
    fi
    log "gsettings aplicado: gtk-theme=${GTK_THEME} icon-theme=${ICON_THEME} cursor-theme=${CURSOR_THEME}"
  else
    log "gsettings ou o schema org.gnome.desktop.interface indisponivel; seguindo so com settings.ini"
  fi

  for ini in "${HOME}/.config/gtk-3.0/settings.ini" "${HOME}/.config/gtk-4.0/settings.ini"; do
    merge_ini_key "${ini}" "gtk-theme-name" "${GTK_THEME}" 0
    merge_ini_key "${ini}" "gtk-icon-theme-name" "${ICON_THEME}" 0
    merge_ini_key "${ini}" "gtk-cursor-theme-name" "${CURSOR_THEME}" 0
    merge_ini_key "${ini}" "gtk-cursor-theme-size" "${CURSOR_SIZE}" 1
    merge_ini_key "${ini}" "gtk-application-prefer-dark-theme" "1" 1
    log "Atualizado ${ini}"
  done

  local gtk4css="${HOME}/.config/gtk-4.0/gtk.css"
  local gtk4dark="${HOME}/.config/gtk-4.0/gtk-Dark.css"
  if [[ -f "${gtk4dark}" ]]; then
    ln -sfn "${gtk4dark}" "${gtk4css}"
    log "libadwaita gtk.css -> gtk-Dark.css"
  fi

  log "Pronto. Tema escuro ativo: ${GTK_THEME} / ${ICON_THEME} / ${CURSOR_THEME}"
}

install_packages

clone_or_update "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" "${SRC_ROOT}/WhiteSur-gtk-theme"
clone_or_update "https://github.com/vinceliuice/MacTahoe-icon-theme.git" "${SRC_ROOT}/MacTahoe-icon-theme"
clone_or_update "https://github.com/vinceliuice/Vimix-cursors.git" "${SRC_ROOT}/Vimix-cursors"

log "Instalando WhiteSur (./install.sh -l: variantes padrao + libadwaita)"
(
  cd "${SRC_ROOT}/WhiteSur-gtk-theme"
  ./install.sh -l
)

log "Instalando icones MacTahoe (./install.sh padrao)"
(
  cd "${SRC_ROOT}/MacTahoe-icon-theme"
  ./install.sh
)

log "Instalando cursores Vimix (./install.sh no diretorio do repo; install.sh usa dist/ relativo)"
(
  cd "${SRC_ROOT}/Vimix-cursors"
  ./install.sh
)

apply_settings
