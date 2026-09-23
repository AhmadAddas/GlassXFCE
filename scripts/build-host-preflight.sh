#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MIN_BUILD_FREE_GIB="${MIN_BUILD_FREE_GIB:-10}"

fail() { printf 'build-host-preflight: error: %s\n' "$*" >&2; exit 1; }

[ "${EUID}" -eq 0 ] || fail "live-build must run as root"
case "$MIN_BUILD_FREE_GIB" in
  ''|*[!0-9]*) fail "MIN_BUILD_FREE_GIB must be an integer" ;;
esac
[ "$MIN_BUILD_FREE_GIB" -gt 0 ] || fail "MIN_BUILD_FREE_GIB must be greater than zero"

for command in lb debootstrap mksquashfs unsquashfs xorriso git rsync xz file sassc; do
  command -v "$command" >/dev/null 2>&1 || fail "missing required build command: $command"
done

free_kib="$(df -Pk "$ROOT" | awk 'NR==2 {print $4}')"
case "$free_kib" in
  ''|*[!0-9]*) fail "could not determine free disk space" ;;
esac
required_kib=$((MIN_BUILD_FREE_GIB * 1024 * 1024))
if [ "$free_kib" -lt "$required_kib" ]; then
  free_gib=$((free_kib / 1024 / 1024))
  fail "only about ${free_gib} GiB free; at least ${MIN_BUILD_FREE_GIB} GiB is required"
fi

free_gib=$((free_kib / 1024 / 1024))
echo "build-host-preflight: build tools present; about ${free_gib} GiB free"
