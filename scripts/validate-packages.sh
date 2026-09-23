#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIST="$ROOT/config/package-lists/desktop.list.chroot"

command -v apt-cache >/dev/null 2>&1 || {
  echo "validate-packages: apt-cache is required (run this inside Debian 13)." >&2
  exit 2
}

mapfile -t packages < <(awk 'NF && $1 !~ /^#/ {print $1}' "$LIST")
[ "${#packages[@]}" -gt 0 ] || {
  echo "validate-packages: package list is empty." >&2
  exit 1
}

missing=0
for package in "${packages[@]}"; do
  if apt-cache show "$package" >/dev/null 2>&1; then
    printf 'package ok: %s\n' "$package"
  else
    printf 'package missing: %s\n' "$package" >&2
    missing=1
  fi
done

if [ "$missing" -ne 0 ]; then
  echo "validate-packages: one or more packages are unavailable from the configured Debian repositories." >&2
  exit 1
fi

echo "validate-packages: ${#packages[@]} explicit packages resolve successfully."
