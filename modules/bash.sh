#!/usr/bin/env bash
# bash — instala aliases/funções + .bashrc (starship nord ativo) + ~/.bin
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/bash.sh)
set -euo pipefail

DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"
DOT_CACHE="${DOT_CACHE:-$HOME/.cache/base-dot-repo}"

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

dot_backup_path() {
  local path="$1"
  if [[ -e "$path" || -L "$path" ]]; then
    local backup="${path}.bak-$(date +%Y%m%d-%H%M%S)"
    log "Backup: $path -> $backup"
    mv "$path" "$backup"
  fi
}

dot_copy_tree() {
  local src="$1"
  local dest="$2"
  mkdir -p "$(dirname "$dest")"
  if command -v rsync >/dev/null 2>&1; then
    rsync -a "$src/" "$dest/"
  else
    cp -a "$src/." "$dest/"
  fi
}

dot_ensure_repo() {
  if ! command -v git >/dev/null 2>&1; then
    fail "git não encontrado."
  fi

  if [[ -d "$DOT_CACHE/.git" ]]; then
    log "Atualizando cache dot: $DOT_CACHE"
    git -C "$DOT_CACHE" pull --ff-only 2>/dev/null || warn "git pull falhou — usando cache local"
    return 0
  fi

  mkdir -p "$(dirname "$DOT_CACHE")"
  log "Clonando $DOT_REPO -> $DOT_CACHE"
  git clone --depth 1 "$DOT_REPO" "$DOT_CACHE"
}

dot_install_home_files() {
  local rel_src="$1"
  shift
  local files=("$@")
  local src_dir="$DOT_CACHE/$rel_src"
  local file src dest

  dot_ensure_repo

  if [[ ! -d "$src_dir" ]]; then
    fail "Origem não encontrada: $src_dir"
  fi

  for file in "${files[@]}"; do
    src="$src_dir/$file"
    dest="$HOME/$file"
    if [[ ! -f "$src" ]]; then
      fail "Arquivo não encontrado: $src"
    fi
    dot_backup_path "$dest"
    cp -a "$src" "$dest"
    ok "Copiado: $dest"
  done
}

dot_install_bin() {
  local src="$DOT_CACHE/dotfiles/bin/.bin"
  local dest="$HOME/.bin"

  dot_ensure_repo

  if [[ ! -d "$src" ]]; then
    fail "Origem não encontrada: $src"
  fi

  dot_backup_path "$dest"
  mkdir -p "$(dirname "$dest")"
  dot_copy_tree "$src" "$dest"
  find "$dest" -type f -exec chmod +x {} + 2>/dev/null || true
  ok "Instalado: $dest ($(find "$dest" -maxdepth 1 -type f | wc -l) scripts)"
}

dot_install_home_files "dotfiles/bash" \
  ".aliases" \
  ".aliases-arch" \
  ".aliases-debian" \
  ".aliases-fedora" \
  ".aliases-nixos" \
  ".aliases-opensuse" \
  ".aliases-solus" \
  ".bash_profile" \
  ".functions"

# .bashrc vendido (starship nord ativo) — embutido para script standalone
BASHRC_DEST="$HOME/.bashrc"
dot_backup_path "$BASHRC_DEST"
cat > "$BASHRC_DEST" <<'BASHRC_EOF'
# ~/.bashrc
# Configuração principal do Bash

# ============================================================
# SOMENTE SHELL INTERATIVO
# ============================================================
 [[ $- != *i* ]] && return


# ============================================================
# BASH COMPLETION
# Pacote: bash-completion
# ============================================================
if [[ -f /usr/share/bash-completion/bash_completion ]]; then
    . /usr/share/bash-completion/bash_completion
fi


# ============================================================
# PATH
# ============================================================
case ":$PATH:" in
    *":$HOME/.bin:"*) ;;
    *) export PATH="$HOME/.bin:$PATH" ;;
esac

case ":$PATH:" in
    *":$HOME/.local/bin:"*) ;;
    *) export PATH="$HOME/.local/bin:$PATH" ;;
esac
# ============================================================
# FUNÇÕES
# ============================================================

# Carrega funções
[[ -f "$HOME/.functions" ]] && . "$HOME/.functions"


# Detecta distro depois de carregar as funções
DISTRO="$(detect_distro)"


# ============================================================
# ALIASES
# ============================================================

# Aliases comuns
[[ -f "$HOME/.aliases" ]] && . "$HOME/.aliases"
[[ -f "$HOME/.aliases.sh" ]] && . "$HOME/.aliases.sh"

# Aliases especifícos da distro
case "$DISTRO" in
    arch)
        [[ -f "$HOME/.aliases-arch" ]] && . "$HOME/.aliases-arch"
        ;;
    debian)
        [[ -f "$HOME/.aliases-debian" ]] && . "$HOME/.aliases-debian"
        ;;
    nixos)
        [[ -f "$HOME/.aliases-nixos" ]] && . "$HOME/.aliases-nixos"
        ;;
    fedora)
        [[ -f "$HOME/.aliases-fedora" ]] && . "$HOME/.aliases-fedora"
        ;;
    opensuse)
        [[ -f "$HOME/.aliases-opensuse" ]] && . "$HOME/.aliases-opensuse"
        ;;
    solus)
        [[ -f "$HOME/.aliases-solus" ]] && . "$HOME/.aliases-solus"
        ;;
    unknown)
        # Descomente para debug:
        # echo "[AVISO] Distro não reconhecida."
        ;;
esac

# Debug opcional
# echo "[INFO] Distro detectada: $DISTRO"

# ============================================================
# HISTÓRICO
# ============================================================
export HISTFILESIZE=10000
export HISTSIZE=10000
export HISTTIMEFORMAT="%F %T "
export HISTCONTROL=erasedups:ignoredups:ignorespace

shopt -s histappend
shopt -s checkwinsize

# Salva histórico da sessão e lê histórico da sessão novo de outros terminais
PROMPT_COMMAND="history -a; history -n${PROMPT_COMMAND:+; $PROMPT_COMMAND}"


# ============================================================
# PROMPT / FERRAMENTAS INTERATIVAS
# ============================================================

# ====================== STARSHIP CONFIG ======================

# Escolha qual configuração do Starship usar (descomente apenas uma)

# export STARSHIP_CONFIG="$HOME/.config/starship.toml"              # Padrão / Matugen
# export STARSHIP_CONFIG="$HOME/.config/starship-tokyo-night.toml" # Tokyo Night
export STARSHIP_CONFIG="$HOME/.config/starship-nord.toml"           # Nord

# ============================================================

if command -v starship >/dev/null 2>&1; then
    eval "$(starship init bash)"
fi

if command -v zoxide >/dev/null 2>&1; then
    eval "$(zoxide init bash)"
fi
BASHRC_EOF
ok "Copiado: $BASHRC_DEST (vendido — starship nord ativo)"

dot_install_bin