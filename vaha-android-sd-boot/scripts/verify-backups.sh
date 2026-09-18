#!/usr/bin/env bash
# verify-backups.sh - confirm the eMMC partition backups still hash correctly.
#
# Read-only. Run this before every stage. Backups that have not been verified
# recently are not backups.
#
# Usage: scripts/verify-backups.sh <backup-dir> [expected-count]

set -euo pipefail

BACKUP="${1:-}"
EXPECT="${2:-13}"

[[ -n "$BACKUP" ]] || { echo "usage: $0 <backup-dir> [expected-count]" >&2; exit 2; }
[[ -d "$BACKUP" ]] || { echo "ERROR: $BACKUP is not a directory" >&2; exit 1; }

cd "$BACKUP"

MANIFEST=""
for m in MANIFEST.sha256 SHA256SUMS sha256sums.txt checksums.sha256; do
    [[ -f "$m" ]] && { MANIFEST="$m"; break; }
done

if [[ -z "$MANIFEST" ]]; then
    echo "ERROR: no checksum manifest found in $BACKUP" >&2
    echo "       Looked for: MANIFEST.sha256 SHA256SUMS sha256sums.txt checksums.sha256" >&2
    echo "       Create one with: sha256sum *.img > MANIFEST.sha256" >&2
    exit 1
fi

echo "[verify] using $MANIFEST"
if sha256sum -c "$MANIFEST"; then
    echo "[verify] all hashes match"
else
    echo "[verify] FAILED: one or more backups do not match their recorded hash" >&2
    echo "[verify] Do not proceed with any boot experiment until this is resolved." >&2
    exit 1
fi

count="$(grep -c . "$MANIFEST")"
echo "[verify] $count files listed, $EXPECT expected"
if [[ "$count" -ne "$EXPECT" ]]; then
    echo "[verify] WARNING: count differs from the expected $EXPECT partitions." >&2
    echo "[verify] Check against hardware-inventory/by-name.txt that nothing is missing." >&2
fi
