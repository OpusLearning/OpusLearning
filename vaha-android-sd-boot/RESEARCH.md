# RESEARCH: Android 10/11 SD boot on the VAHA X (ShiMeta IoT-3399E, RK3399)

Status: research complete for the decision points that gate building anything.
Date: 18 September 2026.
No device access was available during this research. Nothing was written to the
VAHA and no SD card was touched.

## 1. Summary of what the research changes

Three findings materially change the plan you set out. Two are good, one is a
genuine obstacle that has to be designed around rather than assumed away.

**Finding A (good): the kernel base does not change between Android 7.1 and
Android 11 on RK3399.** Rockchip kept Linux 4.4 as the BSP kernel for RK3399
across Android 7.1, 10 and 11. Android 7.1.2 on RK3399 uses kernel 4.4.126, and
the Android 11 builds for RK3399 still use the Rockchip 4.4 tree with an
`android-11.config` fragment on top of `rockchip_defconfig`. This is the reason
the project is feasible at all. The VAHA's device-specific configuration (LVDS
panel timings, touchscreen, amplifier, Wi-Fi, camera, power behaviour) lives in
device tree nodes and vendor firmware blobs for a 4.4 kernel. Porting those into
an Android 10 or 11 image is a device-tree and vendor-blob exercise, not a driver
rewrite against a new kernel API.

**Finding B (good): SD boot on this exact board is already demonstrated at
bootloader level.** rgriebl reports that the IoT-3399E "will always try to start
from SD, if there is one inserted", provided the card carries the Rockchip
partition layout, and that generic RK3399 Linux SD images got as far as
"Starting kernel" before hanging. Reaching "Starting kernel" from an SD card
means the whole SD-side boot chain executed on a board whose eMMC was fully
populated with stock Android 7. The loader-level question is therefore already
answered empirically on our hardware. The failure was kernel and device tree, not
boot media.

**Finding C (the obstacle): the only documented RK3399 Android 10 SD-boot
procedure tells you to erase the eMMC.** Firefly's ROC-RK3399-PC-Plus wiki is the
best-documented RK3399 Android SD-boot reference available. For Android 7.1 it
says the eMMC upgrade firmware can be used directly to make an SD boot card, "the
two are compatible, and when using an SD boot card, the EMMC does not need to be
removed". For Android 10.0 it says the opposite: you must modify the kernel DTS to
add `supports-emmc;` to the `&sdmmc` node, and the resulting firmware "is not
compatible with the firmware directly upgraded into the EMMC ... you will need to
remove or erase the EMMC before using the SD boot card."

Erasing the eMMC is forbidden by your safety rule and would destroy the fallback
that makes this project safe. So Finding C is the thing the design has to solve.
Section 5 sets out how, and it is solvable.

## 2. The board and what is actually known about it

| Item | Value | Source |
|---|---|---|
| Board | ShiMeta / SMDT IoT-3399E, marked `IoT-3399E` on the reverse | rgriebl README |
| Board revision in the VAHA | V3.0 (the published PDF documents V2.0) | rgriebl README |
| SoC | Rockchip RK3399, 2x Cortex-A72 + 4x Cortex-A53, up to 1.8 GHz | ShiMeta product page |
| GPU | Mali-T860, 4K@60 decode | ShiMeta product page |
| RAM | 4 GB LPDDR4 | ShiMeta / your own inspection |
| Internal storage | 16 GB eMMC (stock spec) | ShiMeta listing |
| Stock OS | Android 7.1.2 | your device |
| Advertised OS support | "Android 7.1 and 11.0" | ShiMeta product page |
| Display path | RK3399 LVDS to a 30-pin connector, into an LG T-CON board, 43" panel | rgriebl README |
| Touchscreen | USB | rgriebl README |
| Camera | USB webcam | rgriebl README |
| Audio | amplifier integrated on the board, speakers wired directly to it | rgriebl README |
| Power | 12 V supply with a standby line; the power button switches both panel and board | rgriebl README |
| Debug UART | `DEBUG` connector, same pinout as the 4-pin 2.0 mm TTL serial socket, 1500000 8N1 | rgriebl README |
| Stock U-Boot | console input disabled in the eMMC U-Boot; an SD-supplied U-Boot can have input enabled | rgriebl README |
| Maskrom entry | hold the `UBOOT` button while powering on | rgriebl README |

The last two rows matter more than they look. A custom U-Boot loaded from SD can
give us an interactive console on a board whose stock bootloader deliberately has
none, and that interactive console is the cheapest possible instrument for
answering the remaining questions without building an Android image at all. See
Stage 0 in `SD-BOOT-DESIGN.md`.

## 3. How the RK3399 actually chooses its boot device

The published BootROM order for RK3399 is: SPI NOR, then SPI NAND, then eMMC,
then SD on the SDMMC controller, then USB OTG0 as maskrom fallback. On eMMC and
SD the BootROM looks for the ID block (IDB) at sector 64, and then at
64 + 1024*n for n up to 4. The IDB is a 512-byte block scrambled with a
well-known RC4 key; the loader it points at is the Rockchip first stage
(`idbloader`, which is header + TPL + SPL, or on the Android side
`MiniLoaderAll.bin`).

This published order says eMMC is probed **before** SD, which appears to
contradict rgriebl's observation that this board always tries SD first. Both can
be true, and the likely reconciliation is that the handover happens one stage
later: the Rockchip loader on eMMC itself probes for an SD card carrying a valid
Rockchip structure and hands control to it. That is exactly the mechanism that
makes Rockchip "SD upgrade" and "SD boot" cards work on Android products that
have a fully populated eMMC, and it is consistent with Firefly stating that for
Android 7.1 the eMMC does not need to be removed.

We do not need to resolve this from documentation. Stage 0 resolves it from the
UART log in about ten minutes, and the answer determines how much freedom we have
later. Recorded as assumption A-03 in `DECISIONS.md`.

Community reports are also clear that the BootROM order itself cannot be
reconfigured; the only hardware-level way to force SD ahead of eMMC is to prevent
the BootROM from reading the eMMC at all, typically by grounding the eMMC clock
line during reset. That is a hardware modification, it is not required by the
current design, and it is not proposed here.

## 4. Android version: what is actually obtainable

Your instinct that ShiMeta advertising Android 11 on this exact board is the most
useful new fact is right, and it makes the board-specific image the first thing
worth chasing. But the research found no public download for it.

**ShiMeta / SMDT.** The product page for the AIoT-3399E / IoT-3399E states
support for "Android 7.1 and 11.0". It links a datasheet but exposes no firmware,
SDK or BSP download, and no public download centre was found. There is an FCC
filing and a user manual in circulation, but those are documentation, not images.
An Android 7.1.2 image for this board circulates on enthusiast forums
(FreakTab, XDA). Per your instruction, no firmware was downloaded from any of
those sources and none should be.

Conclusion: the ShiMeta Android 11 build very probably exists as a customer
deliverable rather than a public download. The correct move is to ask them for
it. That is a short email, it costs nothing, and if it succeeds it removes the
single hardest part of this project, because a board-specific image already
contains the LVDS timings, touch, amplifier, Wi-Fi and camera configuration that
we would otherwise have to port by hand. This is the highest-value next action in
the whole project and it is one only you can take. A drafted enquiry is in
`README.md`, section "Action needed from James".

**Android 10 on RK3399.** Well documented and reproducible. Firefly publishes a
full Android 10 build guide and an SD-boot procedure for the ROC-RK3399-PC-Plus,
and Advantech publishes an RK3399 Android 10 BSP guide. Images are built from
source, produce the standard Rockchip set (`MiniLoaderAll.bin`, `uboot.img`,
`trust.img`, `boot.img`, `super.img`, `parameter.txt`), and Android 10 on
Rockchip introduces dynamic partitions via `super.img`. SD boot is explicitly
supported for Android 10 on that board, with the eMMC caveat in Finding C.

**Android 11 on RK3399.** Exists, but as a community and vendor source tree
rather than an official Rockchip RK3399 release. Radxa document an Android 11
build for the ROCK Pi 4 (RK3399):

```
repo init -u https://github.com/radxa/manifests.git -b Android11_Radxa_rk11 -m rockchip-r-release.xml
repo sync -d --no-tags -j4
```

No prebuilt images, no documented SD-boot path, and no statement about dynamic
partitions in that guide. There is also a community AOSP Android TV 11 image for
the ROCK 4 SE / RK3399, unaffiliated with Google or Radxa and without Google apps,
which is interesting as a proof that Android 11 runs well on RK3399 but is not a
suitable base for a device that needs Widevine and Play Services.

**Recommendation.** Judged on peripheral compatibility rather than version
number, in this order:

1. **ShiMeta IoT-3399E Android 11, if they will supply it.** Board-specific,
   advertised by the vendor, and the only option that starts with the VAHA's own
   peripherals already configured. Chase this first.
2. **Firefly ROC-RK3399-PC-Plus Android 10 BSP with the VAHA device tree ported
   in.** The fallback, and a good one: it is the only RK3399 Android with a
   documented SD-boot procedure, it is buildable from public source, and the
   shared 4.4 kernel makes the device-tree port tractable.
3. **Radxa Android 11 for ROCK Pi 4.** Only if Android 11 turns out to matter for
   app compatibility in a way Android 10 does not, because it costs us the
   documented SD-boot path and adds work without adding peripheral support.

Do not pick on version number. Android 10 with a working LVDS panel, touch, Wi-Fi
and audio beats Android 11 with a black screen, and the app-compatibility gap
between 10 and 11 is small for the applications on your list. Section 7 covers
that.

## 5. The eMMC coexistence problem, and the proposed solution

Finding C is the real design problem: Firefly's Android 10 SD-boot recipe assumes
an erased eMMC. Understanding why points at the fix.

The `supports-emmc;` property added to `&sdmmc` tells the kernel to treat the SD
controller with boot-device semantics. On Rockchip Android, the `by-name`
partition links that Android's init and fstab depend on
(`/dev/block/by-name/boot`, `super`, `vendor`, `userdata`, `misc` and so on) are
resolved against the designated boot device. With both the eMMC and the SD card
claiming that role, the resolution is ambiguous. That ambiguity is the actual
hazard: not merely that the wrong system might boot, but that Android could write
to eMMC partitions it believes are its own, for example `misc`, `metadata`,
`vbmeta` or `userdata`. Firefly's advice to erase the eMMC removes the ambiguity
by removing the competitor.

We cannot remove the competitor, and we do not need to. We can remove the
competitor's visibility instead.

**Proposed solution: disable the eMMC controller node in the SD-card kernel's
device tree.** In the DTB we ship on the SD card only, set the RK3399 eMMC
controller (`&sdhci`) to `status = "disabled"`. The SD-booted kernel then never
probes the eMMC, never creates a block device for it, and cannot write to it
through any path, whether by a confused `by-name` link, a stray fstab entry, an
AVB metadata update or a user action inside Android. The eMMC remains physically
present and byte-for-byte untouched. Remove the SD card and the stock Android
7.1.2 boots from its own device tree, which of course still enables the eMMC.

This is stronger than a procedural safety rule, because it is enforced by the
kernel's own hardware probing rather than by anyone remembering to be careful. It
also resolves the `by-name` ambiguity as a side effect: with only one MMC device
present, `by-name` can only resolve to the SD card.

Residual exposure after this change is limited to the pre-kernel stages, which
still see the eMMC: the BootROM, the Rockchip loader and U-Boot. Those stages do
not write in a normal boot. They do write during a firmware upgrade, which is why
the design forbids ever placing a Rockchip **update** image on the card, and why
Stage 0 exists to observe the loader's behaviour on UART before any Android is
involved. Recorded as decision D-05 in `DECISIONS.md`.

**Untested.** We have not yet confirmed that disabling `&sdhci` leaves the
loader-level handover intact, because the handover happens before the kernel's
device tree is in play, so in principle it should be unaffected. This is the main
technical assumption of the design and Stage 0 plus Stage 2 test it directly.

## 6. Why the generic Linux images hung at "Starting kernel"

Worth stating plainly, because it predicts where our first Android attempt will
fail too. rgriebl's generic `rk3399_evb` images hang immediately after "Starting
kernel". That is the signature of a kernel that has started but has no working
console and no correct device tree for the actual board: wrong UART or wrong
baud for early console, wrong DDR or regulator configuration, and no LVDS panel
node, so nothing appears on screen and nothing further appears on serial.

The lesson for us is that the device tree is the whole project. An Android 10 or
11 image built for a reference board will do exactly the same thing. The order of
work is therefore: get a correct DTB first, prove it with an interactive U-Boot
and a serial console, and only then worry about Android userspace.

This is also why Phase 1's inventory is not busywork. The stock DTB is the
specification for the hardware, and extracting it from the backed-up boot or
resource partition gives us the LVDS timings, the amplifier configuration, the
regulator tree and the GPIO map as the vendor actually set them.

## 7. App compatibility, Android 10 versus Android 11

For the applications on your list the difference between Android 10 and Android
11 is small, and both are enormously better than Android 7.1.2, which is now well
past the minimum supported version for most of them.

The variable that actually matters is Widevine. Netflix-style playback and some
features of the video conferencing apps depend on Widevine L1 or L3 and on the
DRM HAL and keybox present in the vendor image. A board-specific ShiMeta image is
far more likely to carry a provisioned Widevine keybox than a self-built AOSP
image, where you would typically end up at L3 or with no Widevine at all. This is
another argument for chasing the vendor image first, and it is worth recording
now rather than discovering it at Phase 7. Recorded as assumption A-07.

Phase 7 testing should therefore check `getprop | grep -i widevine` and
`dumpsys media.drm` early, not at the end.

## 8. Sources

- rgriebl, VAHA Fitness Mirror X: https://github.com/rgriebl/vaha-fitness-mirror
- ShiMeta AIoT-3399E product page: https://shimetadevice.com/product/aiot-3399e-six-core-smart-terminal-motherboard/
- ShiMeta product range: https://shimetadevice.com/products/
- PINE64, RK3399 boot sequence: https://wiki.pine64.org/wiki/RK3399_boot_sequence
- Rockchip open source, Boot option: https://opensource.rock-chips.com/wiki_Boot_option
- U-Boot Rockchip documentation: https://docs.u-boot.org/en/v2023.10/board/rockchip/rockchip.html
- Firefly, Make an SD boot card (ROC-RK3399-PC-PLUS): https://wiki.t-firefly.com/en/ROC-RK3399-PC-PLUS/06-boot_firmware_sd.html
- Firefly, Compile Android 10.0 firmware: https://wiki.t-firefly.com/en/ROC-RK3399-PC-PLUS/compile_android10.0_firmware.html
- Advantech, Android BSP User Guide for rk3399 series 10.0: https://ess-wiki.advantech.com.tw/view/Android_BSP_User_Guide_for_rk3399_series_10.0
- Advantech, Android BSP User Guide for rk3399 series 7.1.2: https://ess-wiki.advantech.com.tw/view/Android_BSP_User_Guide_for_rk3399_series_7.1.2
- Radxa, ROCK Pi 4 Android 11: https://wiki.radxa.com/Rockpi4/rockpi-android11
- rockchip-android/device-rockchip-rk3399: https://github.com/rockchip-android/device-rockchip-rk3399
- rkdeveloptool: https://github.com/rockchip-linux/rkdeveloptool
- Orange Pi 4 / RK3399 SD boot mechanics: http://kofa.mmto.arizona.edu/rk3399/make_boot/
