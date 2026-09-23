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

iso_has() {
  xorriso -indev "$ISO" -ls "$1" >/dev/null 2>&1
}

printf 'installer-verify: checking Debian installer payload\n'
# Debian live-build for Trixie places d-i under /install. Keep a legacy
# /install.amd fallback for older images so the verifier remains useful.
INSTALL_DIR=""
for candidate in /install /install.amd; do
  if iso_has "$candidate"; then
    INSTALL_DIR="$candidate"
    break
  fi
done
[ -n "$INSTALL_DIR" ] || fail "Debian installer directory is missing (/install)"

iso_has "$INSTALL_DIR/vmlinuz" || iso_has "$INSTALL_DIR/linux" || \
  fail "installer kernel is missing from $INSTALL_DIR"
iso_has "$INSTALL_DIR/initrd.gz" || iso_has "$INSTALL_DIR/initrd" || \
  fail "installer initrd is missing from $INSTALL_DIR"

# The project enables the graphical Debian installer, so protect that payload too.
iso_has "$INSTALL_DIR/gtk/vmlinuz" || iso_has "$INSTALL_DIR/gtk/linux" || \
  fail "graphical installer kernel is missing from $INSTALL_DIR/gtk"
iso_has "$INSTALL_DIR/gtk/initrd.gz" || iso_has "$INSTALL_DIR/gtk/initrd" || \
  fail "graphical installer initrd is missing from $INSTALL_DIR/gtk"

printf 'installer-verify: Debian installer found under %s\n' "$INSTALL_DIR"
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
