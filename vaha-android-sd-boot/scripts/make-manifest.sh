#!/usr/bin/env bash
# make-manifest.sh - SHA-256 manifest for everything this project produces.
#
# Read-only apart from the manifest file it writes.
#
# Usage: scripts/make-manifest.sh [directory ...]
# Default: hardware-inventory/ and build/ if they exist.

set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

dirs=("$@")
if [[ ${#dirs[@]} -eq 0 ]]; then
    for d in "$ROOT/hardware-inventory" "$ROOT/build"; do
        [[ -d "$d" ]] && dirs+=("$d")
    done
fi

[[ ${#dirs[@]} -gt 0 ]] || { echo "nothing to hash; no hardware-inventory/ or build/ yet" >&2; exit 0; }

for d in "${dirs[@]}"; do
    [[ -d "$d" ]] || { echo "skipping $d (not a directory)" >&2; continue; }
    echo "[manifest] $d"
    ( cd "$d" && find . -type f ! -name 'MANIFEST.sha256' -print0 \
        | sort -z | xargs -0 -r sha256sum > MANIFEST.sha256 )
    echo "[manifest] $(grep -c . "$d/MANIFEST.sha256") files -> $d/MANIFEST.sha256"
done
