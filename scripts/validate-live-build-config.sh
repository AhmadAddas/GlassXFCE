#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

command -v lb >/dev/null 2>&1 || {
  echo "live-build-config: lb is not installed" >&2
  exit 2
}

echo "live-build-config: validating auto/config with the installed live-build"
sh ./auto/config --validate

echo "live-build-config: configuration accepted"
