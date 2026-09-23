#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
VERSION="${2:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "usage: $0 path/to/glassxfce.iso VERSION" >&2; exit 2; }
[ -n "$VERSION" ] || { echo "usage: $0 path/to/glassxfce.iso VERSION" >&2; exit 2; }

need() { command -v "$1" >/dev/null 2>&1 || { echo "identity-verify: missing command: $1" >&2; exit 2; }; }
need xorriso
need unsquashfs
fail() { printf 'identity-verify: error: %s\n' "$*" >&2; exit 1; }

TMP="$(mktemp -d)"
cleanup_tmp() {
  # ISO directories can be restored read-only. Make the temporary tree
  # owner-writable before removing it so successful verification does not
  # fail during the EXIT trap.
  chmod -R u+rwX "$TMP" 2>/dev/null || true
  rm -rf -- "$TMP" 2>/dev/null || true
}
trap cleanup_tmp EXIT HUP INT TERM
xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$TMP/filesystem.squashfs" >/dev/null 2>&1
[ -s "$TMP/filesystem.squashfs" ] || fail "could not extract filesystem.squashfs"

OS_RELEASE="$(unsquashfs -cat "$TMP/filesystem.squashfs" etc/os-release 2>/dev/null)" || fail "missing /etc/os-release in live filesystem"
RELEASE_FILE="$(unsquashfs -cat "$TMP/filesystem.squashfs" etc/glassxfce-release 2>/dev/null)" || fail "missing /etc/glassxfce-release"

printf '%s\n' "$OS_RELEASE" | grep -Fxq 'NAME="GlassXFCE"' || fail "NAME is not GlassXFCE"
printf '%s\n' "$OS_RELEASE" | grep -Fxq 'ID=glassxfce' || fail "ID is not glassxfce"
printf '%s\n' "$OS_RELEASE" | grep -Fxq 'ID_LIKE=debian' || fail "ID_LIKE is not debian"
printf '%s\n' "$OS_RELEASE" | grep -Fxq 'VERSION_CODENAME=trixie' || fail "VERSION_CODENAME is not trixie"
printf '%s\n' "$OS_RELEASE" | grep -Fxq "VERSION_ID=\"$VERSION\"" || fail "VERSION_ID does not match $VERSION"
printf '%s\n' "$RELEASE_FILE" | grep -Fxq "GlassXFCE $VERSION" || fail "glassxfce-release does not match $VERSION"
printf '%s\n' "$RELEASE_FILE" | grep -Fxq 'Base: Debian 13 (Trixie)' || fail "Debian base identity is missing"

printf 'identity-verify: ok: GlassXFCE %s on Debian 13 Trixie\n' "$VERSION"
