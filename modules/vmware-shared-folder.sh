#!/usr/bin/env bash
# vmware-shared-folder — monta pasta compartilhada do VMware (HGFS) de forma persistente
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/vmware-shared-folder.sh)
#
# Variáveis (override): SHARE_NAME (default SERVER), MOUNT_POINT (default /mnt/hgfs/SERVER),
#                       AUTO_YES=1 (não pergunta se já houver entrada no fstab)
set -euo pipefail

# Configurações - altere via env se necessário
SHARE_NAME="${SHARE_NAME:-SERVER}"
MOUNT_POINT="${MOUNT_POINT:-/mnt/hgfs/${SHARE_NAME}}"
UID_TO_USE="${UID_TO_USE:-$(id -u)}"
GID_TO_USE="${GID_TO_USE:-$(id -g)}"
FSTAB_LINE=".host:/${SHARE_NAME} ${MOUNT_POINT} fuse.vmhgfs-fuse allow_other,uid=${UID_TO_USE},gid=${GID_TO_USE},umask=0022,defaults 0 0"

log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
err()  { printf "[ERRO] %s\n" "$1" >&2; }
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

# Append stdin to root-owned file (evita sudo tee + senha no stdin)
sudo_append_to_file() {
  local dest="$1"
  local tmp
  tmp="$(mktemp)"
  if sudo test -f "$dest" 2>/dev/null; then
    sudo cat "$dest" >"$tmp"
  fi
  cat >>"$tmp"
  sudo cp "$tmp" "$dest"
  rm -f "$tmp"
}

log "Configurando montagem persistente do compartilhamento VMware: ${SHARE_NAME}"

# Pré-checagem: vmhgfs-fuse precisa existir (open-vm-tools + fuse3)
if ! command -v vmhgfs-fuse &>/dev/null; then
  warn "vmhgfs-fuse não encontrado — instale open-vm-tools e fuse3 antes (módulo vmware)."
  warn "A entrada do fstab será adicionada mesmo assim (após instalar, 'sudo mount -a' monta)."
fi

# 1. Criar ponto de montagem (se não existir)
if [[ ! -d "$MOUNT_POINT" ]]; then
  log "Criando diretório: $MOUNT_POINT"
  sudo mkdir -p "$MOUNT_POINT"
else
  ok "Diretório $MOUNT_POINT já existe"
fi

# 2. Verificar se já existe entrada no fstab
if grep -qF ".host:/${SHARE_NAME}" /etc/fstab; then
  warn "Já existe uma linha com .host:/${SHARE_NAME} no /etc/fstab"
  log "Mostrando linhas relevantes:"
  grep ".host:/${SHARE_NAME}" /etc/fstab || true
  echo
  if [[ "${AUTO_YES:-0}" == "1" ]]; then
    log "AUTO_YES=1 — continuando e adicionando mesmo assim."
  else
    read -r -p "Deseja continuar e adicionar mesmo assim? (s/N): " resposta
    if [[ ! "${resposta:-}" =~ ^[sS]$ ]]; then
      log "Abortado pelo usuário."
      exit 1
    fi
  fi
fi

# 3. Adicionar ao fstab (com backup)
log "Fazendo backup do /etc/fstab → /etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"
sudo cp -f /etc/fstab "/etc/fstab.bak.$(date +%Y%m%d_%H%M%S)"

log "Adicionando ao /etc/fstab:"
echo "   $FSTAB_LINE"
printf '%s\n' "$FSTAB_LINE" | sudo_append_to_file /etc/fstab

# 4. Testar se o fstab está sintaticamente correto
log "Testando sintaxe do fstab..."
if ! sudo findmnt --verify --verbose; then
  err "Erro na sintaxe do /etc/fstab!"
  echo "Últimas 5 linhas do fstab:"
  tail -n 5 /etc/fstab
  echo
  echo "Você pode restaurar o backup com:"
  echo "  sudo cp /etc/fstab.bak.* /etc/fstab"
  exit 1
fi

# 5. Tentar montar tudo que está no fstab
log "Tentando montar todas as entradas do fstab..."
if sudo mount -a; then
  ok "Montagem realizada com sucesso"
else
  warn "Alguns mounts falharam (pode ser normal se outros já estavam montados)"
fi

# 6. Mostrar status
echo
log "Resultado atual:"
if mountpoint -q "$MOUNT_POINT"; then
  ok "$MOUNT_POINT está montado"
  df -hT "$MOUNT_POINT" | tail -n 1
  # Atalho na pasta HOME (idempotente)
  ln -sfn "$MOUNT_POINT" "$HOME/${SHARE_NAME}"
  ok "Atalho criado em ~/${SHARE_NAME}"
else
  warn "$MOUNT_POINT NÃO está montado"
  echo "Tente montar manualmente para ver o erro:"
  echo "  sudo mount \"$MOUNT_POINT\""
fi

echo
echo "Comandos úteis para debug:"
echo "  sudo umount \"$MOUNT_POINT\"          # desmontar"
echo "  sudo mount \"$MOUNT_POINT\"           # montar apenas este"
echo "  findmnt \"$MOUNT_POINT\"              # ver detalhes"
echo "  systemctl status vmtoolsd             # verificar serviço (se aplicável)"
echo
ok "Feito!"