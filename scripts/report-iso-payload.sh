#!/usr/bin/env bash
set -euo pipefail
ISO="${1:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "usage: $0 path/to/glassxfce.iso" >&2; exit 2; }
command -v xorriso >/dev/null 2>&1 || { echo "payload-report: missing xorriso" >&2; exit 2; }
TMP="$(mktemp -d "${TMPDIR:-/tmp}/glassxfce-payload.XXXXXX")"
cleanup_tmp() {
  # ISO directories can be restored read-only. Make the temporary tree
  # owner-writable before removing it so successful verification does not
  # fail during the EXIT trap.
  chmod -R u+rwX "$TMP" 2>/dev/null || true
  rm -rf -- "$TMP" 2>/dev/null || true
}
trap cleanup_tmp EXIT HUP INT TERM
SQ="$TMP/filesystem.squashfs"
xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$SQ" >/dev/null 2>&1
iso_bytes=$(stat -c %s "$ISO")
sq_bytes=$(stat -c %s "$SQ")
overhead=$((iso_bytes - sq_bytes))
python3 - "$ISO" "$iso_bytes" "$sq_bytes" "$overhead" <<'PY'
from pathlib import Path
import sys
iso, total, squash, overhead = sys.argv[1], *map(int, sys.argv[2:])
def mib(n): return n / (1024 * 1024)
print('### ISO payload breakdown')
print()
print(f'- Image: `{Path(iso).name}`')
print(f'- Total ISO: **{mib(total):.1f} MiB**')
print(f'- Compressed Live filesystem (SquashFS): **{mib(squash):.1f} MiB**')
print(f'- Bootloader / installer / ISO overhead: **{mib(overhead):.1f} MiB**')
print(f'- SquashFS share of ISO: **{(squash / total * 100 if total else 0):.1f}%**')
PY
