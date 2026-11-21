#!/usr/bin/env bash
# tlogs: tmux com os logs de instalação AO VIVO (/tmp/ff-install.log) de uma máquina remota via ssh
#        + painel local que só aparece durante instalação local + barra com o "term-hub status" do remoto.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/tlogs.sh) [host-ssh]
#      host-ssh (alias do ~/.ssh/config): padrão "pc"; fica em ~/.config/tlogs/host (troque quando quiser).
# Instala: ~/.local/bin/tmux-logs, ~/.local/bin/tmux-logs.ajuda (Ctrl+b ?) e alias tlogs no ~/.aliases (ou ~/.bashrc).
set -euo pipefail

RAW="${TLOGS_RAW:-https://raw.githubusercontent.com/amonetlol/sh/main/modules/tlogs}"
BIN="$HOME/.local/bin"
CFG="$HOME/.config/tlogs"

log()  { printf '[*] %s\n' "$1"; }
ok()   { printf '[OK] %s\n' "$1"; }
warn() { printf '[AVISO] %s\n' "$1"; }
fail() { printf '[ERRO] %s\n' "$1" >&2; exit 1; }

for d in tmux ssh less; do
  command -v "$d" >/dev/null 2>&1 || fail "dependência ausente: $d (instale antes)"
done
command -v curl >/dev/null 2>&1 || fail "dependência ausente: curl"
tmux_v=$(tmux -V | grep -oE '[0-9]+\.[0-9]+' | head -1)
awk -v v="$tmux_v" 'BEGIN{exit !(v>=3.2)}' || warn "tmux $tmux_v: o popup de ajuda (Ctrl+b ?) precisa do tmux 3.2+"

# arquivos: do clone local (se rodar de dentro do repo sh) ou do GitHub
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" 2>/dev/null && pwd || true)"
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
for f in tmux-logs tmux-logs.ajuda; do
  if [[ -n $here && -f "$here/tlogs/$f" ]]; then
    cp "$here/tlogs/$f" "$tmp/$f"
  else
    curl -fsSL --retry 3 "$RAW/$f" -o "$tmp/$f" || fail "download falhou: $RAW/$f"
  fi
done
sh -n "$tmp/tmux-logs" || fail "tmux-logs baixado está com erro de sintaxe"

mkdir -p "$BIN" "$CFG"
install -m755 "$tmp/tmux-logs" "$BIN/tmux-logs"
install -m644 "$tmp/tmux-logs.ajuda" "$BIN/tmux-logs.ajuda"
ok "instalado: $BIN/tmux-logs (+ tmux-logs.ajuda)"

host="${1:-${TLOGS_HOST:-}}"
if [[ -n $host ]]; then
  printf '%s\n' "$host" > "$CFG/host"
elif [[ ! -s $CFG/host ]]; then
  printf 'pc\n' > "$CFG/host"
fi
ok "host remoto: $(cat "$CFG/host")  (arquivo $CFG/host)"

rc="$HOME/.aliases"; [[ -f $rc ]] || rc="$HOME/.bashrc"
if ! grep -q "alias tlogs=" "$rc" 2>/dev/null; then
  printf "\n# tmux com os logs de instalação ao vivo (remoto via ssh + local sob demanda)\nalias tlogs='tmux-logs'\n" >> "$rc"
  ok "alias tlogs adicionado em $rc (abra um terminal novo ou: source $rc)"
else
  ok "alias tlogs já existe em $rc"
fi
case ":$PATH:" in *":$BIN:"*) ;; *) warn "$BIN não está no PATH";; esac
ssh -o BatchMode=yes -o ConnectTimeout=5 "$(cat "$CFG/host")" true 2>/dev/null \
  && ok "ssh $(cat "$CFG/host") sem senha: ok" \
  || warn "ssh $(cat "$CFG/host") sem senha falhou: configure chave/alias no ~/.ssh/config (o tlogs reconecta sozinho quando funcionar)"
ok "pronto: rode tlogs  ·  Ctrl+b ? mostra os atalhos"
