#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  echo "usage: $0 path/to/glassxfce.iso" >&2
  exit 2
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "glass-assets: missing command: $1" >&2
    exit 2
  }
}
need xorriso
need unsquashfs

TMP="$(mktemp -d "${TMPDIR:-/tmp}/glassxfce-assets.XXXXXX")"
cleanup_tmp() {
  # ISO directories can be restored read-only. Make the temporary tree
  # owner-writable before removing it so successful verification does not
  # fail during the EXIT trap.
  chmod -R u+rwX "$TMP" 2>/dev/null || true
  rm -rf -- "$TMP" 2>/dev/null || true
}
trap cleanup_tmp EXIT HUP INT TERM

SQUASHFS="$TMP/filesystem.squashfs"
echo "glass-assets: extracting live root metadata"
xorriso -osirrox on -indev "$ISO" \
  -extract /live/filesystem.squashfs "$SQUASHFS" >/dev/null 2>&1
unsquashfs -ll "$SQUASHFS" > "$TMP/list.txt"

require_path() {
  local path="$1"
  if ! grep -Fq "squashfs-root/$path" "$TMP/list.txt"; then
    echo "glass-assets: missing protected asset: /$path" >&2
    exit 1
  fi
  echo "glass-assets: ok: /$path"
}

# Theme and visual identity
require_path usr/share/themes/WhiteSur-Light
require_path usr/share/themes/WhiteSur-Dark
require_path usr/share/icons/WhiteSur
require_path usr/share/backgrounds/glassxfce/aurora.svg
require_path usr/share/backgrounds/glassxfce/midnight-glass.svg
require_path usr/share/backgrounds/glassxfce/silver-wave.svg
require_path usr/share/themes/GlassXFCE/xfce-notify-4.0/gtk.css

# Glass behavior/configuration
require_path etc/skel/.config/picom/picom.conf
require_path etc/skel/.config/picom/picom-fallback.conf
require_path etc/skel/.face
require_path etc/skel/.config/rofi/config.rasi
require_path etc/skel/.config/rofi/glass.rasi
require_path etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml
require_path etc/skel/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml
require_path usr/local/bin/glassxfce-appearance
require_path usr/local/bin/glassxfce-launcher

# Branded boot/login/installer experience carried by the live root
require_path usr/share/plymouth/themes/glassxfce/glassxfce.plymouth
require_path etc/lightdm/lightdm-gtk-greeter.conf.d/50-glassxfce.conf
require_path etc/calamares/branding/glassxfce/welcome.png
require_path etc/calamares/branding/glassxfce/branding.desc
require_path usr/share/icons/hicolor/scalable/apps/glassxfce-installer.svg
require_path usr/share/applications/glassxfce-installer.desktop

echo "glass-assets: all protected GlassXFCE assets are present"
