#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VERSION="${VERSION:-dev}"
TEMPLATE="$ROOT/config/branding/os-release.in"
ETC="$ROOT/config/includes.chroot/etc"

case "$VERSION" in
  *[!0-9A-Za-z._-]*|'')
    echo "VERSION may contain only letters, numbers, dot, underscore and dash." >&2
    exit 2
    ;;
esac

mkdir -p "$ETC"
sed "s/@VERSION@/$VERSION/g" "$TEMPLATE" > "$ETC/os-release"
cat > "$ETC/glassxfce-release" <<RELEASE
GlassXFCE $VERSION
Base: Debian 13 (Trixie)
Architecture: amd64
RELEASE
cat > "$ETC/issue" <<ISSUE
GlassXFCE $VERSION \\n \\l
ISSUE
cat > "$ETC/issue.net" <<ISSUENET
GlassXFCE $VERSION
ISSUENET
