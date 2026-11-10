#!/usr/bin/env bash
# FF Hub: sessao tmux com 3 janelas acompanhando os logs do FF.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/ff-hub.sh)
set -euo pipefail
umask 077

SESSION="${FF_SESSION:-ff}"
LOG_INSTALL="${FF_LOG_INSTALL:-/tmp/ff-install.log}"
LOG_SCRIPTS="${FF_LOG_SCRIPTS:-/tmp/ff-scripts.log}"
LOG_DOWNLOADS="${FF_LOG_DOWNLOADS:-/tmp/ff-downloads.log}"

log() { printf '[*] %s\n' "$1"; }
ok() { printf '[OK] %s\n' "$1"; }
warn() { printf '[AVISO] %s\n' "$1"; }
fail() { printf '[ERRO] %s\n' "$1" >&2; exit 1; }

for dependency in tmux tail; do
  command -v "$dependency" >/dev/null 2>&1 || fail "Dependencia ausente: $dependency. Instale antes de executar este modulo."
done

# Gerar os arquivos de log caso ainda nao existam, para o tail -f nao falhar.
for logfile in "$LOG_INSTALL" "$LOG_SCRIPTS" "$LOG_DOWNLOADS"; do
  if [[ ! -f "$logfile" ]]; then
    : > "$logfile"
    log "Log criado: $logfile"
  fi
done

# Sessao ja existe: apenas anexar a ela.
if tmux has-session -t "$SESSION" 2>/dev/null; then
  log "Sessao '$SESSION' ja existe; anexando."
  exec tmux attach-session -t "$SESSION"
fi

log "Criando sessao tmux '$SESSION' com 3 janelas."
tmux new-session -d -s "$SESSION" -n install "tail -f '$LOG_INSTALL'"
tmux new-window -t "$SESSION:" -n scripts "tail -f '$LOG_SCRIPTS'"
tmux new-window -t "$SESSION:" -n downloads "tail -f '$LOG_DOWNLOADS'"
tmux select-window -t "$SESSION:install"

ok "Sessao '$SESSION' pronta: install, scripts e downloads."
exec tmux attach-session -t "$SESSION"
