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
for file in auto/config auto/clean config/hooks/live/*.hook.chroot config/hooks/live/*.hook.binary; do
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

say "checking live image cleanup policy"
grep -q -- "--apt-indices false" auto/config || fail "final live image must omit cached APT indices"
grep -q "apt-get clean" config/hooks/live/9000-glassxfce-cleanup.hook.chroot || fail "cleanup hook must clean APT cache"
if grep -Eq "/usr/share/(doc|locale)" config/hooks/live/9000-glassxfce-cleanup.hook.chroot; then
  fail "cleanup hook must not strip packaged docs or locales"
fi

say "checking squashfs size policy"
grep -q -- "--chroot-squashfs-compression-type xz" auto/config || fail "SquashFS must use xz compression"
grep -q -- "-b 1M" config/hooks/live/9100-glassxfce-squashfs.hook.binary || fail "SquashFS repack must use 1 MiB blocks"

say "checking required packages"
packages=config/package-lists/desktop.list.chroot
for pkg in live-task-xfce xfce4-docklike-plugin xfce4-whiskermenu-plugin xfce4-power-manager xfce4-terminal xfce4-screenshooter picom rofi lightdm calamares; do
  grep -qx "$pkg" "$packages" || fail "required package is missing: $pkg"
done
if grep -qx "xfce4-goodies" "$packages"; then
  fail "xfce4-goodies metapackage defeats the lean live-image package policy"
fi
grep -q -- "--apt-recommends false" auto/config || fail "live build must keep APT recommends disabled"

say "checking boot choices"
grep -qi 'live' config/bootloaders/grub-pc/grub.cfg || fail "GRUB menu has no live entry"
grep -qi 'install' config/bootloaders/grub-pc/grub.cfg || fail "GRUB menu has no installer entry"
grep -qi 'live' config/bootloaders/syslinux_common/menu.cfg || fail "Syslinux menu has no live entry"
grep -qi 'install' config/bootloaders/syslinux_common/menu.cfg || fail "Syslinux menu has no installer entry"

say "checking protected glass asset policy"
[ -x scripts/verify-glass-assets.sh ] || fail "missing executable Glass asset verifier"
for asset in WhiteSur-Light WhiteSur-Dark default.jpg picom.conf glass.rasi glassxfce.plymouth 50-glassxfce.conf welcome.png; do
  grep -Fq "$asset" scripts/verify-glass-assets.sh || fail "Glass asset verifier does not protect: $asset"
done
grep -q "verify-glass-assets.sh" .github/workflows/build-iso.yml || fail "ISO workflow must verify the Glass design payload"

say "checking iso size budget policy"
grep -q 'MAX_ISO_MIB="${MAX_ISO_MIB:-1800}"' scripts/release-check.sh || fail "release check must default to the 1800 MiB budget"
grep -q "MAX_ISO_MIB: 1800" .github/workflows/build-iso.yml || fail "ISO workflow must enforce the 1800 MiB budget"
[ -f docs/size-budget.md ] || fail "missing documented ISO size policy"

say "checking build workflow policy"
workflow=.github/workflows/build-iso.yml
grep -q 'workflow_dispatch:' "$workflow" || fail "ISO workflow is missing manual trigger"
grep -q -- '- "v\*"' "$workflow" || fail "ISO workflow is missing v* tag trigger"
if grep -Eq '^[[:space:]]+branches:' "$workflow"; then
  fail "ISO workflow must not build on branch pushes"
fi

say "checking welcome experience"
[ -f config/includes.chroot/usr/share/glassxfce/welcome/index.html ] || fail "missing offline welcome page"
[ -x config/includes.chroot/usr/local/bin/glassxfce-welcome ] || fail "missing welcome launcher helper"
[ -f config/includes.chroot/usr/share/applications/glassxfce-welcome.desktop ] || fail "missing welcome application entry"
grep -q 'glassxfce-welcome.desktop' config/includes.chroot/etc/skel/.config/xfce4/panel/whiskermenu-1.rc || fail "welcome entry must be visible in Whisker favorites"

say "checking installer live-session guard"
[ -x config/includes.chroot/usr/local/bin/glassxfce-installer ] || fail "missing guarded installer wrapper"
[ -x config/includes.chroot/usr/local/bin/glassxfce-installed-cleanup ] || fail "missing installed-system cleanup helper"
for launcher in \
  config/includes.chroot/usr/share/applications/glassxfce-installer.desktop \
  config/includes.chroot/etc/skel/Desktop/install-glassxfce.desktop \
  config/includes.chroot/etc/skel/.config/xfce4/panel/launcher-25/glass-install.desktop; do
  grep -q '^Exec=glassxfce-installer$' "$launcher" || fail "installer entry bypasses live-session guard: $launcher"
done
[ -f config/includes.chroot/etc/xdg/autostart/glassxfce-installed-cleanup.desktop ] || fail "missing installed cleanup autostart"

say "checking live session defaults"
[ -f config/includes.chroot/etc/live/config.conf.d/10-glassxfce.conf ] || fail "missing live-config defaults"
grep -q '^LIVE_USERNAME="live"$' config/includes.chroot/etc/live/config.conf.d/10-glassxfce.conf || fail "live username must remain live"
grep -q '^LIVE_HOSTNAME="glassxfce"$' config/includes.chroot/etc/live/config.conf.d/10-glassxfce.conf || fail "live hostname must remain glassxfce"
[ -x config/includes.chroot/usr/local/bin/glassxfce-is-live ] || fail "missing executable live-session detector"

say "checking distribution identity staging"
[ -f config/branding/os-release.in ] || fail "missing os-release identity template"
grep -q '^ID=glassxfce$' config/branding/os-release.in || fail "identity template must use ID=glassxfce"
grep -q '^ID_LIKE=debian$' config/branding/os-release.in || fail "identity template must declare Debian compatibility"
grep -q 'stage-identity.sh' build.sh || fail "build must stage the release identity"
[ -x scripts/stage-identity.sh ] || fail "identity staging helper must be executable"

say "checking repository whitespace"
if git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff --check HEAD^ HEAD
else
  git diff --check
fi

say "all static checks passed"
