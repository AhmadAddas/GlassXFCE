#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "squashfs-verify: usage: $0 path/to/glassxfce.iso" >&2; exit 2; }

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "squashfs-verify: missing command: $1" >&2
    exit 2
  }
}
need xorriso
need unsquashfs

fail() { printf 'squashfs-verify: error: %s\n' "$*" >&2; exit 1; }
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT HUP INT TERM

xorriso -osirrox on -indev "$ISO" \
  -extract /live/filesystem.squashfs "$TMP/filesystem.squashfs" >/dev/null 2>&1 || \
  fail "could not extract /live/filesystem.squashfs"
[ -s "$TMP/filesystem.squashfs" ] || fail "filesystem.squashfs is empty"

summary="$(unsquashfs -s "$TMP/filesystem.squashfs")"
printf '%s\n' "$summary"

printf '%s\n' "$summary" | grep -Eiq '^Compression[[:space:]]+xz$' || \
  fail "live filesystem is not compressed with XZ"
printf '%s\n' "$summary" | grep -Eiq '^Block size[[:space:]]+1048576$' || \
  fail "live filesystem does not use the 1 MiB block size"

echo "squashfs-verify: XZ compression and 1 MiB blocks confirmed"
