#!/usr/bin/env bash
# extract-dtb.sh - recover the stock device tree from the partition backups.
#
# Offline and read-only. Needs no device access, so it can be run with the VAHA
# powered down. This is the highest-value thing that can be done without the
# hardware, because the stock DTB is the specification for this board.
#
# Usage: scripts/extract-dtb.sh <backup-dir> [output-dir]

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
BACKUP="${1:-}"
OUT="${2:-$(cd "$HERE/.." && pwd)/hardware-inventory}"

[[ -n "$BACKUP" ]] || { echo "usage: $0 <backup-dir> [output-dir]" >&2; exit 2; }
[[ -d "$BACKUP" ]] || { echo "ERROR: $BACKUP is not a directory" >&2; exit 1; }
mkdir -p "$OUT"

echo "[dtb] searching $BACKUP for a Rockchip resource container"

found=0
# Try the likely candidates first, then anything else that looks like an image.
for candidate in "$BACKUP"/resource* "$BACKUP"/boot* "$BACKUP"/*.img "$BACKUP"/*.bin; do
    [[ -f "$candidate" ]] || continue
    echo "[dtb] trying $(basename "$candidate")"
    if python3 "$HERE/rk-resource-extract.py" "$candidate" "$OUT" 2>/dev/null; then
        echo "[dtb] extracted from $(basename "$candidate")"
        found=1
        break
    fi
done

if (( ! found )); then
    echo "ERROR: no Rockchip resource container found in $BACKUP" >&2
    echo "       Check that the resource and boot partition backups are present." >&2
    echo "       Listing what is there:" >&2
    ls -l "$BACKUP" >&2
    exit 1
fi

DTB="$OUT/rk-kernel.dtb"
if [[ -f "$DTB" ]]; then
    echo "[dtb] stock DTB: $DTB ($(stat -c%s "$DTB") bytes)"
    cp -f "$DTB" "$OUT/stock.dtb"
    if command -v dtc >/dev/null; then
        dtc -I dtb -O dts "$DTB" -o "$OUT/stock.dts" 2>/dev/null \
            && echo "[dtb] decompiled -> $OUT/stock.dts" \
            || echo "[dtb] WARNING: dtc could not decompile the DTB" >&2
        if [[ -f "$OUT/stock.dts" ]]; then
            echo
            echo "[dtb] panel timing nodes found (these are the LVDS values we need):"
            grep -n -A 20 'panel-timing' "$OUT/stock.dts" | head -60 || echo "  none matched 'panel-timing'"
            echo
            echo "[dtb] MMC controller nodes:"
            grep -n -e 'sdhci' -e 'sdmmc' -e 'dwmmc' "$OUT/stock.dts" | head -20 || true
        fi
    else
        echo "[dtb] dtc not installed. Run: sudo apt install device-tree-compiler" >&2
    fi
else
    echo "[dtb] WARNING: container parsed but no rk-kernel.dtb entry was present" >&2
fi

( cd "$OUT" && find . -type f ! -name 'MANIFEST.sha256' -print0 | sort -z | xargs -0 -r sha256sum > MANIFEST.sha256 )
echo "[dtb] manifest updated"
