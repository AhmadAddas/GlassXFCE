#!/usr/bin/env bash
set -euo pipefail

ISO="${1:-}"
if [ -z "$ISO" ] || [ ! -f "$ISO" ]; then
  echo "usage: $0 path/to/glassxfce.iso" >&2
  exit 2
fi

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "smoke: missing command: $1" >&2
    exit 2
  }
}
need xorriso
need qemu-system-x86_64
need timeout

echo "smoke: inspecting ISO filesystem"
root_listing="$(xorriso -indev "$ISO" -ls / 2>/dev/null)"
live_listing="$(xorriso -indev "$ISO" -ls /live 2>/dev/null)"
printf '%s\n' "$root_listing" | grep -q 'live' || { echo "smoke: /live is missing" >&2; exit 1; }
printf '%s\n' "$live_listing" | grep -q 'filesystem.squashfs' || { echo "smoke: squashfs is missing" >&2; exit 1; }
printf '%s\n' "$live_listing" | grep -Eq 'vmlinuz|linux' || { echo "smoke: live kernel is missing" >&2; exit 1; }
printf '%s\n' "$live_listing" | grep -q 'initrd' || { echo "smoke: live initrd is missing" >&2; exit 1; }

echo "smoke: inspecting boot catalog"
el_torito="$(xorriso -indev "$ISO" -report_el_torito plain 2>/dev/null)"
printf '%s\n' "$el_torito" | grep -qi 'El Torito' || { echo "smoke: no El Torito boot catalog" >&2; exit 1; }
printf '%s\n' "$el_torito" | grep -qi 'BIOS' || { echo "smoke: BIOS boot entry not detected" >&2; exit 1; }
printf '%s\n' "$el_torito" | grep -qi 'UEFI\|EFI' || { echo "smoke: UEFI boot entry not detected" >&2; exit 1; }

echo "smoke: starting a short QEMU BIOS boot-survival test"
set +e
timeout --signal=TERM --kill-after=5s 35s \
  qemu-system-x86_64 \
    -machine accel=tcg \
    -m 1024 \
    -smp 2 \
    -boot d \
    -cdrom "$ISO" \
    -snapshot \
    -display none \
    -monitor none \
    -serial stdio \
    -no-reboot
rc=$?
set -e

case "$rc" in
  124|137|143)
    echo "smoke: QEMU remained alive through the boot window"
    ;;
  0)
    echo "smoke: QEMU exited cleanly"
    ;;
  *)
    echo "smoke: QEMU exited early with status $rc" >&2
    exit "$rc"
    ;;
esac

echo "smoke: starting a short QEMU UEFI boot-survival test"
OVMF_CODE=""
OVMF_VARS=""
if [ -f /usr/share/OVMF/OVMF_CODE_4M.fd ] && [ -f /usr/share/OVMF/OVMF_VARS_4M.fd ]; then
  OVMF_CODE=/usr/share/OVMF/OVMF_CODE_4M.fd
  OVMF_VARS=/usr/share/OVMF/OVMF_VARS_4M.fd
elif [ -f /usr/share/OVMF/OVMF_CODE.fd ] && [ -f /usr/share/OVMF/OVMF_VARS.fd ]; then
  OVMF_CODE=/usr/share/OVMF/OVMF_CODE.fd
  OVMF_VARS=/usr/share/OVMF/OVMF_VARS.fd
else
  echo "smoke: OVMF firmware files were not found" >&2
  exit 2
fi

UEFI_VARS="${TMPDIR:-/tmp}/glassxfce-ovmf-vars-$$.fd"
cp "$OVMF_VARS" "$UEFI_VARS"
trap 'rm -f "$UEFI_VARS"' EXIT HUP INT TERM

set +e
timeout --signal=TERM --kill-after=5s 35s \
  qemu-system-x86_64 \
    -machine q35,accel=tcg \
    -m 1024 \
    -smp 2 \
    -boot d \
    -cdrom "$ISO" \
    -snapshot \
    -display none \
    -monitor none \
    -serial stdio \
    -no-reboot \
    -drive if=pflash,format=raw,readonly=on,file="$OVMF_CODE" \
    -drive if=pflash,format=raw,file="$UEFI_VARS"
uefi_rc=$?
set -e

case "$uefi_rc" in
  124|137|143)
    echo "smoke: QEMU UEFI remained alive through the boot window"
    ;;
  0)
    echo "smoke: QEMU UEFI exited cleanly"
    ;;
  *)
    echo "smoke: QEMU UEFI exited early with status $uefi_rc" >&2
    exit "$uefi_rc"
    ;;
esac

echo "smoke: BIOS and UEFI ISO checks passed"
