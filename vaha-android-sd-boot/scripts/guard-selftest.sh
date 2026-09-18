#!/usr/bin/env bash
# guard-selftest.sh - show what the write guard would do with every block device
# on this workstation. Writes nothing, ever.
#
# Run this once before trusting the guard, and confirm with your own eyes that
# it refuses your system disk.

set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"

echo "Guard self-test. Nothing is written. Every device on this machine is"
echo "offered to the guard and the verdict printed."
echo

for path in /sys/block/*; do
    dev="$(basename "$path")"
    case "$dev" in
        loop*|ram*|zram*|dm-*|sr*|md*) continue ;;
    esac
    printf '=== /dev/%s (%s) ===\n' "$dev" "$(lsblk -dnro SIZE "/dev/$dev" 2>/dev/null || echo '?')"
    if ( source "$HERE/lib/guard.sh"; guard_check_target "/dev/$dev" ) 2>&1 | sed 's/^/    /'; then
        printf '    VERDICT: ACCEPTED as a write target\n'
    else
        printf '    VERDICT: refused\n'
    fi
    echo
done

echo "Expected result: your system disk is refused, and only the SD card you"
echo "intend to write is accepted. If anything else is accepted, stop and fix"
echo "the guard before running write-sd-card.sh."
