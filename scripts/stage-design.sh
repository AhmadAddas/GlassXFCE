#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

GTK_TAG="2026-09-10"
GTK_SHA_PREFIX="99247ec"
ICON_TAG="2026-09-10"
ICON_SHA_PREFIX="73d8040"
CACHE="$ROOT/.cache/theme-sources"

fetch_pinned_theme() {
  local name="$1" url="$2" tag="$3" expected="$4" dest="$5"
  rm -rf "$dest"
  mkdir -p "$(dirname "$dest")"
  git clone --quiet --depth 1 --branch "$tag" "$url" "$dest"
  local actual
  actual="$(git -C "$dest" rev-parse --short=7 HEAD)"
  if [ "$actual" != "$expected" ]; then
    echo "$name tag $tag resolved to $actual, expected $expected; refusing a moved tag." >&2
    exit 1
  fi
}

GTK="$ROOT/vendor/WhiteSur-gtk-theme"
ICONS="$ROOT/vendor/WhiteSur-icon-theme"

# A checked-out submodule/source tree is useful for offline development. Fresh
# clones and CI automatically fetch the pinned release snapshots instead.
if [ ! -x "$GTK/install.sh" ]; then
  GTK="$CACHE/WhiteSur-gtk-theme"
  fetch_pinned_theme \
    "WhiteSur GTK" \
    "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" \
    "$GTK_TAG" "$GTK_SHA_PREFIX" "$GTK"
fi

if [ ! -x "$ICONS/install.sh" ]; then
  ICONS="$CACHE/WhiteSur-icon-theme"
  fetch_pinned_theme \
    "WhiteSur icons" \
    "https://github.com/vinceliuice/WhiteSur-icon-theme.git" \
    "$ICON_TAG" "$ICON_SHA_PREFIX" "$ICONS"
fi

GTK_DEST="$ROOT/config/includes.chroot/usr/share/themes"
ICON_DEST="$ROOT/config/includes.chroot/usr/share/icons"
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
