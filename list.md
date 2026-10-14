# Módulos standalone — instalação via curl + bash

Cada script é autossuficiente: baixe e execute em um único comando, sem clonar repositório.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/<script>.sh)
```

> `bash <(curl ...)` mantém o stdin do terminal livre — os prompts interativos
> (sudo, yay, confirmações) funcionam normalmente.

## Lista de módulos

### Base Arch
```bash
# pacotes_arch — yay/paru + pacotes essenciais (Arch, CachyOS e derivados)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_arch.sh)
```

### Base Fedora
```bash
# pacotes_fedora — pacotes essenciais (Fedora, RHEL-like)
# faltantes do dnf via GitHub releases / npm / repo dot
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_fedora.sh)
```

### Base Ubuntu / Debian
```bash
# pacotes_ubuntu — pacotes essenciais (Ubuntu, Debian, Pop!_OS, Mint)
# faltantes do apt via GitHub releases / npm / repo dot
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/pacotes_ubuntu.sh)
```

### Shell / prompt
```bash
# bash — aliases, funções, .bashrc (starship nord) e ~/.bin
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/bash.sh)

# bin — scripts de usuário em ~/.bin
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/bin.sh)

# starship — binário + configs
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/starship.sh)

# fonts — fontes (pacman no Arch + repo dot)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/fonts.sh)
```

### Terminais
```bash
# alacritty
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/alacritty.sh)

# kitty
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/kitty.sh)

# foot
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/foot.sh)
```

### Ferramentas
```bash
# btop — temas
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/btop.sh)

# fastfetch — config
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/fastfetch.sh)

# setup-nvim — config neovim (repo amonetlol/nvim)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/setup-nvim.sh)

# snapper — ajusta limites de snapshots do snapper (SNAPPER_LIMIT, padrão 6)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Sistema/snapper.sh)

# chaotic-aur — repositório Chaotic-AUR (Arch)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Sistema/chaotic-aur.sh)
```

### Temas / Rice
```bash
# rice — temas GTK, cursor e ícones (baixa assets do repo dot)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Rice/rice.sh)

# rice-base-gnome — rice GNOME: WhiteSur + MacTahoe + Vimix (multi-distro)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Rice/rice-base-gnome.sh)

# rice-base-kde — rice KDE: nordic-bluish, breeze, Layan, MacTahoe-nord, Oxygen_Zion, splash CachyOS-Nord
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Rice/rice-base-kde.sh)

# rice-ulauncher — temas Catppuccin Frappe (sapphire/blue) + autostart daemon sem popup
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Rice/rice-ulauncher.sh)

# sddm-catppuccin-Frappe-theme — SDDM Catppuccin Frappe Blue (Arch)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Rice/sddm-catppuccin-Frappe-theme.sh)

# sddm-astronaut-theme — SDDM Astronaut (AUR no Arch; manual nas outras distros)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Rice/sddm-astronaut-theme.sh)
```

### Wallpapers
```bash
# shot — screenshots (grim/slurp) em ~/Imagens/Screenshots + clipboard
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/shot.sh)

# wallpapers — repo wall2 → ~/Imagens/wallpapers
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/wallpapers.sh)

# random-wallpapers — script + timer systemd (5 min)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/random-wallpapers.sh)
```

### Rofi / atalhos
```bash
# binds_gnome-kde — keybinds GNOME ou KDE (detecta a DE)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/binds_gnome-kde.sh)

# hide-shortcuts — oculta entradas .desktop no rofi
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/hide-shortcuts.sh)

# recovery-shortcuts — restaura Alacritty/Kitty no rofi
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/recovery-shortcuts.sh)
```

### VMware
```bash
# vmware — open-vm-tools (guest)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/VMware/vmware.sh)

# fix-copy_vmware — autostart vmware-user (copiar/colar)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/VMware/fix-copy_vmware.sh)

# vmware-shared-folder — montagem persistente HGFS (fstab + atalho ~/SERVER)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/VMware/vmware-shared-folder.sh)
```

### Hyprland
```bash
# hypr-temas — Hyprland + temas custom (repo amonetlol/custom)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Hyprland/hypr-temas.sh)

# patch-hypr-scripts — gtkthemes em ~/.config/hypr + exec-once
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Hyprland/patch-hypr-scripts.sh)

# patch-rofi-wallpaper — wallpaper.sh (awww/swww/swaybg) nos temas custom
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/Hyprland/patch-rofi-wallpaper.sh)
```

## Variáveis de ambiente opcionais

| Variável | Função |
|---|---|
| `INSTALL_SUDO_PASSWORD` | senha sudo não interativa (vmware, chaotic-aur, sddm-*, rice, snapper, pacotes_*) |
| `SUDO_ASKPASS` | askpass alternativo |
| `DOT_REPO` / `DOT_CACHE` | repositório e cache dos dotfiles |
| `CUSTOM_REPO` / `CUSTOM_CACHE` | repositório e cache do custom (hypr-temas) |
| `WALLS_REPO_URL` | repositório de wallpapers (wallpapers.sh) |
| `DOT_ASSETS` | base URL dos assets do rice |
| `SNAPPER_LIMIT` | snapshots a manter (snapper.sh, padrão 6) |