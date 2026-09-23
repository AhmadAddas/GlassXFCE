#!/usr/bin/env bash
set -euo pipefail

DIST="${1:-dist}"
VERSION="${2:-}"
EXPECTED_COMMIT="${3:-}"

fail() { printf 'metadata-verify: error: %s\n' "$*" >&2; exit 1; }
[ -d "$DIST" ] || fail "missing dist directory: $DIST"
[ -n "$VERSION" ] || fail "missing expected version"
[ -n "$EXPECTED_COMMIT" ] || fail "missing expected source commit"

INFO="$DIST/build-info.txt"
[ -s "$INFO" ] || fail "missing build-info.txt"

get_value() {
  local key="$1"
  sed -n "s/^${key}=//p" "$INFO" | tail -n 1
}

PROJECT="$(get_value project)"
ACTUAL_VERSION="$(get_value version)"
ARCH="$(get_value architecture)"
SUITE="$(get_value debian_suite)"
IMAGE="$(get_value image)"
COMMIT="$(get_value git_commit)"

[ "$PROJECT" = "GlassXFCE" ] || fail "unexpected project: $PROJECT"
[ "$ACTUAL_VERSION" = "$VERSION" ] || fail "version mismatch: $ACTUAL_VERSION != $VERSION"
[ "$ARCH" = "amd64" ] || fail "unexpected architecture: $ARCH"
[ "$SUITE" = "trixie" ] || fail "unexpected Debian suite: $SUITE"
[ "$IMAGE" = "glassxfce-${VERSION}-amd64.iso" ] || fail "unexpected image name: $IMAGE"
[ "$COMMIT" = "$EXPECTED_COMMIT" ] || fail "source commit mismatch: $COMMIT != $EXPECTED_COMMIT"
[ -f "$DIST/$IMAGE" ] || fail "metadata names an ISO that does not exist: $IMAGE"

printf 'metadata-verify: ok: %s from %s\n' "$IMAGE" "$COMMIT"
