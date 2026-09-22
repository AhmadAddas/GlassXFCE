#!/usr/bin/env bash
set -euo pipefail

if [ ! -d .git ]; then
  echo "Run this from the root of a Git repository." >&2
  exit 1
fi

git submodule add https://github.com/vinceliuice/WhiteSur-gtk-theme.git vendor/WhiteSur-gtk-theme
git submodule add https://github.com/vinceliuice/WhiteSur-icon-theme.git vendor/WhiteSur-icon-theme

echo "Theme submodules added. Commit .gitmodules and vendor/* to pin the current commits."
