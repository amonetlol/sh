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
# pacotes_fedora — pacotes essenciais via dnf + extras via GitHub Releases (starship, eza, zoxide, lazygit, tree-sitter-cli, prettier) e fontes Geist/Nerd
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
```

### Temas / Rice
```bash
# rice — temas GTK, cursor e ícones (baixa assets do repo dot)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/rice.sh)

# rice-base — WhiteSur + MacTahoe + Vimix (multi-distro)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/rice-base.sh)

# hypr-temas — Hyprland + temas custom (repo amonetlol/custom)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/hypr-temas.sh)

# sddm-theme — SDDM Catppuccin Frappe Blue (Arch)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/sddm-theme.sh)

# chaotic-aur — repositório Chaotic-AUR (Arch)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/chaotic-aur.sh)
```

### Wallpapers
```bash
# wallpapers — repo wall2 → ~/Imagens/wallpapers
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/wallpapers.sh)

# random-wallpapers — script + timer systemd (5 min)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/random-wallpapers.sh)

# patch-rofi-wallpaper — wallpaper.sh (awww/swww/swaybg) nos temas custom
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/patch-rofi-wallpaper.sh)
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
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/vmware.sh)

# fix-copy_vmware — autostart vmware-user (copiar/colar)
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/fix-copy_vmware.sh)
```

### Patches Hyprland
```bash
# patch-hypr-scripts — gtkthemes em ~/.config/hypr + exec-once
bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/patch-hypr-scripts.sh)
```

## Variáveis de ambiente opcionais

| Variável | Função |
|---|---|
| `INSTALL_SUDO_PASSWORD` | senha sudo não interativa (vmware, chaotic-aur, sddm-theme, rice) |
| `SUDO_ASKPASS` | askpass alternativo |
| `DOT_REPO` / `DOT_CACHE` | repositório e cache dos dotfiles |
| `CUSTOM_REPO` / `CUSTOM_CACHE` | repositório e cache do custom (hypr-temas) |
| `WALLS_REPO_URL` | repositório de wallpapers (wallpapers.sh) |
| `DOT_ASSETS` | base URL dos assets do rice |