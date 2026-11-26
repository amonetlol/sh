#!/usr/bin/env bash
# apps-cleanup.sh — aplica 0-default-remove_and_hide.txt (universal, sem referência a distro).
#   bash apps-cleanup.sh hide      -> seção 1: oculta (NoDisplay=true em ~/.local/share/applications) + seção 4 (renomear)
#   bash apps-cleanup.sh dry-run   -> seção 2: lista pacotes instalados que seriam removidos (pacman -Rp), NÃO remove
#   bash apps-cleanup.sh ask       -> seção 6: gera 0-ask-remove_or_hide_or_untouched.txt (sobrescreve) com o que está visível e sem regra
# Log: /tmp/ff-apps-cleanup.log
set -uo pipefail
LOG=/tmp/ff-apps-cleanup.log; log(){ echo "[$(date +%T)] $*" | tee -a "$LOG"; }
APPS=/usr/share/applications; USR="$HOME/.local/share/applications"; mkdir -p "$USR"
ASKFILE="${ASKFILE:-$HOME/0-ask-remove_or_hide_or_untouched.txt}"

# ids (nome do .desktop sem .desktop) ou Name= exatos
HIDE=(avahi-discover picom assistant qdbusviewer linguist qv4l2 qvidcap designer rofi rofi-theme-selector vim xcalib btop
 "Print Settings" FontForge "PIM Data Exporter" "Xwayland Video Bridge" micro nvim htop qt5ct qt6ct bssh bvnc cups lstopo xgps xgpsspeed
 CMake "Btrfs Assistant" "CachyOS Hello" yad-icon-browser yad-settings garuda-system-maintenance-settings garuda-toolbox reboot-to-uefi
 setup-assistant snapper-tools suspend-then-hibernate org.gnome.Vte.App.Gtk3 org.gnome.Vte.App.Gtk4 org.gtk.gtk4.NodeEditor
 org.gtk.PrintEditor4 vulkanCapsViewer ca.desrt.dconf-editor gpa org.freedesktop.IBus.Setup org.gtk.Demo4 org.gtk.WidgetFactory4
 wpa_gui fcitx5-configtool org.manjaro.pamac.manager application-utility manjaro-settings-manager msm_notifier_settings
 stoken-gui stoken-gui-small gtk-lshw org.gnome.Firmware gnome-printers-panel display-im7.q16 gnome-language-selector slicksddm-customize foot-server footclient networkmanager_dmenu org.cachyos.scx-manager)
NOTOUCH=(alacritty Alacritty com.mitchellh.ghostty Ghostty foot Foot nwg-look "GTK Settings" org.gnome.Loupe org.gnome.Papers kitty blueman-adapters blueman-manager mplayer mpv org.pulseaudio.pavucontrol nm-connection-editor nautilus org.gnome.Nautilus firefox nomachine nvidia-settings org.flameshot.Flameshot org.gnome.Evince org.gnome.FileRoller vlc io.github.celluloid_player.Celluloid org.gnome.TextEditor org.mozilla.firefox blend-settings com.saivert.pwvucontrol)
REMOVE_PKGS=(kaddressbook kontact ktorrent okular kleopatra kwrite filelight partitionmanager gimp strawberry kcalc konsole
 libreoffice-fresh libreoffice-still kmail kmail-account-wizard korganizer libktnef krfb audacious audacious-plugins simplescreenrecorder
 ddd distcc easytag eboard xboard gnuchess cdrdao gftp gkrellm gparted gucharmap gvim hexchat qalculate-qt qalculate-gtk joe lftp geeqie
 glade pan pidgin rxvt-unicode seamonkey soma thunderbird xterm xaos xine-ui xmms xpaint xpdf xsane xscreensaver xsnow xinput_calibrator
 nmap hplip konversation octopi cachyos-packageinstaller meld)

field(){ grep -m1 "^$2=" "$1" 2>/dev/null | cut -d= -f2-; }
find_desktop(){ # id|Name -> caminho
  local k=$1 f
  for f in "$APPS/$k.desktop" "$APPS/$k"; do [[ -f $f ]] && { echo "$f"; return; }; done
  grep -lx "Name=$k" "$APPS"/*.desktop 2>/dev/null | head -1
}
match_any(){ local id=$1 name=$2 k; shift 2; for k in "$@"; do [[ $id == "$k" || $name == "$k" ]] && return 0; done; return 1; }

hide_one(){ local src=$1 dst="$USR/$(basename "$1")"
  [[ -f $dst ]] || cp "$src" "$dst"
  if grep -q '^NoDisplay=' "$dst"; then sed -i 's/^NoDisplay=.*/NoDisplay=true/' "$dst"; else sed -i '0,/^\[Desktop Entry\]/s//[Desktop Entry]\nNoDisplay=true/' "$dst"; fi
}

mode=${1:-hide}
case $mode in
hide)
  n=0
  for k in "${HIDE[@]}"; do f=$(find_desktop "$k"); [[ -z $f ]] && continue
    id=$(basename "$f" .desktop); name=$(field "$f" Name)
    match_any "$id" "$name" "${NOTOUCH[@]}" && { log "pulado (NÃO_MEXER): $id"; continue; }
    hide_one "$f"; log "oculto: $id ($name)"; n=$((n+1))
  done
  # seção 4: renomear
  for pair in "org.gnome.Nautilus|Nautilus" "org.gnome.Files|Nautilus" "firefox|Firefox" "thunar|Thunar"; do
    id=${pair%%|*}; new=${pair##*|}; f="$APPS/$id.desktop"; [[ -f $f ]] || continue
    dst="$USR/$id.desktop"; [[ -f $dst ]] || cp "$f" "$dst"
    sed -i "s/^Name=.*/Name=$new/" "$dst"; log "renomeado: $id -> $new"
  done
  update-desktop-database "$USR" 2>/dev/null; log "hide: $n ocultados";;
dry-run)
  inst=(); for p in "${REMOVE_PKGS[@]}"; do pacman -Qq "$p" >/dev/null 2>&1 && inst+=("$p"); done
  if ((${#inst[@]}==0)); then log "dry-run: nenhum item da seção 2 instalado"; exit 0; fi
  log "dry-run: instalados da seção 2: ${inst[*]}"
  for p in "${inst[@]}"; do log "--- $p"; pacman -Rp "$p" 2>&1 | tail -n +1 | sed 's/^/    /' | tee -a "$LOG"; done
  log "dry-run: NADA foi removido. Remova só após confirmação explícita (pacman -R, sem -s).";;
ask)
  vis=()
  for f in "$APPS"/*.desktop; do
    id=$(basename "$f" .desktop); [[ -f "$USR/$id.desktop" ]] && grep -q '^NoDisplay=true' "$USR/$id.desktop" && continue
    grep -qE '^(NoDisplay|Hidden)=true' "$f" && continue
    grep -q '^Type=Application' "$f" || continue
    grep -qE '^OnlyShowIn=' "$f" && ! grep -qiE '^OnlyShowIn=.*(niri|sway|wlroots|GNOME|KDE)' "$f" && continue
    name=$(field "$f" Name)
    match_any "$id" "$name" "${HIDE[@]}" "${NOTOUCH[@]}" && continue
    vis+=("$id|$name")
  done
  {
    echo "====================================================================="
    echo "ASK - REMOVER, OCULTAR OU NÃO_MEXER"
    echo "====================================================================="
    echo "Responda em cada linha com uma opção:  H = ocultar (NoDisplay=true) | R = remover (dry-run antes) | N = não mexer | ? = ainda não sei"
    echo
    echo "A. VISÍVEIS NO LAUNCHER SEM REGRA (id — nome)"
    for v in "${vis[@]}"; do printf '  ?  %-45s %s\n' "${v%%|*}" "${v#*|}"; done
  } > "$ASKFILE"
  log "ask: ${#vis[@]} itens -> $ASKFILE";;
*) echo "uso: $0 hide|dry-run|ask"; exit 1;;
esac
