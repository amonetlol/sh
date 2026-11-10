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

ok 'Use ssh-hub ou term-hub em um terminal. Para acompanhar os logs: term-hub --ff (atalho Ctrl+b f). Novas instalacoes comecam sem credenciais.'
