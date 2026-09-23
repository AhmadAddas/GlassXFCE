#!/usr/bin/env bash
set -euo pipefail

TAG="${1:-}"
VERSION="${2:-}"

fail() { printf 'release-version: error: %s\n' "$*" >&2; exit 1; }

[ -n "$TAG" ] || fail "missing tag"
[ -n "$VERSION" ] || fail "missing resolved version"

if [[ ! "$TAG" =~ ^v([0-9]+)\.([0-9]+)\.([0-9]+)(-[0-9A-Za-z][0-9A-Za-z.-]*)?$ ]]; then
  fail "tag must use semantic form vMAJOR.MINOR.PATCH or vMAJOR.MINOR.PATCH-prerelease: $TAG"
fi

EXPECTED="${TAG#v}"
[ "$VERSION" = "$EXPECTED" ] || fail "resolved version $VERSION does not match tag $TAG"

printf 'release-version: ok: %s -> %s\n' "$TAG" "$VERSION"
