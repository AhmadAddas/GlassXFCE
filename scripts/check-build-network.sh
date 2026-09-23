#!/usr/bin/env bash
set -euo pipefail

DEBIAN_PROBE="${DEBIAN_PROBE:-https://deb.debian.org/debian/dists/trixie/InRelease}"
GITHUB_PROBE="${GITHUB_PROBE:-https://github.com/vinceliuice/WhiteSur-gtk-theme.git/info/refs?service=git-upload-pack}"

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "network-preflight: missing command: $1" >&2
    exit 2
  }
}
need curl

probe() {
  local label="$1" url="$2"
  echo "network-preflight: checking $label"
  curl \
    --fail \
    --silent \
    --show-error \
    --location \
    --retry 3 \
    --retry-all-errors \
    --connect-timeout 10 \
    --max-time 45 \
    --output /dev/null \
    "$url"
}

probe "Debian Trixie archive" "$DEBIAN_PROBE"
probe "WhiteSur source host" "$GITHUB_PROBE"

echo "network-preflight: required build sources are reachable"
