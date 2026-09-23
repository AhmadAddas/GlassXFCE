#!/usr/bin/env bash
set -euo pipefail

if [ ! -d .git ]; then
  echo "Run this from the root of a Git repository." >&2
  exit 1
fi

GTK_TAG="2026-09-10"
ICON_TAG="2026-09-10"

add_pinned_submodule() {
  local url="$1" path="$2" tag="$3"
  if [ ! -e "$path" ]; then
    git submodule add "$url" "$path"
  fi
  git -C "$path" fetch --depth 1 origin "refs/tags/$tag:refs/tags/$tag"
  git -C "$path" checkout --detach "$tag"
}

add_pinned_submodule \
  https://github.com/vinceliuice/WhiteSur-gtk-theme.git \
  vendor/WhiteSur-gtk-theme "$GTK_TAG"
add_pinned_submodule \
  https://github.com/vinceliuice/WhiteSur-icon-theme.git \
  vendor/WhiteSur-icon-theme "$ICON_TAG"

echo "Pinned WhiteSur theme submodules to the $GTK_TAG release. Commit .gitmodules and vendor/* gitlinks."
