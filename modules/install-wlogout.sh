#!/usr/bin/env bash
set -euo pipefail

readonly GOODIES_REPO="amonetlol/goodies"
readonly SH_REPO="amonetlol/sh"
readonly REPO_REF="main"

fail() {
  printf '[ERRO] %s\n' "$*" >&2
  exit 1
}

for command_name in curl python3; do
  command -v "$command_name" >/dev/null 2>&1 || fail "Comando necessario nao encontrado: $command_name"
done

workdir=$(mktemp -d "${TMPDIR:-/tmp}/install-wlogout.XXXXXX")
config_stage="$workdir/wlogout-01"
config_dir="$HOME/.config/wlogout"
backup_path=""
bin_stage=""
config_installed=0

cleanup() {
  local status=$?
  trap - EXIT
  if (( status != 0 )); then
    if [[ -n "$bin_stage" ]]; then
      rm -f -- "$bin_stage" || true
    fi
    if (( config_installed )) && [[ -e "$config_dir" || -L "$config_dir" ]]; then
      rm -rf -- "$config_dir" || true
    fi
    if [[ -n "$backup_path" && ( -e "$backup_path" || -L "$backup_path" ) && ! -e "$config_dir" && ! -L "$config_dir" ]]; then
      mv -- "$backup_path" "$config_dir" || true
    fi
  fi
  rm -rf -- "$workdir" || true
  exit "$status"
}
trap cleanup EXIT

mkdir -p "$config_stage"

python3 - "$GOODIES_REPO" "$REPO_REF" "$config_stage" <<'PY'
import json
import sys
import urllib.request
from pathlib import Path

repo, ref, destination = sys.argv[1:]
destination = Path(destination)
headers = {
    "Accept": "application/vnd.github+json",
    "User-Agent": "amonetlol-install-wlogout",
}

def fetch(url):
    request = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read()

def download_directory(api_path):
    url = f"https://api.github.com/repos/{repo}/contents/{api_path}?ref={ref}"
    entries = json.loads(fetch(url))
    if not isinstance(entries, list):
        raise RuntimeError(f"Resposta inesperada da API para {api_path}")
    for entry in entries:
        item_path = entry["path"]
        if not item_path.startswith("wlogout-01/"):
            raise RuntimeError(f"Caminho fora de wlogout-01: {item_path}")
        relative = Path(*item_path.split("/")[1:])
        if not relative.parts or any(part in ("", ".", "..") for part in relative.parts):
            raise RuntimeError(f"Caminho invalido no repositorio: {item_path}")
        target = destination / relative
        if entry["type"] == "dir":
            target.mkdir(parents=True, exist_ok=True)
            download_directory(item_path)
        elif entry["type"] == "file":
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(fetch(entry["download_url"]))
        else:
            raise RuntimeError(f"Tipo de arquivo nao suportado: {entry['type']} ({item_path})")

download_directory("wlogout-01")
PY

for required_file in layout style.css launch.sh session-action.sh icons/lock.png icons/logout.png icons/suspend.png icons/hibernate.png icons/shutdown.png icons/reboot.png; do
  [[ -s "$config_stage/$required_file" ]] || fail "Arquivo nao encontrado no wlogout-01: $required_file"
done

launcher_url="https://raw.githubusercontent.com/$SH_REPO/$REPO_REF/modules/wlogout"
curl -fsSL --retry 3 "$launcher_url" -o "$workdir/wlogout"
bash -n "$workdir/wlogout"
bash -n "$config_stage/launch.sh"
bash -n "$config_stage/session-action.sh"
chmod +x "$config_stage/launch.sh" "$config_stage/session-action.sh"

mkdir -p "$HOME/.config" "$HOME/.local/bin"
bin_stage="$HOME/.local/bin/.wlogout.install.$$"
install -m 0755 "$workdir/wlogout" "$bin_stage"

if [[ -e "$config_dir" || -L "$config_dir" ]]; then
  backup_path="${config_dir}.backup-$(date +%Y%m%d-%H%M%S)"
  if [[ -e "$backup_path" || -L "$backup_path" ]]; then
    backup_path="${backup_path}-$$"
  fi
  [[ ! -e "$backup_path" && ! -L "$backup_path" ]] || fail "Destino de backup ja existe: $backup_path"
  mv -- "$config_dir" "$backup_path"
  printf '[OK] Backup criado: %s\n' "$backup_path"
fi

mv -- "$config_stage" "$config_dir"
config_installed=1
mv -f -- "$bin_stage" "$HOME/.local/bin/wlogout"
bin_stage=""

printf '[OK] Configuracao instalada em %s\n' "$config_dir"
printf '[OK] Launcher instalado em %s\n' "$HOME/.local/bin/wlogout"
