#!/usr/bin/env bash
# shot — capturas de tela (grim/slurp) para ~/Imagens/Screenshots + clipboard
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/shot.sh)
# (copiado de amonetlol/custom — Screenshots movido para ~/Imagens/Screenshots)
set -euo pipefail

time=$(date +%Y-%m-%d-%H-%M-%S)
dir="${HOME}/Imagens/Screenshots"
file="Screenshot_${time}_${RANDOM}.png"
[[ -d "$dir" ]] || mkdir -p "$dir"

# ============================================================
# DEPENDÊNCIAS NECESSÁRIAS (instale antes de usar):
#
#   Arch:      sudo pacman -S grim slurp wl-clipboard libnotify pipewire viewnior
#   Fedora:    sudo dnf install grim slurp wl-clipboard libnotify pipewire-utils viewnior
#   Ubuntu:    sudo apt install grim slurp wl-clipboard libnotify-bin pipewire-utils viewnior
#
#   grim        — captura de tela (Wayland)
#   slurp       — seleção de área
#   wl-clipboard — wl-copy (copia para o clipboard)
#   libnotify   — notify-send (notificações)
#   pipewire    — paplay (som de captura); alternativa: pulseaudio
#   viewnior    — opcional, abre o screenshot após capturar
#                 (se ausente, o script apenas notifica, sem abrir o arquivo)
#
#   Obs.: --shotwin requer Hyprland (hyprctl) para obter a janela ativa.
# ============================================================

show_help() {
  cat <<EOF
Uso: $(basename "$0") [OPÇÃO]

Captura screenshots e salva em: $dir

Opções:
  --shotnow    Captura a tela inteira imediatamente
  --shotarea   Seleciona uma região da tela para capturar
  --shotwin    Captura a janela ativa no momento
  --shot5      Captura a tela inteira após contagem de 5 segundos
  --shot10     Captura a tela inteira após contagem de 10 segundos
  -h, --help   Exibe esta mensagem de ajuda

Execute sem argumentos para exibir esta ajuda.
EOF
}

notify_view() {
  notify-send -u low 'Copied to clipboard.' 2>/dev/null || true
  paplay /usr/share/sounds/freedesktop/stereo/screen-capture.oga &>/dev/null || true
  command -v viewnior >/dev/null && viewnior "$dir/$file" &
  [[ -e "$dir/$file" ]] && notify-send -u low 'Screenshot saved.' || notify-send -u low 'Screenshot deleted.'
}

countdown() {
  for sec in $(seq "$1" -1 1); do
    notify-send -t 1000 "Taking shot in: $sec"
    sleep 1
  done
}

shotnow() {
  sleep 0.5 && grim - | tee "$dir/$file" | wl-copy
  notify_view
}

shot5() {
  countdown 5
  sleep 1 && grim - | tee "$dir/$file" | wl-copy
  notify_view
}

shot10() {
  countdown 10
  sleep 1 && grim - | tee "$dir/$file" | wl-copy
  notify_view
}

shotwin() {
  w_pos=$(hyprctl activewindow | grep 'at:' | cut -d':' -f2 | tr -d ' ' | tail -n1)
  w_size=$(hyprctl activewindow | grep 'size:' | cut -d':' -f2 | tr -d ' ' | tail -n1 | sed 's/,/x/g')
  sleep 0.3 && grim -g "$w_pos $w_size" - | tee "$dir/$file" | wl-copy
  notify_view
}

shotarea() {
  grim -g "$(slurp -w 2 && sleep 0.3)" - | tee "$dir/$file" | wl-copy
  notify_view
}

if [[ $# -eq 0 ]]; then
  show_help
  exit 0
fi

case "$1" in
  --shotnow)  shotnow ;;
  --shotarea) shotarea ;;
  --shotwin)  shotwin ;;
  --shot5)    shot5 ;;
  --shot10)   shot10 ;;
  -h|--help)  show_help ;;
  *)
    echo "Unknown option: $1" >&2
    echo >&2
    show_help >&2
    exit 1
    ;;
esac