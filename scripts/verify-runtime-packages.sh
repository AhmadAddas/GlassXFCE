#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
[ -n "$ISO" ] && [ -f "$ISO" ] || { echo "usage: $0 path/to/glassxfce.iso" >&2; exit 2; }
command -v xorriso >/dev/null 2>&1 || { echo "runtime-packages: missing xorriso" >&2; exit 2; }
command -v unsquashfs >/dev/null 2>&1 || { echo "runtime-packages: missing unsquashfs" >&2; exit 2; }

TMP="$(mktemp -d "${TMPDIR:-/tmp}/glassxfce-runtime.XXXXXX")"
cleanup_tmp() {
  # ISO directories can be restored read-only. Make the temporary tree
  # owner-writable before removing it so successful verification does not
  # fail during the EXIT trap.
  chmod -R u+rwX "$TMP" 2>/dev/null || true
  rm -rf -- "$TMP" 2>/dev/null || true
}
trap cleanup_tmp EXIT HUP INT TERM
SQUASHFS="$TMP/filesystem.squashfs"
STATUS="$TMP/status"

xorriso -osirrox on -indev "$ISO" -extract /live/filesystem.squashfs "$SQUASHFS" >/dev/null 2>&1
unsquashfs -cat "$SQUASHFS" var/lib/dpkg/status > "$STATUS"

python3 - "$STATUS" <<'PY'
from pathlib import Path
import sys
status = Path(sys.argv[1]).read_text(errors='replace')
installed = set()
for para in status.split('\n\n'):
    fields = {}
    for line in para.splitlines():
        if ': ' in line:
            k, v = line.split(': ', 1)
            fields[k] = v
    if fields.get('Status') == 'install ok installed' and fields.get('Package'):
        installed.add(fields['Package'])
required = [
    'live-config', 'live-config-systemd', 'user-setup', 'sudo', 'papirus-icon-theme',
    'xfce4-power-manager-plugins', 'xfce4-pulseaudio-plugin', 'pipewire-audio', 'network-manager-gnome',
    'bluez', 'blueman', 'colord', 'xiccd',
    'firmware-iwlwifi', 'firmware-realtek', 'firmware-atheros',
    'xserver-xorg-core', 'xserver-xorg-video-all', 'libgl1-mesa-dri',
    'mesa-vulkan-drivers',
    'firmware-brcm80211', 'firmware-amd-graphics', 'firmware-intel-graphics',
    'firmware-nvidia-graphics', 'firmware-misc-nonfree',
    'firmware-intel-sound', 'firmware-sof-signed',
    'intel-microcode', 'amd64-microcode',
]
missing = [p for p in required if p not in installed]
for pkg in required:
    print(f"runtime-packages: {'ok' if pkg in installed else 'MISSING'}: {pkg}")
if missing:
    raise SystemExit('runtime-packages: missing required packages: ' + ', '.join(missing))
print(f'runtime-packages: verified {len(required)} live-session/hardware/audio/network packages')
PY
