#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "usage: $0 path/to/glassxfce.iso" >&2; exit 2; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "secure-boot: missing command: $1" >&2; exit 2; }; }
need xorriso
need sbverify
fail() { printf 'secure-boot: error: %s\n' "$*" >&2; exit 1; }

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM
EFI="$TMP/BOOTX64.EFI"
FOUND=""

for candidate in /EFI/BOOT/BOOTX64.EFI /EFI/boot/bootx64.efi /efi/boot/bootx64.efi; do
  if xorriso -osirrox on -indev "$ISO" -extract "$candidate" "$EFI" >/dev/null 2>&1; then
    if [ -s "$EFI" ]; then
      FOUND="$candidate"
      break
    fi
  fi
done

[ -n "$FOUND" ] || fail "could not extract the default x86_64 UEFI bootloader"

OUTPUT="$(sbverify --list "$EFI" 2>&1)" || {
  printf '%s\n' "$OUTPUT" >&2
  fail "UEFI bootloader is not recognized as a signed PE image"
}
printf '%s\n' "$OUTPUT" | grep -qi 'signature' || fail "no Authenticode signature reported for $FOUND"

printf 'secure-boot: ok: signed UEFI bootloader found at %s\n' "$FOUND"
