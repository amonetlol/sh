#!/usr/bin/env bash
# snapper — ajusta os limites de snapshots do snapper nas configs existentes
# (NUMBER_LIMIT e timeline). Não cria configs — só ajusta as de /etc/snapper/configs.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/snapper.sh)
set -euo pipefail

SNAPPER_LIMIT="${SNAPPER_LIMIT:-6}"

log()  { printf "[*] %s\n" "$*" >&2; }
ok()   { printf "[OK] %s\n" "$*" >&2; }
warn() { printf "[AVISO] %s\n" "$*" >&2; }
err()  { printf "[ERRO] %s\n" "$*" >&2; }
die()  { err "$*"; exit 1; }

# sudo com suporte a INSTALL_SUDO_PASSWORD / SUDO_ASKPASS
sudo() {
  if [[ "${EUID:-$(id -u)}" -eq 0 ]]; then
    if [[ "$1" == "-S" || "$1" == "-A" || "$1" == "-n" || "$1" == "-v" ]]; then
      command sudo "$@"
    else
      command sudo -H "$@"
    fi
    return $?
  fi
  if [[ -n "${INSTALL_SUDO_PASSWORD:-}" ]]; then
    printf '%s\n' "$INSTALL_SUDO_PASSWORD" | command sudo -S "$@"
  elif [[ -n "${SUDO_ASKPASS:-}" ]]; then
    export DISPLAY="${DISPLAY:-:0}"
    command sudo -A "$@"
  else
    command sudo "$@"
  fi
}

# Grava ficheiro em path root sem heredoc+tee (sudo -S consome stdin).
sudo_write_file() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  cat >"$tmp"
  sudo mkdir -p "$(dirname "$dest")"
  sudo cp "$tmp" "$dest"
  rm -f "$tmp"
}

_snapper_set_kv() {
  local file="$1" key="$2" value="$3"
  if grep -qE "^${key}=" "$file"; then
    sudo sed -i "s/^${key}=.*/${key}=\"${value}\"/" "$file"
  else
    # append sem tee (stdin do sudo -S é a senha — nunca pipe de conteúdo)
    local tmp
    tmp="$(mktemp)"
    sudo cat "$file" > "$tmp"
    printf '%s="%s"\n' "$key" "$value" >> "$tmp"
    sudo_write_file "$file" < "$tmp"
    rm -f "$tmp"
  fi
}

configure_snapper_limits() {
  local limit="${1:-$SNAPPER_LIMIT}"

  if ! command -v snapper &>/dev/null; then
    warn "snapper não instalado — nada a fazer (instale o pacote 'snapper' e rode de novo)."
    return 0
  fi

  local configs=()
  if [[ -d /etc/snapper/configs ]]; then
    while IFS= read -r -d '' cfg; do
      configs+=("$cfg")
    done < <(find /etc/snapper/configs -maxdepth 1 -type f ! -name '.*' -print0 2>/dev/null)
  fi

  if [[ ${#configs[@]} -eq 0 ]]; then
    warn "Nenhuma config do snapper em /etc/snapper/configs — nada a fazer."
    return 0
  fi

  local config config_name
  for config in "${configs[@]}"; do
    [[ -f "$config" ]] || continue
    config_name="$(basename "$config")"
    log "Ajustando limites em ${config} (manter ${limit} snapshots)..."

    _snapper_set_kv "$config" NUMBER_CLEANUP yes
    _snapper_set_kv "$config" NUMBER_MIN_AGE 0
    _snapper_set_kv "$config" NUMBER_LIMIT "$limit"
    _snapper_set_kv "$config" NUMBER_LIMIT_IMPORTANT "$limit"

    # Zera a timeline quando ela estiver ativa (só snapshots de número)
    if grep -qE '^TIMELINE_CREATE="yes"' "$config" 2>/dev/null \
      || grep -qE '^TIMELINE_CLEANUP="yes"' "$config" 2>/dev/null; then
      _snapper_set_kv "$config" TIMELINE_CLEANUP yes
      _snapper_set_kv "$config" TIMELINE_LIMIT_HOURLY 0
      _snapper_set_kv "$config" TIMELINE_LIMIT_DAILY 0
      _snapper_set_kv "$config" TIMELINE_LIMIT_WEEKLY 0
      _snapper_set_kv "$config" TIMELINE_LIMIT_MONTHLY 0
      _snapper_set_kv "$config" TIMELINE_LIMIT_QUARTERLY 0
      _snapper_set_kv "$config" TIMELINE_LIMIT_YEARLY 0
    fi

    log "Rodando snapper cleanup para ${config_name}..."
    sudo snapper -c "$config_name" cleanup number 2>/dev/null \
      || warn "number cleanup falhou para ${config_name}"
    sudo snapper -c "$config_name" cleanup timeline 2>/dev/null || true

    ok "Limites do snapper ajustados em ${config_name}"
  done
}

configure_snapper_limits
ok "snapper finalizado (SNAPPER_LIMIT=${SNAPPER_LIMIT})"
