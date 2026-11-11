#!/usr/bin/env bash
# Acompanhamento geral e por distro no socket padrao do tmux.
# Ex.: bash tmux-attach-ff_ffd.sh fedora debian; depois escolha ff, ffd ou term-hub.
set -euo pipefail
umask 077
SESSION="${FF_SESSION:-ff}"
DISTRO_SESSION="${FF_DISTRO_SESSION:-ffd}"
LOG_INSTALL="${FF_LOG_INSTALL:-/tmp/ff-install.log}"
LOG_SCRIPTS="${FF_LOG_SCRIPTS:-/tmp/ff-scripts.log}"
LOG_DOWNLOADS="${FF_LOG_DOWNLOADS:-/tmp/ff-downloads.log}"
log() { printf '[*] %s\n' "$1"; }
fail() { printf '[ERRO] %s\n' "$1" >&2; exit 1; }
for dependency in tmux tail; do
  command -v "$dependency" >/dev/null 2>&1 || fail "Dependencia ausente: $dependency."
done
# Mesmo se chamado dentro do term-hub, usar o socket padrao do tmux.
tmux_default() { env -u TMUX tmux "$@"; }
create_log() { [[ -e "$1" ]] || : > "$1"; }
tail_command() { printf 'tail -f %q' "$1"; }
window_exists() {
  local session="$1" window="$2"
  tmux_default list-windows -t "=$session" -F '#{window_name}' | grep -Fxq -- "$window"
}
for distro in "$@"; do
  [[ "$distro" =~ ^[[:alnum:]][[:alnum:]_.-]*$ ]] || fail "Nome de distro invalido: $distro"
  [[ "$distro" != install && "$distro" != scripts && "$distro" != downloads ]] || fail "Nome reservado: $distro"
  create_log "/tmp/ff-$distro.log"
done
for logfile in "$LOG_INSTALL" "$LOG_SCRIPTS" "$LOG_DOWNLOADS"; do create_log "$logfile"; done
if ! tmux_default has-session -t "=$SESSION" 2>/dev/null; then
  tmux_default new-session -d -s "$SESSION" -n install "$(tail_command "$LOG_INSTALL")"
fi
for item in "scripts:$LOG_SCRIPTS" "downloads:$LOG_DOWNLOADS"; do
  name="${item%%:*}"; path="${item#*:}"
  if ! window_exists "$SESSION" "$name"; then
    tmux_default new-window -d -t "$SESSION:" -n "$name" "$(tail_command "$path")"
  fi
done
shopt -s nullglob
logs=()
for logfile in /tmp/ff-*.log; do
  case "${logfile##*/}" in ff-install.log|ff-scripts.log|ff-downloads.log) continue ;; esac
  [[ -f "$logfile" ]] && logs+=("$logfile")
done
if ! tmux_default has-session -t "=$DISTRO_SESSION" 2>/dev/null; then
  if ((${#logs[@]})); then
    name="${logs[0]##*/ff-}"; name="${name%.log}"
    tmux_default new-session -d -s "$DISTRO_SESSION" -n "$name" "$(tail_command "${logs[0]}")"
  else
    tmux_default new-session -d -s "$DISTRO_SESSION" -n aguardando \
      'printf "Nenhum log de distro. Execute o script com os nomes das distros.\\n"; exec tail -f /dev/null'
    tmux_default set-window-option -t "$DISTRO_SESSION:aguardando" @ff_hub_waiting 1
  fi
fi
for logfile in "${logs[@]}"; do
  name="${logfile##*/ff-}"; name="${name%.log}"
  if ! window_exists "$DISTRO_SESSION" "$name"; then
    tmux_default new-window -d -t "$DISTRO_SESSION:" -n "$name" "$(tail_command "$logfile")"
  fi
done
if ((${#logs[@]})) && window_exists "$DISTRO_SESSION" aguardando; then
  waiting=$(tmux_default display-message -p -t "$DISTRO_SESSION:aguardando" '#{@ff_hub_waiting}:#{pane_current_command}')
  if [[ "$waiting" == 1:tail ]]; then tmux_default kill-window -t "$DISTRO_SESSION:aguardando"; fi
fi
log "Logs gerais: tmux attach -t $SESSION"
log "Logs por distro: tmux attach -t $DISTRO_SESSION"
