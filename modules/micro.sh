#!/usr/bin/env bash
# micro — instala o editor micro + tema Catppuccin Frappe
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/micro.sh)
set -euo pipefail

log() { printf "[*] %s\n" "$1"; }
ok() { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }

# ---------- Arch / base Arch ----------
is_arch_based() {
  [[ -f /etc/arch-release ]] && return 0
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID:-}:${ID_LIKE:-}" in
      arch*|*:arch*|cachyos*|manjaro*|endeavouros*|garuda*)
        return 0
        ;;
    esac
  fi
  return 1
}

is_arch_based || fail "Não é base Arch — script ignorado."

MICRO_REPO="${MICRO_REPO:-https://github.com/catppuccin/micro}"
MICRO_RAW="https://raw.githubusercontent.com/catppuccin/micro/main"
MICRO_CONFIG="$HOME/.config/micro"
COLORSCHEMES_DIR="$MICRO_CONFIG/colorschemes"

# ---------- micro ----------
if command -v micro >/dev/null 2>&1; then
  ok "micro já instalado: $(command -v micro)"
else
  log "Instalando micro via pacman..."
  sudo pacman -S --needed --noconfirm micro \
    || fail "Falha ao instalar o micro."
  ok "micro instalado."
fi

# ---------- Tema Catppuccin Frappe ----------
install_theme() {
  local file="$1"
  local dest="$COLORSCHEMES_DIR/$file"
  mkdir -p "$COLORSCHEMES_DIR"
  if curl -fsSL "$MICRO_RAW/themes/$file" -o "$dest"; then
    ok "Tema instalado: $dest"
  else
    warn "Falha ao baixar o tema $file de $MICRO_REPO."
    rm -f "$dest"
  fi
}

log "Baixando tema Catppuccin Frappe de $MICRO_REPO..."
install_theme "catppuccin-frappe.micro"
install_theme "catppuccin-frappe-transparent.micro"

# ---------- settings.json ----------
set_colorscheme() {
  local settings="$MICRO_CONFIG/settings.json"
  mkdir -p "$MICRO_CONFIG"
  if [[ ! -f "$settings" ]]; then
    printf '{\n  "colorscheme": "catppuccin-frappe"\n}\n' > "$settings"
    ok "settings.json criado com colorscheme catppuccin-frappe"
    return 0
  fi
  if grep -q '"colorscheme"' "$settings"; then
    if grep -q '"colorscheme"[[:space:]]*:[[:space:]]*"catppuccin-frappe"' "$settings"; then
      ok "colorscheme catppuccin-frappe já configurado."
    else
      warn "settings.json já define outro colorscheme — não alterei. Ajuste para \"catppuccin-frappe\" se desejar."
    fi
    return 0
  fi
  if command -v python3 >/dev/null 2>&1; then
    python3 - "$settings" <<'PY'
import json, sys
p = sys.argv[1]
with open(p) as f:
    data = json.load(f)
data["colorscheme"] = "catppuccin-frappe"
with open(p, "w") as f:
    json.dump(data, f, indent=2)
    f.write("\n")
PY
    ok "colorscheme catppuccin-frappe definido em settings.json"
  else
    warn "python3 ausente — adicione \"colorscheme\": \"catppuccin-frappe\" em $settings."
  fi
}

set_colorscheme

ok "micro + tema Catppuccin Frappe concluído"
