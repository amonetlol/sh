#!/usr/bin/env bash
# SSH Hub e Term Hub: arquivos do repositorio amonetlol/dot.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/hub-ssh_term.sh)
set -euo pipefail
umask 077

DOT_REPO="${DOT_REPO:-https://github.com/amonetlol/dot.git}"
DOT_CACHE="${DOT_CACHE:-$HOME/.cache/base-dot-repo}"

log() { printf '[*] %s\n' "$1"; }
ok() { printf '[OK] %s\n' "$1"; }
warn() { printf '[AVISO] %s\n' "$1"; }
fail() { printf '[ERRO] %s\n' "$1" >&2; exit 1; }

for dependency in git python3 tmux ssh; do
  command -v "$dependency" >/dev/null 2>&1 || fail "Dependencia ausente: $dependency. Instale antes de executar este modulo."
done
command -v nvim >/dev/null 2>&1 || warn 'Neovim nao encontrado; o atalho e de edicao requer nvim.'

# O banco minimo de terminfo do openSUSE pode nao incluir tmux-256color.
if command -v zypper >/dev/null 2>&1 &&
   { ! command -v infocmp >/dev/null 2>&1 || ! infocmp tmux-256color >/dev/null 2>&1; }; then
  sudo zypper --non-interactive install --no-recommends terminfo ncurses-utils
fi
if command -v xbps-install >/dev/null 2>&1 &&
   { ! command -v infocmp >/dev/null 2>&1 || ! infocmp tmux-256color >/dev/null 2>&1; }; then
  sudo xbps-install -Sy ncurses-term
fi

# openSUSE distribui curses separadamente para cada versao do Python.
if ! python3 -c 'import curses' >/dev/null 2>&1; then
  if command -v zypper >/dev/null 2>&1; then
    python_version="$(python3 -c 'import sys; print(f"{sys.version_info.major}{sys.version_info.minor}")')"
    sudo zypper --non-interactive install --no-recommends "python${python_version}-curses"
  else
    fail 'O modulo curses do Python esta ausente; instale-o antes de usar term-hub.'
  fi
  python3 -c 'import curses' >/dev/null 2>&1 || fail 'Nao foi possivel carregar curses no Python.'
fi

if [[ -d "$DOT_CACHE/.git" ]]; then
  log "Atualizando cache dot: $DOT_CACHE"
  git -C "$DOT_CACHE" pull --ff-only || warn 'git pull falhou; usando cache local.'
else
  [[ ! -e "$DOT_CACHE" ]] || fail "O cache existe e nao e um clone Git: $DOT_CACHE"
  mkdir -p "$(dirname "$DOT_CACHE")"
  git clone --depth 1 "$DOT_REPO" "$DOT_CACHE"
fi

# Verificar ambas as origens antes de modificar qualquer instalacao.
for hub in ssh-hub term-hub; do
  source_bin="$DOT_CACHE/dotfiles/$hub/.local/bin"
  for file in "$hub" "$hub.d/hub.py" "$hub.d/connections.py" "$hub.d/tmux.conf" "$hub.d/ssh.conf" "$hub.d/ssh-askpass"; do
    [[ -f "$source_bin/$file" ]] || fail "Arquivo ausente no repo dot: $source_bin/$file"
  done
done
[[ -f "$DOT_CACHE/dotfiles/term-hub/.local/bin/term-hub.d/log_picker.py" ]] || fail 'Seletor de logs do term-hub ausente no repo dot.'

mkdir -p "$HOME/.local/bin"
stamp="$(date +%Y%m%d-%H%M%S)-$$"
for hub in ssh-hub term-hub; do
  source_bin="$DOT_CACHE/dotfiles/$hub/.local/bin"
  target="$HOME/.local/bin/$hub.d"
  launcher="$HOME/.local/bin/$hub"
  backup="$HOME/.local/state/hub-ssh_term/backups/$stamp/$hub"

  if [[ -e "$target" || -L "$target" || -e "$launcher" || -L "$launcher" ]]; then
    mkdir -p "$backup"
    # Copiar os campos preenchidos antes de mover links ou pastas existentes.
    if [[ -f "$target/ssh.conf" ]]; then
      install -m 600 "$target/ssh.conf" "$backup/ssh.conf.saved"
    fi
    if [[ -e "$target" || -L "$target" ]]; then mv "$target" "$backup/$hub.d"; fi
    if [[ -e "$launcher" || -L "$launcher" ]]; then mv "$launcher" "$backup/$hub"; fi
    log "Backup: $backup"
  fi

  mkdir -p "$target"
  cp -a "$source_bin/$hub.d/." "$target/"
  install -m 755 "$source_bin/$hub" "$launcher"
  # Repositorios obtidos no Windows podem conter CRLF.
  find "$target" -type f -exec sed -i 's/\r$//' {} +
  if [[ -f "$backup/ssh.conf.saved" ]]; then
    install -m 600 "$backup/ssh.conf.saved" "$target/ssh.conf"
  fi
  chmod 755 "$target/ssh-askpass"
  chmod 700 "$target"
  chmod 600 "$target/ssh.conf"
  ok "$hub instalado; campos em $target/ssh.conf"
done


# Disponibiliza o preparador das duas sessoes junto dos launchers.
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
ff_script="$here/tmux-attach-ff_ffd.sh"
if [[ -f "$ff_script" ]]; then
  install -m 755 "$ff_script" "$HOME/.local/bin/tmux-attach-ff_ffd.sh"
else
  command -v curl >/dev/null 2>&1 || fail 'curl ausente para baixar o preparador de logs.'
  temp_ff="$(mktemp)"
  if ! curl -fsSL --retry 3 https://raw.githubusercontent.com/amonetlol/sh/main/modules/tmux-attach-ff_ffd.sh -o "$temp_ff"; then
    rm -f -- "$temp_ff"
    fail 'Nao foi possivel baixar o preparador de logs.'
  fi
  install -m 755 "$temp_ff" "$HOME/.local/bin/tmux-attach-ff_ffd.sh"
  rm -f -- "$temp_ff"
fi
ok 'Preparador instalado: ~/.local/bin/tmux-attach-ff_ffd.sh'

ok 'Use Ctrl+b l para selecionar logs, Ctrl+b N para novo grupo e Ctrl+b Q para encerrar o servidor dedicado. Para criar ff e ffd: tmux-attach-ff_ffd.sh DISTRO1 DISTRO2.'
