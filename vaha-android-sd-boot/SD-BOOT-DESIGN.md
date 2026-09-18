# SD-BOOT-DESIGN: booting Android 10/11 from microSD with eMMC untouched

This is the design, not a build record. Nothing here has been built or written
yet. Every statement that has not been verified on hardware is marked
**UNVERIFIED** and has a test that settles it.

## 1. Requirements

| # | Requirement | How the design meets it |
|---|---|---|
| R1 | SD inserted boots the experimental Android | Rockchip loader structure on the card, section 3 |
| R2 | SD removed boots the untouched stock Android 7.1.2 | nothing is ever written to eMMC, section 2 |
| R3 | No command may erase, repartition or flash the VAHA eMMC | enforced in kernel DTB and in every script, section 5 |
| R4 | Failure is diagnosable | UART at 1500000 8N1 captured from before power-on, section 6 |
| R5 | Reversible at every step | staged boot, section 6; `RECOVERY.md` |

## 2. The safety model, in order of strength

Four layers, listed strongest first. The design does not rely on any single one.

**Layer 1, physical.** Nothing in this project ever writes to the VAHA's internal
storage. The only write target is a microSD card, and the only machine that
writes is the Ubuntu workstation. The VAHA is never put into maskrom mode and
`rkdeveloptool` is never pointed at it.

**Layer 2, kernel device tree.** The DTB on the SD card disables the RK3399 eMMC
controller (`&sdhci { status = "disabled"; }`). The SD-booted kernel cannot see
the eMMC, so no process inside the experimental Android, including Android's own
init, fstab, AVB metadata handling or a mis-resolved `by-name` symlink, can write
to it. This also removes the `by-name` ambiguity that makes Firefly tell people
to erase their eMMC (see `RESEARCH.md` section 5). **UNVERIFIED**, tested at
Stage 2.

**Layer 3, image content.** The card carries a *boot* layout, never a Rockchip
*update* image. `update.img`, `MiniLoaderAll.bin` in upgrade mode, the Rockchip
"SD Upgrade" card type and anything else whose purpose is to flash internal
storage are prohibited artefacts. Their presence on the card is what turns an SD
card into an eMMC flasher, and the build scripts refuse to produce them.

**Layer 4, script guards.** Every script that can write to a block device loads
`scripts/lib/guard.sh`, which refuses non-removable devices, refuses devices
whose MMC type is `MMC` rather than `SD`, refuses any device holding a mounted
filesystem or the workstation root, and requires the operator to retype the
target device's model and serial. Details in section 5.

## 3. Rockchip SD boot structure

The RK3399 BootROM looks for the ID block at sector 64 of the boot medium, and
then at sector 64 + 1024*n for n up to 4. The ID block is a 512-byte RC4-scrambled
header that points at the first-stage loader.

Two loader conventions exist and they must not be mixed:

**Mainline/U-Boot convention**, used at Stage 0 for the diagnostic card:

| Artefact | Offset (512-byte sectors) | Byte offset |
|---|---|---|
| `idbloader.img` (IDB header + TPL + SPL) | 64 | 32 KiB |
| `u-boot.itb` (FIT: U-Boot proper, ATF, DTB) | 16384 | 8 MiB |
| GPT / first partition | from 32768 | 16 MiB |

**Rockchip Android convention**, used from Stage 2 onward. Offsets come from the
`parameter.txt` in the chosen BSP and are not invented here; the table below is
the shape, and the authoritative values are copied from the BSP at build time:

| Artefact | Role |
|---|---|
| `MiniLoaderAll.bin` | Rockchip first-stage loader, written at the IDB offset |
| `parameter.txt` | partition table plus kernel command line, read by the loader |
| `uboot.img` | U-Boot proper |
| `trust.img` | ARM Trusted Firmware / OP-TEE |
| `resource.img` | DTB and boot logo, this is where our patched DTB goes |
| `boot.img` | Android boot image, kernel plus ramdisk |
| `super.img` | Android 10/11 dynamic partitions: system, vendor, product, odm |
| `userdata` | created empty on the card |
| `misc`, `vbmeta`, `metadata` | created on the card, never on eMMC |

Android 10 and 11 on Rockchip use dynamic partitions, so `super.img` replaces the
separate `system.img` and `vendor.img` of the Android 7 era. This is the specific
reason the task cannot be done by copying `system.img` onto a card.

**Minimum card**: 32 GB, UHS-I A1 or better, from a brand that publishes real
part numbers. A 16 GB card will fit but leaves almost nothing for `userdata` once
`super` is sized for Android 11.

## 4. Boot chain and where the handover happens

```
power on
  BootROM               probes SPI, eMMC, SD, then USB maskrom
  loader                either the SD loader directly, or the eMMC loader
                        handing over to the SD card  <-- UNVERIFIED, Stage 0
  U-Boot (from SD)      reads SD parameter.txt, loads trust and resource
  kernel (from SD)      DTB has &sdhci disabled, eMMC invisible from here on
  Android init (SD)     by-name resolves only to SD partitions
```

The single unresolved question in the chain is which component performs the
handover to SD, because the published BootROM order probes eMMC before SD while
this board is reported to prefer SD. Stage 0 answers it from the UART log. The
answer does not change the design, but it does change the recovery story, so it
is worth knowing before Stage 2.

## 5. Script guards

`scripts/lib/guard.sh` is sourced by every script capable of writing to a block
device. A target is rejected unless all of the following hold:

1. The path matches `/dev/sd[a-z]` or `/dev/mmcblk[0-9]`, with no partition
   suffix.
2. `/sys/block/<dev>/removable` reads `1`, or the device is an SD card reader
   whose transport is USB.
3. For MMC devices, `/sys/block/<dev>/device/type` reads `SD`. A value of `MMC`
   means eMMC and is refused unconditionally, with a message naming the safety
   rule.
4. No partition of the device is mounted, and the device does not host `/`,
   `/boot` or `/home`.
5. Reported size is between 4 GB and 512 GB.
6. The operator retypes the exact model and serial that the script has printed.

Any failed check aborts with a non-zero status before any write occurs. There is
no `--force` flag and none should be added. The guard is deliberately paranoid
about eMMC even though the VAHA's eMMC is not attached to the workstation,
because the cost of the check is nil and the cost of the mistake is the project.

The build scripts additionally refuse to emit an artefact named `update.img` or
to write anything with the Rockchip upgrade tag.

## 6. Staged bring-up

Each stage is cheap, reversible, and answers one question. Do not skip to Stage 2.

**Stage 0, diagnostic U-Boot card. No Android at all.**
Write only `idbloader.img` and `u-boot.itb` for RK3399 to a card, with console
input enabled. rgriebl's note that the stock eMMC U-Boot has input disabled but
an SD-supplied U-Boot can have it enabled is what makes this possible. Boot with
UART capturing. Success is a U-Boot prompt. From it, run `mmc list`, `mmc dev`,
`part list mmc 0`, `part list mmc 1` to see exactly which controller is which and
confirm that the eMMC GPT is intact and readable. Read only; issue no `mmc write`
and no `mmc erase`.

This stage costs one card and an evening, and it settles: whether SD boot works
on this board at all, which component hands over, which MMC index is the eMMC,
and whether the stock partition table matches our backups. Everything after it is
better informed. If it fails, nothing has been risked.

**Stage 1, build only.** Produce the Android SD image as a file on the
workstation. Inspect the partition table offline with `sgdisk -p` on the image
file and `file`/`fdisk -l`. Generate the SHA-256 manifest. Nothing physical.

**Stage 2, first Android boot from SD.** UART capturing before power-on. Expected
progress markers are the ten success stages in `TEST-CHECKLIST.md`. The most
likely failure is a hang at "Starting kernel", for the reasons in `RESEARCH.md`
section 6, and the fix is always in the DTB on the card.

**Stage 3 onwards**, peripheral bring-up and then app testing, per
`TEST-CHECKLIST.md`.

After every stage: power off, remove the card, boot the VAHA, confirm stock
Android 7.1.2 comes up normally. That check is the actual proof of R2 and it
should be performed every time, not once.

## 7. What would make this project stop

State these now so the decision is not made under sunk cost.

- Stage 0 shows the board will not hand over to an SD loader at all. The project
  stops unless you accept a hardware modification, which is out of scope.
- The LVDS timings cannot be recovered from the stock DTB and the panel will not
  initialise. Recoverable, but it becomes a much longer project.
- ShiMeta decline to supply an image and the Firefly Android 10 base cannot be
  made to coexist with a populated eMMC even with `&sdhci` disabled. At that
  point the honest options are to stop, or to obtain a second IoT-3399E board to
  experiment on, which is the cheap way to buy back the freedom to erase an eMMC.
