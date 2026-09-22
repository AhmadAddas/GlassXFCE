#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GTK="$ROOT/vendor/WhiteSur-gtk-theme"
ICONS="$ROOT/vendor/WhiteSur-icon-theme"
GTK_DEST="$ROOT/config/includes.chroot/usr/share/themes"
ICON_DEST="$ROOT/config/includes.chroot/usr/share/icons"

if [ ! -x "$GTK/install.sh" ] || [ ! -x "$ICONS/install.sh" ]; then
  echo "WhiteSur submodules are missing. Run: git submodule update --init --recursive" >&2
  exit 1
fi

rm -rf "$GTK_DEST"/WhiteSur* "$ICON_DEST"/WhiteSur*
mkdir -p "$GTK_DEST" "$ICON_DEST"

"$GTK/install.sh" -d "$GTK_DEST" -c light -c dark -o normal --silent-mode
"$ICONS/install.sh" -d "$ICON_DEST" -t default

if [ -f "$ROOT/assets/wallpapers/default.jpg" ]; then
  install -Dm0644 "$ROOT/assets/wallpapers/default.jpg" \
    "$ROOT/config/includes.chroot/usr/share/backgrounds/glassxfce/default.jpg"
else
  echo "Note: assets/wallpapers/default.jpg is missing; ISO will use the Debian/XFCE default wallpaper." >&2
fi
