#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "boot-menu-verify: usage: $0 path/to/glassxfce.iso" >&2; exit 2; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "boot-menu-verify: missing command: $1" >&2
    exit 2
  }
}
need xorriso

fail() { printf 'boot-menu-verify: error: %s\n' "$*" >&2; exit 1; }
TMP="$(mktemp -d)"
cleanup_tmp() {
  # ISO directories can be restored read-only. Make the temporary tree
  # owner-writable before removing it so successful verification does not
  # fail during the EXIT trap.
  chmod -R u+rwX "$TMP" 2>/dev/null || true
  rm -rf -- "$TMP" 2>/dev/null || true
}
trap cleanup_tmp EXIT HUP INT TERM

# GRUB is used for UEFI and is also generated from our custom menu template.
echo "boot-menu-verify: checking GRUB live/install choices"
xorriso -osirrox on:auto_chmod_on -indev "$ISO" -extract /boot/grub "$TMP/grub" >/dev/null 2>&1 || \
  fail "could not extract /boot/grub"
grep -RFiq 'Try GlassXFCE Live' "$TMP/grub" || fail "GRUB menu is missing the Live choice"
grep -RFiq 'Install GlassXFCE' "$TMP/grub" || fail "GRUB menu is missing the Install choice"

# Syslinux/ISOLINUX is the legacy BIOS path. Its installer submenu is generated
# by live-build, so require both our Live label and an installer entry/config.
echo "boot-menu-verify: checking BIOS live/install choices"
xorriso -osirrox on:auto_chmod_on -indev "$ISO" -extract /isolinux "$TMP/isolinux" >/dev/null 2>&1 || \
  fail "could not extract /isolinux"
grep -RFiq 'Try GlassXFCE Live' "$TMP/isolinux" || fail "BIOS menu is missing the Live choice"
if ! grep -REiq 'install|debian installer' "$TMP/isolinux"; then
  fail "BIOS menu does not expose an installer choice"
fi

echo "boot-menu-verify: Live and Install choices are present for GRUB and BIOS menus"
