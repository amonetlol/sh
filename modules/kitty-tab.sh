#!/usr/bin/env bash
# kitty-tab - instala as configs de amonetlol/goodies com CodeNewRoman ativa.
# Uso: bash <(curl -fsSL https://raw.githubusercontent.com/amonetlol/sh/main/modules/kitty-tab.sh)
# Requer git e python3; para usar as configs, Kitty, Rofi e as fontes instaladas.
set -euo pipefail

GOODIES_REPO="${GOODIES_REPO:-https://github.com/amonetlol/goodies.git}"
GOODIES_REF="${GOODIES_REF:-main}"

for dependency in git python3; do
  command -v "$dependency" >/dev/null 2>&1 || {
    printf '[ERRO] Dependencia ausente: %s\n' "$dependency" >&2
    exit 1
  }
done

work_dir="$(mktemp -d "${TMPDIR:-/tmp}/kitty-tab.XXXXXXXX")"
trap 'rm -rf -- "$work_dir"' EXIT

printf '[*] Baixando as configuracoes Kitty Tab...\n'
git clone --depth 1 --filter=blob:none --sparse --branch "$GOODIES_REF" \
  -- "$GOODIES_REPO" "$work_dir/goodies"
git -C "$work_dir/goodies" sparse-checkout set kitty-tab

python3 - "$work_dir/goodies/kitty-tab" <<'PY'
from pathlib import Path
from datetime import datetime
import re
import shutil
import sys

source = Path(sys.argv[1])
required = ('kitty.conf', 'show-hotkeys', 'search.py', 'scroll_mark.py')
for name in required:
    if not (source / name).is_file():
        raise SystemExit(f'[ERRO] Arquivo ausente na origem: {name}')
for name in ('rofi', 'themes'):
    if not (source / name).is_dir():
        raise SystemExit(f'[ERRO] Pasta ausente na origem: {name}')

home = Path.home()
target = home / '.config/kitty-tab'
launcher = home / '.local/bin/kitty-tab'
stamp = datetime.now().strftime('%Y%m%d-%H%M%S-%f')

# Prepare a configuracao antes de substituir os arquivos instalados.
config = (source / 'kitty.conf').read_text(encoding='utf-8-sig')
config = config.replace('\r\n', '\n').replace('@CONFIG@', str(target))
font_lines = (
    'font_family CodeNewRoman Nerd Font\n'
    '# font_family 0xProto Nerd Font'
)
pattern = r'(?m)^[ \t]*font_family[^\S\n]+[^\n]*$'
if not re.search(pattern, config):
    raise SystemExit('[ERRO] A origem nao possui a opcao font_family esperada.')
config = re.sub(pattern, lambda _: font_lines, config, count=1)

def backup(path):
    if path.exists() or path.is_symlink():
        destination = path.with_name(path.name + '.bak-' + stamp)
        path.rename(destination)
        print(f'[*] Backup: {destination}')

target.parent.mkdir(parents=True, exist_ok=True)
launcher.parent.mkdir(parents=True, exist_ok=True)
backup(target)
shutil.copytree(source, target)
(target / 'kitty.conf').write_text(config, encoding='utf-8', newline='\n')
(target / 'show-hotkeys').chmod(0o755)

backup(launcher)
launcher.write_text(
    '#!/usr/bin/env bash\n'
    'export KITTY_CONFIG_DIRECTORY="$HOME/.config/kitty-tab"\n'
    'exec kitty --config "$KITTY_CONFIG_DIRECTORY/kitty.conf" "$@"\n',
    encoding='utf-8', newline='\n',
)
launcher.chmod(0o755)
print(f'[OK] Configuracoes: {target}')
print('[OK] CodeNewRoman Nerd Font ativa; 0xProto Nerd Font comentada.')
print(f'[OK] Lancador: {launcher}')
PY
