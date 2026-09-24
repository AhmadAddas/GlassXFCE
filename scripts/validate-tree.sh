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
for pkg in live-task-xfce live-config live-config-systemd user-setup sudo plank xfce4-whiskermenu-plugin xfce4-power-manager xfce4-power-manager-plugins xfce4-pulseaudio-plugin xfce4-terminal xfce4-screenshooter picom rofi lightdm python3-gi gir1.2-gtk-3.0 calamares xserver-xorg-core xserver-xorg-video-all libgl1-mesa-dri mesa-vulkan-drivers firmware-iwlwifi firmware-realtek firmware-atheros firmware-brcm80211 firmware-mediatek firmware-libertas firmware-ti-connectivity firmware-zd1211 firmware-amd-graphics firmware-intel-graphics firmware-nvidia-graphics firmware-misc-nonfree firmware-sof-signed intel-microcode amd64-microcode network-manager network-manager-gnome wpasupplicant wireless-regdb iw rfkill bluez blueman colord xiccd libpam-pwquality cracklib-runtime wamerican; do
  grep -qx "$pkg" "$packages" || fail "required package is missing: $pkg"
done
if grep -qx "xfce4-goodies" "$packages"; then
  fail "xfce4-goodies metapackage defeats the lean live-image package policy"
fi
grep -q -- "--apt-recommends false" auto/config || fail "live build must keep APT recommends disabled"

# The default top panel references the PulseAudio plugin explicitly.
grep -q 'value="pulseaudio"' config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml || fail "default panel must expose audio controls"
[ -f config/includes.chroot/etc/xdg/autostart/glassxfce-plank.desktop ] || fail "missing Plank autostart"
[ -f config/includes.chroot/etc/xdg/autostart/glassxfce-color-management.desktop ] || fail "missing XFCE color-management autostart"
grep -q '^Exec=xiccd$' config/includes.chroot/etc/xdg/autostart/glassxfce-color-management.desktop || fail "color-management autostart must run xiccd"
[ -f config/includes.chroot/etc/skel/.config/plank/dock1/settings ] || fail "missing Plank dock defaults"
if grep -q 'panel-2' config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml; then
  fail "bottom dock must not be a second XFCE panel"
fi

say "checking wallpaper reliability"
[ -f config/includes.chroot/usr/share/backgrounds/glassxfce/sunlit-glass.png ] || fail "missing shipped bright wallpaper"
[ -f config/includes.chroot/usr/local/bin/glassxfce-apply-wallpaper ] || fail "missing monitor-aware wallpaper helper"
[ -f config/includes.chroot/etc/xdg/autostart/glassxfce-wallpaper.desktop ] || fail "missing delayed wallpaper autostart"
grep -Fq 'sunlit-glass.png' config/includes.chroot/etc/lightdm/lightdm-gtk-greeter.conf.d/50-glassxfce.conf || fail "LightDM must use an existing GlassXFCE background"
grep -Fq '/last-image$' config/includes.chroot/usr/local/bin/glassxfce-apply-wallpaper || fail "wallpaper helper must discover real monitor backdrop keys"
grep -Fq 'COMPAT=/usr/share/images/desktop-base' config/hooks/live/0410-glassxfce-wallpapers.hook.chroot || fail "wallpaper hook must preserve the Debian/Xfce compatibility folder"
grep -Fq 'desktop-background' config/hooks/live/0410-glassxfce-wallpapers.hook.chroot || fail "wallpaper compatibility folder must expose a default background"

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
grep -Fq 'background_image /boot/grub/splash.png' config/bootloaders/grub-pc/grub.cfg || fail "GRUB must render the GlassXFCE splash directly"
if grep -Fq 'source /boot/grub/theme.cfg' config/bootloaders/grub-pc/grub.cfg; then fail "GRUB submenus must not re-enable the opaque stock live-build theme"; fi
[ -f config/bootloaders/grub-pc/theme.cfg ] || fail "missing transparent GRUB theme compatibility shim"
[ -f config/bootloaders/grub-pc/themes/glassxfce/theme.txt ] || fail "missing GlassXFCE GRUB theme file"
[ -f config/bootloaders/grub-pc/themes/glassxfce/background.png ] || fail "missing GlassXFCE GRUB theme background"
grep -Fq "/boot/grub/themes/glassxfce/theme.txt" config/bootloaders/grub-pc/theme.cfg || fail "GRUB theme shim must target the bundled GlassXFCE theme"
grep -Fq 'set theme=' config/bootloaders/grub-pc/theme.cfg || fail "GRUB theme shim must disable the stock opaque theme"
grep -Fq 'background_image /boot/grub/splash.png' config/bootloaders/grub-pc/theme.cfg || fail "GRUB theme shim must retain GlassXFCE boot art"

say "checking protected glass asset policy"
[ -f scripts/verify-glass-assets.sh ] || fail "missing Glass asset verifier"
for asset in WhiteSur-Light WhiteSur-Dark aurora.svg aurora.png picom.conf glass.rasi glassxfce.plymouth 50-glassxfce.conf welcome.png; do
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
grep -Fq 'on:auto_chmod_on' scripts/verify-boot-menu.sh || fail "boot menu verifier must handle read-only ISO directories during extraction"
grep -Fq 'chmod -R u+rwX "$TMP"' scripts/verify-boot-menu.sh || fail "boot menu verifier cleanup must handle read-only extracted directories"

say "checking installer payload verification"
[ -f scripts/verify-installer-payload.sh ] || fail "missing installer payload verifier"
grep -q 'verify-installer-payload.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify installer payloads"
grep -Fq '/install /install.amd' scripts/verify-installer-payload.sh || fail "installer verifier must recognize the Trixie /install layout"
grep -Fq 'gtk/vmlinuz' scripts/verify-installer-payload.sh || fail "installer verifier must protect the graphical Debian installer payload"
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
for pkg in firmware-iwlwifi firmware-realtek firmware-atheros firmware-brcm80211 firmware-mediatek firmware-libertas firmware-ti-connectivity firmware-zd1211 firmware-amd-graphics firmware-nvidia-graphics firmware-misc-nonfree network-manager wpasupplicant wireless-regdb xserver-xorg-core xserver-xorg-video-all libgl1-mesa-dri mesa-vulkan-drivers xfce4-power-manager-plugins xfce4-pulseaudio-plugin bluez; do
  grep -Fq "'$pkg'" scripts/verify-runtime-packages.sh || fail "runtime verifier does not protect package: $pkg"
done

say "checking squashfs release format verification"
[ -f scripts/verify-squashfs-format.sh ] || fail "missing SquashFS verifier"
grep -Fq 'verify-squashfs-format.sh' .github/workflows/build-iso.yml || fail "ISO workflow must verify SquashFS release compression"
grep -Fq "Compression[[:space:]]+xz" scripts/verify-squashfs-format.sh || fail "SquashFS verifier must require XZ"
grep -Fq "Block size[[:space:]]+1048576" scripts/verify-squashfs-format.sh || fail "SquashFS verifier must require 1 MiB blocks"

say "checking iso size budget policy"
grep -q 'MAX_ISO_MIB="${MAX_ISO_MIB:-1950}"' scripts/release-check.sh || fail "release check must default to the 1950 MiB budget"
grep -q "MAX_ISO_MIB: 1950" .github/workflows/build-iso.yml || fail "ISO workflow must enforce the 1950 MiB budget"
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
grep -Fq 'xz-utils file sassc' .github/workflows/build-iso.yml || fail "ISO build container must install the file utility for live-build installer detection"
grep -Eq 'for command in .*\bfile\b' scripts/build-host-preflight.sh || fail "build host preflight must require the file utility"
grep -Fq 'PATH="$shim:$PATH" bash "$source/install.sh"' scripts/stage-design.sh || fail "WhiteSur icon staging must not depend on host GTK tooling"
grep -Fq 'Inherits=Papirus,Adwaita,hicolor' scripts/stage-design.sh || fail "WhiteSur must inherit the broad Papirus fallback"
[ -f config/hooks/live/0410-glassxfce-wallpapers.hook.chroot ] || fail "missing stock-wallpaper cleanup hook"
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

say "checking compositor presentation"
[ -f config/includes.chroot/etc/skel/.config/picom/picom-fallback.conf ] || fail "missing Picom hardware fallback"
grep -q 'backend = "xrender"' config/includes.chroot/etc/skel/.config/picom/picom-fallback.conf || fail "Picom fallback must use XRender"
grep -q -- '--daemon' config/includes.chroot/usr/local/bin/glassxfce-start-picom || fail "Picom wrapper must daemonize cleanly"
grep -q '^Hidden=true$' config/includes.chroot/etc/skel/.local/share/applications/picom.desktop || fail "raw Picom menu entry must be hidden"
[ -f config/includes.chroot/etc/skel/.face ] || fail "missing GlassXFCE user avatar"

say "checking welcome experience"
[ -f config/includes.chroot/usr/share/glassxfce/welcome/welcome.py ] || fail "missing native welcome app"
[ -f config/includes.chroot/usr/local/bin/glassxfce-welcome ] || fail "missing welcome launcher helper"
[ -f config/includes.chroot/etc/xdg/autostart/glassxfce-welcome.desktop ] || fail "missing welcome autostart"
grep -Fq "welcome.py" config/includes.chroot/usr/local/bin/glassxfce-welcome || fail "welcome helper must launch the native GTK app"
[ -f config/includes.chroot/usr/share/applications/glassxfce-welcome.desktop ] || fail "missing welcome application entry"
grep -q 'glassxfce-welcome.desktop' config/includes.chroot/etc/skel/.config/xfce4/panel/whiskermenu-1.rc || fail "welcome entry must be visible in Whisker favorites"
[ -f config/includes.chroot/usr/share/applications/glassxfce-search.desktop ] || fail "missing branded Glass Search entry"
grep -q '^Exec=glassxfce-launcher$' config/includes.chroot/usr/share/applications/glassxfce-search.desktop || fail "Glass Search must use the lightweight launcher helper"
for hidden in rofi.desktop rofi-theme-selector.desktop; do
  grep -q '^Hidden=true$' "config/includes.chroot/etc/skel/.local/share/applications/$hidden" || fail "raw Rofi menu entry must be hidden: $hidden"
done

say "checking installer password quality support"
[ -f config/hooks/live/0430-glassxfce-password-dictionary.hook.chroot ] || fail "missing CrackLib dictionary build hook"
grep -q 'update-cracklib' config/hooks/live/0430-glassxfce-password-dictionary.hook.chroot || fail "password dictionary hook must build CrackLib cache"
for pkg in libpam-pwquality cracklib-runtime wamerican; do
  grep -qx "$pkg" "$packages" || fail "installer password-quality package is missing: $pkg"
done

say "checking installer live-session guard"
[ -f config/includes.chroot/usr/local/bin/glassxfce-installer ] || fail "missing guarded installer wrapper"
[ -f config/includes.chroot/usr/local/bin/glassxfce-installed-cleanup ] || fail "missing installed-system cleanup helper"
for launcher in \
  config/includes.chroot/usr/share/applications/glassxfce-installer.desktop \
  config/includes.chroot/etc/skel/Desktop/install-glassxfce.desktop; do
  grep -q '^Exec=glassxfce-installer$' "$launcher" || fail "installer entry bypasses live-session guard: $launcher"
done
[ -f config/includes.chroot/etc/skel/.config/plank/dock1/launchers/glassxfce-installer.dockitem ] || fail "missing installer Plank item"
grep -Fq 'glassxfce-installer.desktop' config/includes.chroot/etc/skel/.config/plank/dock1/launchers/glassxfce-installer.dockitem || fail "Plank installer item must launch the GlassXFCE installer entry"
[ -f config/includes.chroot/etc/xdg/autostart/glassxfce-installed-cleanup.desktop ] || fail "missing installed cleanup autostart"
[ -f config/includes.chroot/usr/share/icons/hicolor/scalable/apps/glassxfce-installer.svg ] || fail "missing GlassXFCE installer icon"
grep -q '^Icon=glassxfce-installer$' config/includes.chroot/usr/share/applications/glassxfce-installer.desktop || fail "installer menu entry must use GlassXFCE icon"
[ -f config/includes.chroot/etc/calamares/branding/glassxfce/branding.desc ] || fail "missing GlassXFCE Calamares branding"
grep -q 'productName: GlassXFCE' config/includes.chroot/etc/calamares/branding/glassxfce/branding.desc || fail "Calamares product name must be GlassXFCE"
[ -f config/hooks/live/0420-glassxfce-installer-branding.hook.chroot ] || fail "missing Calamares branding cleanup hook"
[ -f config/hooks/live/0400-glassxfce-desktop-shortcuts.hook.chroot ] || fail "missing generic Calamares desktop-shortcut cleanup hook"
grep -Fq 'calamares-install-debian.desktop' config/hooks/live/0400-glassxfce-desktop-shortcuts.hook.chroot || fail "generic Calamares desktop shortcut must be removed"
grep -Fq 'calamares-desktop-icon.desktop' config/hooks/live/0420-glassxfce-installer-branding.hook.chroot || fail "Debian Calamares desktop-icon autostart must be disabled"

say "checking window button placement"
[ -f config/includes.chroot/usr/local/bin/glassxfce-window-buttons ] || fail "missing window-button side switcher"
[ -f config/includes.chroot/usr/share/applications/glassxfce-window-buttons.desktop ] || fail "missing window-button Settings entry"
grep -Fq 'value="|HMC"' config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml || fail "window buttons must default to the right"
grep -Fq "layout='CHM|'" config/includes.chroot/usr/local/bin/glassxfce-window-buttons || fail "window button switcher must support left controls"

say "checking bounded user-session shutdown"
[ -f config/includes.chroot/etc/systemd/user/mpris-proxy.service.d/10-glassxfce-stop-timeout.conf ] || fail "missing mpris-proxy stop timeout"
grep -q '^TimeoutStopSec=5s$' config/includes.chroot/etc/systemd/user/mpris-proxy.service.d/10-glassxfce-stop-timeout.conf || fail "mpris-proxy stop timeout must remain short"
[ -f config/includes.chroot/etc/systemd/system/user@.service.d/10-glassxfce-stop-timeout.conf ] || fail "missing user manager stop timeout"
grep -q '^TimeoutStopSec=20s$' config/includes.chroot/etc/systemd/system/user@.service.d/10-glassxfce-stop-timeout.conf || fail "user manager stop timeout must remain bounded"

say "checking system icon coverage"
[ -f config/hooks/live/0440-glassxfce-system-icons.hook.chroot ] || fail "missing GlassXFCE system-icon overlay hook"
grep -Fq 'Inherits=WhiteSur,Papirus,Adwaita,hicolor' config/hooks/live/0440-glassxfce-system-icons.hook.chroot || fail "system icon overlay must retain WhiteSur and Papirus fallbacks"
grep -Fq 'value="GlassXFCE"' config/includes.chroot/etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml || fail "GlassXFCE icon overlay must be the default icon theme"
grep -Fq 'xfsm-logout' config/hooks/live/0440-glassxfce-system-icons.hook.chroot || fail "system icon overlay must cover Xfce logout actions"
grep -Fq 'org.xfce.workspaces' config/hooks/live/0440-glassxfce-system-icons.hook.chroot || fail "system icon overlay must cover the Xfce workspaces icon"
grep -Fq 'linearGradient id="g"' config/hooks/live/0440-glassxfce-system-icons.hook.chroot || fail "workspaces icon must use the dedicated high-contrast GlassXFCE glyph"
last_cache_line=$(grep -n 'gtk-update-icon-cache -f "$THEME"' config/hooks/live/0440-glassxfce-system-icons.hook.chroot | tail -1 | cut -d: -f1)
[ -n "$last_cache_line" ] || fail "system icon overlay must rebuild its icon cache"

say "checking graphical session handoff"
grep -qx 'x11-xserver-utils' "$packages" || fail "X root transition requires explicit x11-xserver-utils"
[ -f config/includes.chroot/usr/local/bin/glassxfce-display-setup ] || fail "missing pre-session display setup"
[ -f config/includes.chroot/etc/lightdm/lightdm.conf.d/50-glassxfce-display.conf ] || fail "missing LightDM display setup configuration"
grep -Fq 'xsetroot -solid' config/includes.chroot/usr/local/bin/glassxfce-display-setup || fail "display setup must paint the X root window before XFCE starts"

say "checking live session defaults"
[ -f config/includes.chroot/etc/live/config.conf.d/10-glassxfce.conf ] || fail "missing live-config defaults"
grep -q '^LIVE_USERNAME="live"$' config/includes.chroot/etc/live/config.conf.d/10-glassxfce.conf || fail "live username must remain live"
grep -q '^LIVE_HOSTNAME="glassxfce"$' config/includes.chroot/etc/live/config.conf.d/10-glassxfce.conf || fail "live hostname must remain glassxfce"
for pkg in live-config live-config-systemd user-setup sudo; do
  grep -qx "$pkg" "$packages" || fail "live session requires explicit package with APT recommends disabled: $pkg"
done
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
