#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "live-build needs root. Run locally with: sudo ./build.sh" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

VERSION="${VERSION:-dev}"
case "$VERSION" in
  *[!0-9A-Za-z._-]*|'')
    echo "VERSION may contain only letters, numbers, dot, underscore and dash." >&2
    exit 2
    ;;
esac
export VERSION

./scripts/stage-design.sh
./scripts/stage-identity.sh
lb clean --purge || true
./auto/config
lb build

mkdir -p dist
ISO_SRC="live-image-amd64.hybrid.iso"
[ -f "$ISO_SRC" ] || ISO_SRC="glassxfce-amd64.hybrid.iso"
if [ ! -f "$ISO_SRC" ]; then
  echo "Could not find the generated ISO." >&2
  find . -maxdepth 1 -type f -name '*.iso' -print >&2
  exit 1
fi

ISO_DST="dist/glassxfce-${VERSION}-amd64.iso"
mv "$ISO_SRC" "$ISO_DST"
sha256sum "$(basename "$ISO_DST")" > "$ISO_DST.sha256.tmp"
# Make the checksum portable by storing only the ISO basename.
sed "s#  .*#  $(basename "$ISO_DST")#" "$ISO_DST.sha256.tmp" > "$ISO_DST.sha256"
rm -f "$ISO_DST.sha256.tmp"
cp "$ISO_DST.sha256" dist/SHA256SUMS

COMMIT="unknown"
if command -v git >/dev/null 2>&1; then
  COMMIT="$(git rev-parse HEAD 2>/dev/null || printf unknown)"
fi
cat > dist/build-info.txt <<INFO
project=GlassXFCE
version=$VERSION
architecture=amd64
debian_suite=trixie
image=$(basename "$ISO_DST")
git_commit=$COMMIT
INFO

echo "Built: $ISO_DST"
