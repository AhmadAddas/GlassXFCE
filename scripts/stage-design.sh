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

find_release_archive() {
  local root="$1" variant="$2" exact candidate
  exact="$root/release/WhiteSur-${variant}.tar.xz"
  if [ -f "$exact" ]; then
    printf '%s\n' "$exact"
    return 0
  fi

  # Upstream occasionally adds a desktop-version suffix to the precompiled
  # archive name. Accept one unambiguous matching archive, but fail loudly if
  # the release layout changes in a way that needs a deliberate update here.
  shopt -s nullglob
  local matches=("$root"/release/WhiteSur-"$variant"*.tar.xz)
  shopt -u nullglob
  if [ "${#matches[@]}" -eq 1 ]; then
    printf '%s\n' "${matches[0]}"
    return 0
  fi

  echo "WhiteSur ${variant} precompiled archive was not found in $root/release." >&2
  if [ "${#matches[@]}" -gt 1 ]; then
    printf 'Candidates:\n' >&2
    printf '  %s\n' "${matches[@]}" >&2
  fi
  return 1
}

stage_gtk_release() {
  local source="$1" dest="$2" variant archive tmp
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' RETURN

  for variant in Light Dark; do
    archive="$(find_release_archive "$source" "$variant")"
    echo "Staging precompiled WhiteSur ${variant} theme from $(basename "$archive")"
    tar -xJf "$archive" -C "$tmp"
  done

  # The release tarballs contain the complete compiled themes, including XFWM
  # decorations. Copy only the requested light/dark variants into the image.
  find "$tmp" -mindepth 1 -maxdepth 1 -type d -name 'WhiteSur-*' -exec cp -a {} "$dest/" \;

  if [ ! -f "$dest/WhiteSur-Light/index.theme" ] || [ ! -f "$dest/WhiteSur-Dark/index.theme" ]; then
    echo "WhiteSur release archives did not produce WhiteSur-Light and WhiteSur-Dark themes." >&2
    find "$dest" -maxdepth 2 -type f -name index.theme -print >&2 || true
    return 1
  fi

  rm -rf "$tmp"
  trap - RETURN
}

GTK="$ROOT/vendor/WhiteSur-gtk-theme"
ICONS="$ROOT/vendor/WhiteSur-icon-theme"

# A checked-out submodule/source tree is useful for offline development. Fresh
# clones and CI automatically fetch the pinned release snapshots instead.
# GTK staging uses upstream's precompiled release archives instead of executing
# install.sh. This avoids CI-only installer/app side effects while keeping the
# exact WhiteSur Light/Dark visual assets in the ISO.
if [ ! -d "$GTK/release" ]; then
  GTK="$CACHE/WhiteSur-gtk-theme"
  fetch_pinned_theme \
    "WhiteSur GTK" \
    "https://github.com/vinceliuice/WhiteSur-gtk-theme.git" \
    "$GTK_TAG" "$GTK_SHA_PREFIX" "$GTK"
fi

if [ ! -f "$ICONS/install.sh" ]; then
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

stage_gtk_release "$GTK" "$GTK_DEST"

stage_icon_theme() {
  local source="$1" dest="$2" shim
  shim="$(mktemp -d)"
  trap 'rm -rf "$shim"' RETURN

  # Upstream generates gtk icon caches at the very end of install.sh. The CI
  # staging container does not need GTK runtime tooling just to assemble files,
  # so provide a temporary no-op cache command here. A live-build chroot hook
  # refreshes caches later when the command exists in the target image.
  cat > "$shim/gtk-update-icon-cache" <<'EOF'
#!/bin/sh
exit 0
EOF
  chmod +x "$shim/gtk-update-icon-cache"

  echo "Staging WhiteSur icon theme"
  PATH="$shim:$PATH" bash "$source/install.sh" -d "$dest" -t default

  for variant in WhiteSur WhiteSur-light WhiteSur-dark; do
    if [ ! -f "$dest/$variant/index.theme" ]; then
      echo "WhiteSur icon staging did not produce $dest/$variant/index.theme" >&2
      return 1
    fi
  done

  rm -rf "$shim"
  trap - RETURN
}

stage_icon_theme "$ICONS" "$ICON_DEST"

WALL_DEST="$ROOT/config/includes.chroot/usr/share/backgrounds/glassxfce"
rm -rf "$WALL_DEST"
mkdir -p "$WALL_DEST"
for wallpaper in "$ROOT"/assets/wallpapers/*.svg; do
  [ -f "$wallpaper" ] || continue
  install -m0644 "$wallpaper" "$WALL_DEST/$(basename "$wallpaper")"
done
[ -f "$WALL_DEST/aurora.svg" ] || { echo "GlassXFCE default wallpaper is missing." >&2; exit 1; }

# WhiteSur keeps the macOS-inspired first choice. Papirus is packaged as a very
# broad fallback for applications that WhiteSur does not cover.
for index in "$ICON_DEST"/WhiteSur*/index.theme; do
  [ -f "$index" ] || continue
  if grep -q '^Inherits=' "$index"; then
    sed -i 's/^Inherits=.*/Inherits=Papirus,Adwaita,hicolor/' "$index"
  else
    printf '\nInherits=Papirus,Adwaita,hicolor\n' >> "$index"
  fi
done
