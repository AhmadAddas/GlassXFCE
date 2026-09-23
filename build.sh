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

# Do not rely on Git executable bits. GitHub web uploads and ZIP extraction
# can store shell helpers as 0644 even when the original repository used 0755.
chmod +x auto/config auto/clean
find config/hooks -type f \( -name '*.hook.chroot' -o -name '*.hook.binary' \) -exec chmod +x {} +
find config/includes.chroot/usr/local/bin -maxdepth 1 -type f -exec chmod +x {} +
chmod +x config/includes.chroot/etc/skel/Desktop/install-glassxfce.desktop

bash ./scripts/stage-design.sh
bash ./scripts/stage-identity.sh
lb clean --purge || true
bash ./auto/config

# live-build creates filesystem.squashfs during binary_rootfs, after binary hooks.
# Pass the size-focused options directly to that mksquashfs invocation instead
# of trying to repack an image that does not exist yet.
export MKSQUASHFS_OPTIONS="-b 1M -Xdict-size 100% -Xbcj x86"
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
ISO_BASE="$(basename "$ISO_DST")"
# Generate the checksum from inside dist/ so the checksum file contains only
# the portable ISO basename rather than a repository-relative path.
( cd dist && sha256sum "$ISO_BASE" ) > "$ISO_DST.sha256"
cp "$ISO_DST.sha256" dist/SHA256SUMS

COMMIT="${GIT_COMMIT:-unknown}"
if [ "$COMMIT" = "unknown" ] && command -v git >/dev/null 2>&1; then
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
