# Guia — criação de scripts standalone em `sh/modules`

Use este guia para criar novos módulos seguindo a mesma lógica dos existentes.

## Regras base

1. **Destino:** `F:\GitHub\sh\modules` (repo `amonetlol/sh`, remote `https://github.com/amonetlol/sh.git`).
2. **Um script = zero dependências locais.** Nada de `source lib/*.sh`, nada de arquivos de outro repositório local. Tudo que o script precisa vem embutido nele ou é baixado da internet.
3. **Nome:** sem prefixo `install-` — apenas o nome do módulo (ex.: `alacritty.sh`, `rice.sh`).
4. **Cabeçalho:** comentário na 1ª linha descrevendo o módulo + linha `# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/<nome>.sh)`.
5. **Validação obrigatória:** `bash -n <script>` (no Windows: `"C:\Program Files\Git\bin\bash.exe" -n`).

## Padrões do projeto

### 1. Estrutura de um script

```bash
#!/usr/bin/env bash
# <nome> — o que faz
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/<nome>.sh)
set -euo pipefail

log()  { printf "[*] %s\n" "$1"; }
ok()   { printf "[OK] %s\n" "$1"; }
warn() { printf "[AVISO] %s\n" "$1"; }
fail() { printf "[ERRO] %s\n" "$1" >&2; exit 1; }
```

### 2. Helpers inlineados (copiar só o que o script usa)

- **Distro** (`is_arch_based`, `is_fedora_based`, `is_ubuntu_based`, `detect_distro_base`): checa `/etc/*-release` + `/etc/os-release` com `ID`/`ID_LIKE`. Arch aceita: `arch*`, `cachyos*`, `manjaro*`, `endeavouros*`, `garuda*`.
- **sudo não interativo:** wrapper que usa `INSTALL_SUDO_PASSWORD` (via `sudo -S`) ou `SUDO_ASKPASS`; se root, `command sudo -H`. Incluir `sudo_write_file` / `sudo_append_to_file` (mktemp + cp) quando precisar gravar em arquivo de root — nunca `sudo tee` com heredoc (a senha no stdin corrompe o arquivo).
- **Repo dot** (`DOT_REPO`, `DOT_CACHE=$HOME/.cache/base-dot-repo`): `dot_ensure_repo` (clone --depth 1 ou pull --ff-only), `dot_backup_path` (backup `.bak-<timestamp>`), `dot_copy_tree` (rsync ou cp -a), `dot_install_config`, `dot_install_bin`, `dot_install_home_files`.

### 3. Arquivos "vendored" viram heredoc

Conteúdo de arquivos de vendor (`.bashrc`, `gtkthemes`, `rofi-wallpaper.sh`, units systemd, etc.) vai embutido no script:

```bash
cat > "$DEST" <<'NOME_EOF'
...conteúdo literal (aspas simples no delimitador = sem expansão de variáveis)...
NOME_EOF
```

Regra: variáveis do script EMBUTIDO precisam continuar literais → delimitador entre aspas. Variáveis do script DE FORA (ex.: `$THEME_NAME` em config gerada) → delimitador sem aspas.

### 4. Assets binários viram download

Assets (zips, tar.xz) não vão no repo. O script baixa de `https://github.com/amonetlol/dot/raw/main/Assets/<arquivo>` (override com `DOT_ASSETS`) para cache local:

```bash
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/sh-assets"
# se já existe no cache, não baixa de novo (curl -fL)
```

Antes de usar uma URL nova, **verifique que ela responde** (`curl -sI` → 302/200).

### 5. Execução via curl + bash

Sempre `bash <(curl -fsSL URL)` — nunca `curl | bash` (stdin do script via pipe quebra prompts interativos de sudo/yay). Prompts `read` do script funcionam porque a process substitution não ocupa o stdin do terminal.

### 6. Não interativo / multi-distro

- Pacotes: `--needed --noconfirm` (pacman), `--needed --noconfirm --answerdiff None --answerclean None` (yay/paru), `dnf install -y`, `DEBIAN_FRONTEND=noninteractive apt-get install -y`, `zypper --non-interactive`.
- IDE/navegador: `source /etc/os-release` e case por família.
- Scripts de sessão GNOME usam `gsettings`; KDE usa `kglobalshortcutsrc` (formato INI, seção `[services][<id>.desktop] _launch=<tecla>`, reload com `kbuildsycoca6` + `qdbus org.kde.KWin /KWin reconfigure`).

### 7. Idempotência e robustez

- Sempre verificável de novo: backup antes de sobrescrever, `--needed`, check `command -v` antes de instalar.
- Grupos de pacotes: se um pacote falha, `warn` e continua para o próximo grupo (não aborta tudo).
- Comando pode não existir: `command -v x &>/dev/null || warn "..."` e segue.

## Fluxo de criação (checklist)

1. Ler o script original (se existir em outro repo) e mapear: sources de libs, arquivos locais usados, assets.
2. Criar o arquivo em `F:\GitHub\sh\modules\<nome>.sh` com header + `set -euo pipefail` + helpers inlineados.
3. Embutir vendored em heredoc; substituir assets locais por download remoto verificado.
4. Remover toda referência a `SCRIPT_DIR`, `REPO_ROOT`, `vendor/`, `Assets/`, `lib/` (exceto quando for fallback opcional com caminho remoto).
5. Validar com `bash -n`.
6. Atualizar `F:\GitHub\sh\modules\list.md`: comando pronto na seção certa (`bash <(curl -fsSL ...)`) + variáveis de ambiente opcionais na tabela, se houver.
7. Commit/push no repo `amonetlol/sh` para a URL raw ficar ativa.

## Variáveis de ambiente padrão (documentar se o script usar)

| Variável | Uso |
|---|---|
| `INSTALL_SUDO_PASSWORD` | senha sudo não interativa |
| `SUDO_ASKPASS` | askpass alternativo |
| `DOT_REPO` / `DOT_CACHE` | repo/cache dos dotfiles |
| `CUSTOM_REPO` / `CUSTOM_CACHE` | repo/cache do custom |
| `DOT_ASSETS` | base URL dos assets |
| `XDG_CACHE_HOME` | onde ficam os caches (sh-assets, base-dot-repo) |