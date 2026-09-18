# RECOVERY

The premise of this project is that recovery is trivial because nothing is ever
broken. This document exists so that remains true even when something goes wrong.

## The one-line version

Remove the microSD card and power cycle. The VAHA boots its untouched stock
Android 7.1.2 from eMMC.

That is the entire recovery procedure for every failure mode this project's
design can produce, because the design never writes to the eMMC. If that ever
stops being the recovery procedure, something has gone wrong that was not
supposed to be possible, and the rest of this document applies.

## Before each stage

1. Confirm the partition backups are present and still verify. Run
   `scripts/verify-backups.sh <backup-dir>` and confirm all 13 hashes match.
   Do not proceed on a mismatch.
2. Confirm at least one copy of the backups exists on storage that is not the
   workstation you are about to run `dd` on.
3. Confirm UART is attached and capturing at 1500000 8N1 before power-on.

Backups that have not been verified recently are not backups.

## Failure modes and responses

**The VAHA does not boot with the SD card inserted, and shows nothing on UART.**
Power off, remove the card, power on. Stock Android should boot. If it does, the
card is the problem and the fix is in the image. If it does not, go to the last
section.

**UART shows the loader, then a hang at "Starting kernel".**
Expected on a first attempt. The kernel has started with a device tree that does
not match this board. Nothing is damaged; the eMMC has not been touched. Fix the
DTB on the card and try again. See `RESEARCH.md` section 6.

**Android boots from SD but the panel stays dark.**
The system may be fully up and merely headless. Try ADB over the USB/ADB port
before concluding failure, and capture `dmesg` for the DRM and panel nodes. A
dark panel with a live ADB shell is a good result at Stage 2, not a bad one.

**Android boots from SD and you suspect it has touched the eMMC.**
Stop. Power off, remove the card, and do not boot the VAHA again until you have
established the truth. With the card out, boot and compare the eMMC partitions
against your backups by hashing them read-only over ADB. If anything differs,
that is a design failure worth understanding fully before any further
experiments, and the `&sdhci` disable in the SD DTB should be verified as present
in the DTB that was actually on the card.

**The stock Android 7.1.2 will not boot with the card removed.**
This should not be reachable. If it happens: the board can be put into maskrom
mode by holding the `UBOOT` button while powering on, and `rkdeveloptool` can
then write the backed-up partitions back. This is the only procedure in the whole
project that writes to the eMMC, it is a last resort, and under your own safety
rule it requires your explicit approval as a separate step before anyone runs it.
It is documented here so the knowledge exists, not so it gets used.

## What the backups are for

The 13 hash-verified partition backups are the insurance policy. Their value is
not that we expect to restore them; it is that their existence is what makes it
reasonable to experiment at all. Keep them, keep them verified, and keep a copy
off the workstation.
