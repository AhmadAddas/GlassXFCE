#!/usr/bin/env bash
set -euo pipefail

DIST="${1:-dist}"
VERSION="${2:-${VERSION:-}}"

fail() { printf 'release-check: error: %s\n' "$*" >&2; exit 1; }
[ -d "$DIST" ] || fail "missing dist directory: $DIST"

mapfile -t ISOS < <(find "$DIST" -maxdepth 1 -type f -name 'glassxfce-*-amd64.iso' -print | sort)
[ "${#ISOS[@]}" -eq 1 ] || fail "expected exactly one amd64 ISO, found ${#ISOS[@]}"
ISO="${ISOS[0]}"
BASE="$(basename "$ISO")"

if [ -n "$VERSION" ]; then
  case "$VERSION" in
    *[!0-9A-Za-z._-]*|'') fail "unsafe version label: $VERSION" ;;
  esac
  [ "$BASE" = "glassxfce-${VERSION}-amd64.iso" ] || \
    fail "ISO filename does not match version $VERSION: $BASE"
fi

[ -s "$ISO" ] || fail "ISO is empty"
# This is deliberately conservative: a Debian XFCE live/install image should
# never be tiny. It catches placeholder/truncated files without enforcing a
# release-size target.
SIZE="$(stat -c %s "$ISO")"
[ "$SIZE" -ge 104857600 ] || fail "ISO is suspiciously small (${SIZE} bytes)"

MAX_ISO_MIB="${MAX_ISO_MIB:-1800}"
case "$MAX_ISO_MIB" in
  *[!0-9]*|'') fail "MAX_ISO_MIB must be a positive integer" ;;
esac
[ "$MAX_ISO_MIB" -gt 0 ] || fail "MAX_ISO_MIB must be greater than zero"
MAX_ISO_BYTES=$((MAX_ISO_MIB * 1024 * 1024))
if [ "$SIZE" -gt "$MAX_ISO_BYTES" ]; then
  actual_mib=$(( (SIZE + 1024 * 1024 - 1) / (1024 * 1024) ))
  fail "ISO is ${actual_mib} MiB; release budget is ${MAX_ISO_MIB} MiB"
fi

INDIVIDUAL="$ISO.sha256"
[ -f "$INDIVIDUAL" ] || fail "missing per-ISO checksum: $INDIVIDUAL"
(
  cd "$DIST"
  sha256sum -c "$(basename "$INDIVIDUAL")"
)

[ -f "$DIST/SHA256SUMS" ] || fail "missing SHA256SUMS"
(
  cd "$DIST"
  sha256sum -c SHA256SUMS
)

[ -s "$DIST/build-info.txt" ] || fail "missing build-info.txt"
grep -Fq "image=$BASE" "$DIST/build-info.txt" || fail "build-info does not name the ISO"

actual_mib=$(( (SIZE + 1024 * 1024 - 1) / (1024 * 1024) ))
printf 'release-check: ok: %s (%s bytes, %s MiB; budget %s MiB)\n' "$BASE" "$SIZE" "$actual_mib" "$MAX_ISO_MIB"
