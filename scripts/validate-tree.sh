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
for file in auto/config auto/clean; do
  sh -n "$file"
done
while IFS= read -r -d '' file; do
  sh -n "$file"
done < <(find config/hooks/live -maxdepth 1 -type f \( -name '*.hook.chroot' -o -name '*.hook.binary' \) -print0)

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
grep -Fq 'export MKSQUASHFS_OPTIONS="-b 1M -Xdict-size 100% -Xbcj x86"' build.sh || fail "live-build must create SquashFS with 1 MiB XZ/BCJ options"
grep -Fq 'config/hooks/live/9100-glassxfce-squashfs.hook.binary' build.sh || fail "build must clean the obsolete pre-binary_rootfs SquashFS hook left by ZIP overlays"
grep -Fq 'rm -f -- "$legacy_path"' build.sh || fail "build must remove obsolete ZIP-overlay paths before live-build scans hooks"
if [ -e config/hooks/live/9100-glassxfce-squashfs.hook.binary ]; then
  say "legacy SquashFS hook is present in this overlaid tree; build.sh will remove it before live-build"
fi

say "checking required packages"
packages=config/package-lists/desktop.list.chroot
for pkg in live-task-xfce xfce4-docklike-plugin xfce4-whiskermenu-plugin xfce4-power-manager xfce4-pulseaudio-plugin xfce4-terminal xfce4-screenshooter picom rofi lightdm calamares firmware-iwlwifi firmware-realtek firmware-amd-graphics firmware-intel-graphics firmware-sof-signed intel-microcode amd64-microcode bluez blueman; do
  grep -qx "$pkg" "$packages" || fail "required package is missing: $pkg"
done
if grep -qx "xfce4-goodies" "$packages"; then
  fail "xfce4-goodies metapackage defeats the lean live-image package policy"
fi
grep -q -- "--apt-recommends false" auto/config || fail "live build must keep APT recommends disabled"

# The default top panel references the PulseAudio plugin explicitly.
grep -q 'value="pulseaudio"' config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml || fail "default panel must expose audio controls"

say "checking power defaults"
power=config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-power-manager.xml
[ -f "$power" ] || fail "missing XFCE power defaults"
grep -q 'name="dpms-enabled" type="bool" value="true"' "$power" || fail "DPMS must be enabled"
grep -q 'name="lock-screen-suspend-hibernate" type="bool" value="true"' "$power" || fail "resume lock protection must be enabled"

say "checking boot choices"
grep -q -- '--bootloaders "grub-efi syslinux"' auto/config || fail "build must include BIOS and UEFI bootloaders"
grep -q -- '--uefi-secure-boot enable' auto/config || fail "UEFI Secure Boot support must remain enabled"
grep -qi 'live' config/bootloaders/grub-pc/grub.cfg || fail "GRUB menu has no live entry"
grep -qi 'install' config/bootloaders/grub-pc/grub.cfg || fail "GRUB menu has no installer entry"
grep -qi 'live' config/bootloaders/syslinux_common/menu.cfg || fail "Syslinux menu has no live entry"
grep -qi 'install' config/bootloaders/syslinux_common/menu.cfg || fail "Syslinux menu has no installer entry"

say "checking protected glass asset policy"
[ -f scripts/verify-glass-assets.sh ] || fail "missing Glass asset verifier"
for asset in WhiteSur-Light WhiteSur-Dark default.jpg picom.conf glass.rasi glassxfce.plymouth 50-glassxfce.conf welcome.png; do
  grep -Fq "$asset" scripts/verify-glass-assets.sh || fail "Glass asset verifier does not protect: $asset"
done
grep -q "verify-glass-assets.sh" .github/workflows/build-iso.yml || fail "ISO workflow must verify the Glass design payload"

say "checking image identity verification"
[ -f scripts/verify-image-identity.sh ] || fail "missing image identity verifier"
grep -q 'verify-image-identity.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify the built image identity"
grep -q 'VERSION_CODENAME=trixie' scripts/verify-image-identity.sh || fail "identity verifier must protect the Debian suite"

say "checking built boot menu verification"
[ -f scripts/verify-boot-menu.sh ] || fail "missing built boot menu verifier"
grep -Fq 'verify-boot-menu.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify built boot menu choices"
grep -Fq 'Try GlassXFCE Live' scripts/verify-boot-menu.sh || fail "boot menu verifier must protect the Live choice"
grep -Fq 'Install GlassXFCE' scripts/verify-boot-menu.sh || fail "boot menu verifier must protect the Install choice"

say "checking installer payload verification"
[ -f scripts/verify-installer-payload.sh ] || fail "missing installer payload verifier"
grep -q 'verify-installer-payload.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify installer payloads"
grep -q '/install.amd' scripts/verify-installer-payload.sh || fail "installer verifier must inspect the Debian installer payload"
grep -q 'usr/bin/calamares' scripts/verify-installer-payload.sh || fail "installer verifier must protect Calamares"

say "checking Secure Boot verification"
[ -f scripts/verify-secure-boot.sh ] || fail "missing Secure Boot verifier"
grep -q 'verify-secure-boot.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify the signed UEFI bootloader"
grep -q 'sbsigntool' .github/workflows/build-iso.yml || fail "ISO workflow must install sbverify tooling"
grep -q 'sbverify --list' scripts/verify-secure-boot.sh || fail "Secure Boot verifier must inspect PE signatures"

say "checking QEMU boot smoke coverage"
[ -f scripts/smoke-test-iso.sh ] || fail "missing ISO smoke test"
grep -q 'OVMF_CODE' scripts/smoke-test-iso.sh || fail "smoke test must exercise UEFI through OVMF"
grep -q 'ovmf' .github/workflows/build-iso.yml || fail "ISO workflow must install OVMF for UEFI smoke testing"

say "checking ISO payload reporting"
[ -f scripts/report-iso-payload.sh ] || fail "missing ISO payload reporter"
grep -q 'report-iso-payload.sh' .github/workflows/build-iso.yml || fail "ISO workflow must report compressed payload size"

say "checking runtime package verification"
[ -f scripts/verify-runtime-packages.sh ] || fail "missing runtime package verifier"
grep -q 'verify-runtime-packages.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify runtime packages"
for pkg in firmware-iwlwifi firmware-realtek firmware-amd-graphics xfce4-pulseaudio-plugin bluez; do
  grep -Fq "'$pkg'" scripts/verify-runtime-packages.sh || fail "runtime verifier does not protect package: $pkg"
done

say "checking squashfs release format verification"
[ -f scripts/verify-squashfs-format.sh ] || fail "missing SquashFS verifier"
grep -Fq 'verify-squashfs-format.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify SquashFS release compression"
grep -Fq "Compression[[:space:]]+xz" scripts/verify-squashfs-format.sh || fail "SquashFS verifier must require XZ"
grep -Fq "Block size[[:space:]]+1048576" scripts/verify-squashfs-format.sh || fail "SquashFS verifier must require 1 MiB blocks"

say "checking iso size budget policy"
grep -q 'MAX_ISO_MIB="${MAX_ISO_MIB:-1850}"' scripts/release-check.sh || fail "release check must default to the 1850 MiB budget"
grep -q "MAX_ISO_MIB: 1850" .github/workflows/build-iso.yml || fail "ISO workflow must enforce the 1850 MiB budget"
[ -f docs/size-budget.md ] || fail "missing documented ISO size policy"

say "checking Debian package validation policy"
[ -f scripts/validate-packages.sh ] || fail "missing package manifest validator"
grep -q 'validate-packages.sh' .github/workflows/validate.yml || fail "normal CI must validate Debian package availability"
grep -q 'debian:13' .github/workflows/validate.yml || fail "package validation must run against Debian 13"

say "checking live-build configuration validation"
[ -f scripts/validate-live-build-config.sh ] || fail "missing live-build configuration validator"
grep -q 'validate-live-build-config.sh' .github/workflows/validate.yml || fail "normal CI must validate live-build configuration"
grep -Fq './auto/config --validate' scripts/validate-live-build-config.sh || fail "live-build validation must use lb config validation mode"

say "checking build host preflight"
[ -f scripts/build-host-preflight.sh ] || fail "missing build host preflight"
grep -Fq 'build-host-preflight.sh' .github/workflows/build-iso.yml || fail "ISO build must run the build host preflight"
grep -Fq 'MIN_BUILD_FREE_GIB:-10' scripts/build-host-preflight.sh || fail "build host preflight must protect working disk space"
grep -Fq 'xz-utils' .github/workflows/build-iso.yml || fail "ISO build container must install xz-utils for .tar.xz theme archives"
grep -Eq 'for command in .*\bxz\b' scripts/build-host-preflight.sh || fail "build host preflight must require the xz decompressor"
grep -Fq 'PATH="$shim:$PATH" bash "$source/install.sh"' scripts/stage-design.sh || fail "WhiteSur icon staging must not depend on host GTK tooling"
[ -f config/hooks/live/0300-glassxfce-icon-cache.hook.chroot ] || fail "missing target-image icon cache hook"

say "checking build source metadata"
grep -q 'GIT_COMMIT="$GITHUB_SHA"' .github/workflows/build-iso.yml || fail "ISO workflow must pass the source commit into the build container"
grep -q 'COMMIT="${GIT_COMMIT:-unknown}"' build.sh || fail "build metadata must prefer the explicit source commit"

say "checking build metadata verification"
[ -f scripts/verify-build-metadata.sh ] || fail "missing build metadata verifier"
grep -q 'verify-build-metadata.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify build metadata"
grep -q 'source commit mismatch' scripts/verify-build-metadata.sh || fail "metadata verifier must compare the source commit"

say "checking release checksum generation"
grep -q '( cd dist && sha256sum "$ISO_BASE" )' build.sh || fail "build must checksum the ISO from inside dist/"
if grep -q 'sha256sum "$(basename "$ISO_DST")"' build.sh; then
  fail "build checksum must not reference the ISO basename from repository root"
fi

say "checking semantic release tags"
[ -f scripts/validate-release-version.sh ] || fail "missing release version validator"
grep -q 'validate-release-version.sh' .github/workflows/build-iso.yml || fail "tagged builds must validate semantic release versions"

say "checking build network preflight"
[ -f scripts/check-build-network.sh ] || fail "local build network preflight is missing"
if ! grep -Fq 'check-build-network.sh' .github/workflows/build-iso.yml; then
  grep -Fq 'https://deb.debian.org/debian/dists/trixie/InRelease' .github/workflows/build-iso.yml || fail "build workflow does not probe Debian Trixie"
  grep -Fq 'WhiteSur-gtk-theme.git/info/refs?service=git-upload-pack' .github/workflows/build-iso.yml || fail "build workflow does not probe the WhiteSur source host"
fi

say "checking workflow checkout integrity guard"
grep -Fq 'Verify checked-out build tree' .github/workflows/build-iso.yml || fail "build workflow does not verify its checked-out source tree"
grep -Fq 'Required build file is missing from the checked-out revision' .github/workflows/build-iso.yml || fail "checkout integrity guard does not report missing required files"

say "checking failed build log retention"
grep -Fq 'id: iso_build' .github/workflows/build-iso.yml || fail "ISO build step must have a stable id"
grep -Fq 'tee build.log' .github/workflows/build-iso.yml || fail "ISO build output must be captured"
grep -Fq "steps.iso_build.outcome == 'failure'" .github/workflows/build-iso.yml || fail "failed build log upload must be failure-only"

say "checking build workflow policy"
workflow=.github/workflows/build-iso.yml
grep -q 'workflow_dispatch:' "$workflow" || fail "ISO workflow is missing manual trigger"
grep -q -- '- "v\*"' "$workflow" || fail "ISO workflow is missing v* tag trigger"
if grep -Eq '^[[:space:]]+branches:' "$workflow"; then
  fail "ISO workflow must not build on branch pushes"
fi

say "checking welcome experience"
[ -f config/includes.chroot/usr/share/glassxfce/welcome/index.html ] || fail "missing offline welcome page"
[ -f config/includes.chroot/usr/local/bin/glassxfce-welcome ] || fail "missing welcome launcher helper"
[ -f config/includes.chroot/usr/share/applications/glassxfce-welcome.desktop ] || fail "missing welcome application entry"
grep -q 'glassxfce-welcome.desktop' config/includes.chroot/etc/skel/.config/xfce4/panel/whiskermenu-1.rc || fail "welcome entry must be visible in Whisker favorites"

say "checking installer live-session guard"
[ -f config/includes.chroot/usr/local/bin/glassxfce-installer ] || fail "missing guarded installer wrapper"
[ -f config/includes.chroot/usr/local/bin/glassxfce-installed-cleanup ] || fail "missing installed-system cleanup helper"
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
[ -f config/includes.chroot/usr/local/bin/glassxfce-is-live ] || fail "missing live-session detector"

say "checking distribution identity staging"
[ -f config/branding/os-release.in ] || fail "missing os-release identity template"
grep -q '^ID=glassxfce$' config/branding/os-release.in || fail "identity template must use ID=glassxfce"
grep -q '^ID_LIKE=debian$' config/branding/os-release.in || fail "identity template must declare Debian compatibility"
grep -q 'stage-identity.sh' build.sh || fail "build must stage the release identity"
[ -f scripts/stage-identity.sh ] || fail "identity staging helper is missing"

say "checking repository whitespace"
# During development, check the current worktree/index so formatting problems
# are caught before commit. In CI the checkout is clean, so validate the latest
# committed change instead.
if ! git diff --quiet || ! git diff --cached --quiet; then
  git diff --check
  git diff --cached --check
elif git rev-parse --verify HEAD^ >/dev/null 2>&1; then
  git diff --check HEAD^ HEAD
fi

say "all static checks passed"
