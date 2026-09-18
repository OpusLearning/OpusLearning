#!/usr/bin/env bash
# write-sd-card.sh - write a built image file to a physical microSD card.
#
# THIS IS THE ONLY SCRIPT IN THE PROJECT THAT WRITES TO A DEVICE.
#
# It refuses to run without an approval token, because James's standing rule is
# that writing to physical media needs explicit approval as a separate step.
# Get that approval, then run with --approved.
#
# Usage:
#   scripts/write-sd-card.sh --image out.img --device /dev/sdX --approved
#
# It will not run if the device fails any check in lib/guard.sh, and there is no
# --force flag. Do not add one.

set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/lib/guard.sh"

IMAGE=""
DEVICE=""
APPROVED=0

while [[ $# -gt 0 ]]; do
    case "$1" in
        --image)    IMAGE="${2:-}"; shift 2 ;;
        --device)   DEVICE="${2:-}"; shift 2 ;;
        --approved) APPROVED=1; shift ;;
        -h|--help)  sed -n '2,20p' "$0"; exit 0 ;;
        *) guard_die "unknown argument: $1" ;;
    esac
done

[[ -n "$IMAGE" ]]  || guard_die "no --image given"
[[ -n "$DEVICE" ]] || guard_die "no --device given"
[[ -f "$IMAGE" ]]  || guard_die "$IMAGE does not exist"

if (( ! APPROVED )); then
    cat >&2 <<'MSG'

[GUARD] REFUSED: no approval token.

Writing to physical media requires James's explicit approval as a separate
step (Phase 5 of the brief). Show him the device identity below, get approval,
then re-run with --approved.

MSG
    guard_describe "$DEVICE" >&2 || true
    exit 1
fi

# Refuse Rockchip update images even at this stage.
guard_reject_update_image "$IMAGE"

echo "[write] image : $IMAGE"
echo "[write] size  : $(du -h "$IMAGE" | cut -f1)"
echo "[write] sha256: $(sha256sum "$IMAGE" | cut -d' ' -f1)"

guard_check_target "$DEVICE"
guard_confirm_target "$DEVICE"

echo
echo "[write] writing. Do not remove the card."
dd if="$IMAGE" of="$DEVICE" bs=4M conv=fsync status=progress
sync
echo "[write] flushed"

# Verify by reading back exactly as many bytes as we wrote.
IMG_BYTES="$(stat -c%s "$IMAGE")"
echo "[write] verifying $IMG_BYTES bytes read back from $DEVICE"
SRC_HASH="$(sha256sum "$IMAGE" | cut -d' ' -f1)"
DST_HASH="$(dd if="$DEVICE" bs=4M count=$(( (IMG_BYTES + 4194303) / 4194304 )) \
             iflag=fullblock status=none | head -c "$IMG_BYTES" | sha256sum | cut -d' ' -f1)"

if [[ "$SRC_HASH" == "$DST_HASH" ]]; then
    echo "[write] VERIFIED: card matches the image ($SRC_HASH)"
else
    echo "[write] FAILED: read-back hash does not match" >&2
    echo "        image: $SRC_HASH" >&2
    echo "        card : $DST_HASH" >&2
    echo "        Do not boot this card." >&2
    exit 1
fi

cat <<'MSG'

[write] done.

Before booting the VAHA:
  - UART capture running at 1500000 8N1, started BEFORE power is applied
  - partition backups verified (scripts/verify-backups.sh)
  - TEST-CHECKLIST.md open, ready to record the result

After booting: power off, remove the card, boot the VAHA, and confirm the stock
Android 7.1.2 still comes up. Do that every time, not just once.
MSG
