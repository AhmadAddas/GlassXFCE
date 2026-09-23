#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

say() { printf 'validate: %s\n' "$*"; }
fail() { printf 'validate: error: %s\n' "$*" >&2; exit 1; }

say "checking shell syntax"
bash -n build.sh
for file in scripts/*.sh; do
  bash -n "$file"
done
for file in auto/config auto/clean config/hooks/live/*.hook.chroot; do
  sh -n "$file"
done

say "checking XML"
python3 - <<'PY'
from pathlib import Path
import xml.etree.ElementTree as ET
paths = sorted(Path('config').rglob('*.xml'))
if not paths:
    raise SystemExit('no XML configuration files found')
for path in paths:
    ET.parse(path)
    print(f'xml ok: {path}')
PY

say "checking desktop launchers"
python3 - <<'PY'
from pathlib import Path
import configparser
paths = sorted(Path('config/includes.chroot').rglob('*.desktop'))
for path in paths:
    parser = configparser.ConfigParser(interpolation=None, strict=False)
    parser.optionxform = str
    parser.read(path, encoding='utf-8')
    if 'Desktop Entry' not in parser:
        raise SystemExit(f'{path}: missing [Desktop Entry]')
    entry = parser['Desktop Entry']
    for key in ('Type', 'Name'):
        if not entry.get(key):
            raise SystemExit(f'{path}: missing {key}')
    if entry.get('Type') == 'Application' and not entry.get('Exec'):
        raise SystemExit(f'{path}: application is missing Exec')
    print(f'desktop ok: {path}')
PY

say "checking required packages"
packages=config/package-lists/desktop.list.chroot
for pkg in live-task-xfce xfce4-docklike-plugin picom rofi lightdm calamares; do
  grep -qx "$pkg" "$packages" || fail "required package is missing: $pkg"
done

say "checking boot choices"
grep -qi 'live' config/bootloaders/grub-pc/grub.cfg || fail "GRUB menu has no live entry"
grep -qi 'install' config/bootloaders/grub-pc/grub.cfg || fail "GRUB menu has no installer entry"
grep -qi 'live' config/bootloaders/syslinux_common/menu.cfg || fail "Syslinux menu has no live entry"
grep -qi 'install' config/bootloaders/syslinux_common/menu.cfg || fail "Syslinux menu has no installer entry"

say "checking build workflow policy"
workflow=.github/workflows/build-iso.yml
grep -q 'workflow_dispatch:' "$workflow" || fail "ISO workflow is missing manual trigger"
grep -q -- '- "v\*"' "$workflow" || fail "ISO workflow is missing v* tag trigger"
if grep -Eq '^[[:space:]]+branches:' "$workflow"; then
  fail "ISO workflow must not build on branch pushes"
fi

say "checking repository whitespace"
if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff --check HEAD^ HEAD
else
  git diff --check
fi

say "all static checks passed"
