# VAHA X: Android 10/11 microSD boot project

Goal: boot a VAHA X fitness mirror from a microSD card running Android 10 or 11,
while leaving its original Android 7.1.2 eMMC installation completely intact.
Remove the card, and the machine is exactly as it was.

Hardware: ShiMeta / SMDT IoT-3399E (board revision V3.0), Rockchip RK3399,
4 GB LPDDR4, 16 GB eMMC, 43" LVDS panel via an LG T-CON, USB touchscreen, USB
camera, on-board amplifier.

**Safety rule, in force throughout: the eMMC is read-only. Any operation capable
of modifying it requires James's explicit approval as a separate step.**

## Status: research and design complete. Nothing built, nothing written.

This session performed research and produced the design and the tooling. It did
not touch the VAHA and did not write an SD card. It could not have: the VAHA is
powered down, and this session runs in a cloud container with no USB, no ADB and
no serial port.

| Phase | State |
|---|---|
| 1 Inventory | Harness written and tested. **No data collected**, needs the VAHA, or the backups for the offline part |
| 2 Target Android version | Researched, recommendation made, one blocking question for the vendor |
| 3 SD boot design | Complete, with the eMMC coexistence problem identified and a solution proposed |
| 4 Build an image file | Builder written and tested against synthetic inputs; needs a BSP to build anything real |
| 5 Physical SD | Not started. Gated on your explicit approval |
| 6 First VAHA boot | Not started |
| 7 App compatibility | Not started |

## Read these in order

1. `RESEARCH.md`, what the research found, including the two findings that
   change the plan and the one that threatens it.
2. `SD-BOOT-DESIGN.md`, how SD boot works on this board, the four-layer safety
   model, and the staged bring-up.
3. `HARDWARE-INVENTORY.md`, what Phase 1 collects and why it is the thing the
   whole project depends on.
4. `RECOVERY.md`, what to do when something goes wrong. Mostly: remove the card.
5. `TEST-CHECKLIST.md`, what to record at each boot.
6. `DECISIONS.md`, every assumption, its evidence, and what would overturn it.

## The three things worth knowing before you read anything else

**The kernel does not change.** Rockchip kept Linux 4.4 as the RK3399 kernel base
across Android 7.1, 10 and 11. Your VAHA's panel timings, amplifier, Wi-Fi and
touch configuration are device-tree nodes and vendor blobs for a 4.4 kernel, and
they port forward. This is why the project is feasible.

**SD boot already works on this exact board.** rgriebl's generic RK3399 Linux
images reached "Starting kernel" from an SD card on an IoT-3399E with a fully
populated Android 7 eMMC. The boot-media question is answered; the failure was
the device tree. Which means the device tree is the project.

**The documented Android 10 SD-boot recipe says to erase the eMMC.** Firefly's
RK3399 wiki, the best reference available, says the Android 10 SD boot firmware
"is not compatible with the firmware directly upgraded into the EMMC ... you will
need to remove or erase the EMMC before using the SD boot card." That is
forbidden here, and it is the real problem to solve.

The proposed solution is to disable the eMMC controller in the device tree we
ship on the SD card, so the SD-booted kernel cannot see the eMMC at all. That
removes every kernel-level write path to it and resolves the partition-naming
ambiguity that caused Firefly's advice in the first place. The eMMC stays
physically intact; pull the card and stock Android boots from it as usual. This
is decision D-05 and it is the main unverified assumption in the design.

## Action needed from James

Two things, and only one of them is urgent.

**1. Ask ShiMeta for the IoT-3399E Android 11 image. This is the highest-value
action in the project and only you can take it.**

ShiMeta advertise Android 11 support on this exact board but publish no
download, so it is almost certainly a customer deliverable rather than a public
file. A board-specific image arrives with your panel, touch, amplifier, Wi-Fi and
camera already configured, and is far more likely to carry a provisioned Widevine
keybox than anything we build ourselves. It would remove the hardest part of this
project in one step. A draft enquiry:

> Subject: IoT-3399E (RK3399) Android 11 firmware and BSP request
>
> Hello,
>
> I have an IoT-3399E motherboard, revision V3.0, currently running Android
> 7.1.2. Your product page states that the board supports Android 7.1 and 11.0.
>
> Could you supply the Android 11 firmware image for this board, and the
> corresponding BSP or SDK, including the device tree sources? I am also
> interested in whether the Android 11 build supports booting from the TF/microSD
> slot, and whether a board-specific SD boot image is available.
>
> The board drives a 43-inch LVDS panel through an LG T-CON, with a USB
> touchscreen, a USB camera and the on-board amplifier, so a build that already
> carries that configuration would be ideal.
>
> Thank you,
> James Wallace

Their contact route is via https://shimetadevice.com/. Whatever they answer,
record it in `DECISIONS.md` against A-08 and D-10.

**2. Decide when the VAHA goes back on.** The offline half of Phase 1 needs only
your partition backups and can be done today:

    scripts/extract-dtb.sh /path/to/your/backups

That recovers the stock device tree, which is the specification for this board
and the thing an Android 10/11 image will fail without. The rest of Phase 1 needs
the machine powered on with ADB connected. Nothing needs the case open until
Stage 0, and whether Stage 0 needs the case open depends on whether the microSD
slot is reachable from outside, which is worth checking before you plan an
evening around it.

## What happens next, in order

1. You send the ShiMeta enquiry. Costs ten minutes, may save weeks.
2. `scripts/extract-dtb.sh` against the backups. No device needed.
3. VAHA on, `scripts/collect-inventory.sh`. Read-only, about ten minutes.
4. Stage 0: a diagnostic U-Boot card with no Android on it, to confirm SD boot
   and identify which MMC device is the eMMC. One evening, nothing at risk.
5. Then, and only then, choose the BSP and build an Android image.

Steps 2 to 4 are worth doing whatever ShiMeta say. Step 5 depends on their answer.

## Scripts

| Script | Writes? | Purpose |
|---|---|---|
| `scripts/lib/guard.sh` | no | shared refusal logic for anything that could write to a device |
| `scripts/guard-selftest.sh` | no | show the guard's verdict on every block device on your workstation |
| `scripts/collect-inventory.sh` | no | Phase 1 inventory over ADB, read-only throughout |
| `scripts/extract-dtb.sh` | no | recover the stock device tree from the partition backups, offline |
| `scripts/rk-resource-extract.py` | no | parse a Rockchip resource container (the DTB lives in one) |
| `scripts/verify-backups.sh` | no | confirm the 13 partition backups still hash correctly |
| `scripts/rk-sdimage.py` | file only | build an SD image as a file; refuses Rockchip update images |
| `scripts/make-manifest.sh` | manifest only | SHA-256 manifest of everything produced |
| `scripts/write-sd-card.sh` | **yes, to an SD card** | the only script that writes to a device. Requires `--approved` |

Run `scripts/guard-selftest.sh` once before trusting any of this, and confirm
with your own eyes that the guard refuses your system disk.

### What has actually been tested

The Rockchip resource parser was verified against a synthetic container and
extracted entries at the correct offsets. The `parameter.txt` parser was verified
against a realistic RK3399 Android 10 layout. The Stage 0 image builder was run
and produced a correctly laid-out file. The update-image rejection, the approval
gate and the device guard were all exercised and all refused as intended.

Nothing has been tested against real hardware, a real SD card, or a real BSP,
because none of those were reachable from this session.

## Prerequisites on the Ubuntu workstation

    sudo apt install android-tools-adb device-tree-compiler gdisk python3 util-linux
