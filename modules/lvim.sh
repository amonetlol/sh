#!/usr/bin/env bash
# lvim — StratVIM ajustado (repo amonetlol/lvim) → ~/.config/stratvim, comando `lvim` (NVIM_APPNAME=stratvim).
# Não mexe no ~/.config/nvim. Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/lvim.sh)
set -euo pipefail

LVIM_REPO="${LVIM_REPO:-https://github.com/amonetlol/lvim.git}"
DEST="$HOME/.config/stratvim"
BIN="$HOME/.local/bin"

log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }

command -v git >/dev/null 2>&1 || { echo "[ERRO] git não encontrado" >&2; exit 1; }
if ! command -v nvim >/dev/null 2>&1; then
  warn "nvim não encontrado — instalando via pacman (Arch-based)"
  sudo pacman -S --needed --noconfirm neovim git base-devel ripgrep fd nodejs npm
fi

if [[ -e "$DEST" || -L "$DEST" ]]; then
  b="${DEST}.bak-$(date +%Y%m%d-%H%M%S)"; log "Backup: $DEST -> $b"; mv "$DEST" "$b"
fi
log "Clonando $LVIM_REPO"
git clone --depth 1 "$LVIM_REPO" "$DEST"

mkdir -p "$BIN"
printf '#!/usr/bin/env bash\nNVIM_APPNAME=stratvim exec nvim "$@"\n' > "$BIN/lvim"
chmod +x "$BIN/lvim"
ok "Comando: $BIN/lvim"

log "Instalando plugins (headless)..."
NVIM_APPNAME=stratvim timeout 400 nvim --headless "+Lazy! sync" +qa >/dev/null 2>&1 || warn "sync não terminou: abra 'lvim' e rode :Lazy sync"
case ":$PATH:" in *":$BIN:"*) ;; *) warn "adicione $BIN ao PATH (export PATH=\"\$HOME/.local/bin:\$PATH\")";; esac
ok "lvim instalado. Rode: lvim"
