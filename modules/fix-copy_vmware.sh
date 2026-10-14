#!/usr/bin/env bash
# Autostart do VMware User Agent (copiar/colar no guest via GDK_BACKEND=x11)
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/fix-copy_vmware.sh)

set -euo pipefail

dest_dir="${HOME}/.config/autostart"
dest="${dest_dir}/vmware-user.desktop"

mkdir -p "$dest_dir"

cat > "$dest" <<'EOF'
[Desktop Entry]
Type=Application
Exec=env GDK_BACKEND=x11 /usr/bin/vmware-user-suid-wrapper
Name=VMware User Agent
NoDisplay=true
X-KDE-autostart-phase=1
X-GNOME-Autostart-enabled=true
EOF

chmod 644 "$dest"
printf 'Arquivo criado: %s\n' "$dest"
