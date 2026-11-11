#!/usr/bin/env bash
# Compatibilidade com o nome anterior; prepara ff e ffd sem anexar.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
script="$here/tmux-attach-ff_ffd.sh"
if [[ -f "$script" ]]; then exec bash "$script" "$@"; fi
command -v curl >/dev/null || { echo '[ERRO] curl ausente.' >&2; exit 1; }
work="$(mktemp)"
trap 'rm -f -- "$work"' EXIT
curl -fsSL --retry 3 https://raw.githubusercontent.com/amonetlol/sh/main/modules/tmux-attach-ff_ffd.sh -o "$work"
bash "$work" "$@"
