#!/usr/bin/env bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
  echo "live-build needs root. Run locally with: sudo ./build.sh" >&2
  exit 1
fi

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT"

./scripts/stage-design.sh
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

VERSION="${VERSION:-dev}"
ISO_DST="dist/glassxfce-${VERSION}-amd64.iso"
mv "$ISO_SRC" "$ISO_DST"
sha256sum "$ISO_DST" > "$ISO_DST.sha256"
echo "Built: $ISO_DST"
