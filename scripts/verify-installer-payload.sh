#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "usage: $0 path/to/glassxfce.iso" >&2; exit 2; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "installer-verify: missing command: $1" >&2; exit 2; }; }
need xorriso
need unsquashfs

fail() { printf 'installer-verify: error: %s\n' "$*" >&2; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

printf 'installer-verify: checking Debian installer payload\n'
if ! listing="$(xorriso -indev "$ISO" -ls /install.amd 2>/dev/null)"; then
  fail "/install.amd is missing from the ISO"
fi
printf '%s\n' "$listing" | grep -Eq '(^|[[:space:]])(vmlinuz|linux)([[:space:]]|$)' || fail "installer kernel is missing from /install.amd"
printf '%s\n' "$listing" | grep -Eq 'initrd' || fail "installer initrd is missing from /install.amd"

printf 'installer-verify: extracting live SquashFS\n'
xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$TMP/filesystem.squashfs" >/dev/null 2>&1
[ -s "$TMP/filesystem.squashfs" ] || fail "could not extract filesystem.squashfs"

for path in \
  usr/bin/calamares \
  usr/local/bin/glassxfce-installer \
  usr/share/applications/glassxfce-installer.desktop \
  etc/calamares; do
  if ! unsquashfs -ll "$TMP/filesystem.squashfs" "$path" 2>/dev/null | grep -q "$path"; then
    fail "missing installer component in live filesystem: /$path"
  fi
done

printf 'installer-verify: ok: Debian installer and Calamares payloads are present\n'
