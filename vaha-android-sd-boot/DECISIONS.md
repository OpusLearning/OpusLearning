# Decision log

Every assumption and decision, with the evidence behind it and what would
overturn it. Append, do not rewrite. Date format: YYYY-MM-DD.

Status values: `assumed` (acting on it, not yet tested), `verified` (tested on
hardware), `refuted`, `open` (not yet decided).

---

### A-01: The eMMC is read-only for the entire project
**2026-09-18 · status: decided (constraint set by James)**
Stated requirement. Every design choice defers to it. Any operation capable of
modifying the VAHA's eMMC requires separate explicit approval.
Overturned by: nothing short of James changing the constraint.

### A-02: Android 10 and 11 on RK3399 share the Android 7.1 kernel base (Linux 4.4)
**2026-09-18 · status: assumed, evidence strong**
Evidence: RK3399 Android 7.1.2 BSP uses kernel 4.4.126; RK3399 Android 11 builds
use the Rockchip 4.4 tree with `rockchip_defconfig` plus `android-11.config`.
Consequence: porting the VAHA's device-tree nodes forward is tractable.
Overturned by: finding the chosen BSP actually ships a 5.10 kernel, which would
make the peripheral port substantially harder.

### A-03: This board hands over to an SD loader with the eMMC populated
**2026-09-18 · status: assumed, evidence from this exact board**
Evidence: rgriebl reports the IoT-3399E "will always try to start from SD, if
there is one inserted", and generic RK3399 Linux SD images reached "Starting
kernel". Reaching the kernel from SD proves the SD-side chain executed while the
eMMC held stock Android 7.
Tension: the published RK3399 BootROM order probes eMMC before SD. Most likely
the eMMC loader performs the handover rather than the BootROM.
Settled by: Stage 0 UART log.

### A-04: The published BootROM order cannot be reconfigured
**2026-09-18 · status: assumed**
Evidence: multiple community sources state the RK3399 BootROM order is fixed and
the only way to deprioritise eMMC is hardware, typically grounding the eMMC clock.
Consequence: no software setting will force SD-first. We depend on A-03 instead.
Note: a hardware modification is explicitly out of scope and is not proposed.

### D-05: Disable the eMMC controller in the SD card's device tree
**2026-09-18 · status: decided, UNVERIFIED on hardware**
Problem: Firefly's RK3399 Android 10 SD-boot recipe requires adding
`supports-emmc;` to `&sdmmc`, and states the result is incompatible with a
populated eMMC, telling users to remove or erase it. Erasing is forbidden by A-01.
Decision: in the DTB shipped on the SD card only, set `&sdhci` to
`status = "disabled"`. The SD-booted kernel then cannot enumerate the eMMC at
all, which both removes every kernel-level write path to it and resolves the
`by-name` ambiguity that caused Firefly's advice.
Why this rather than a procedural rule: it is enforced by hardware probing, not
by anyone remembering to be careful.
Residual risk: pre-kernel stages still see the eMMC. Mitigated by never placing a
Rockchip update image on the card (D-06).
Settled by: Stage 2, plus a post-boot hash comparison of eMMC partitions against
the backups.

### D-06: Never place a Rockchip update image on the card
**2026-09-18 · status: decided**
A Rockchip "SD Upgrade" card exists specifically to flash internal storage. Only
"SD Boot" structure is permitted. `update.img` and upgrade-tagged artefacts are
prohibited outputs and the build scripts refuse to emit them.

### D-07: Stage 0 is a diagnostic U-Boot card with no Android
**2026-09-18 · status: decided**
Evidence: rgriebl notes the stock eMMC U-Boot has console input disabled, but an
SD-supplied U-Boot can have it enabled.
Rationale: one cheap, read-only experiment settles A-03, identifies which MMC
index is the eMMC, and confirms the stock partition table against the backups,
before any Android image is built. Failing here costs an evening; failing at
Stage 2 without it costs a build cycle and leaves the cause ambiguous.

### A-08: No public download exists for the ShiMeta IoT-3399E Android 11 image
**2026-09-18 · status: assumed after searching**
Evidence: the ShiMeta product page advertises "Android 7.1 and 11.0" but exposes
no firmware, SDK or BSP download, and no ShiMeta download centre was found. An
Android 7.1.2 image for this board circulates on enthusiast forums; per A-09 it
was not downloaded and should not be.
Consequence: the image is probably a customer deliverable. Asking ShiMeta is the
highest-value next action and only James can take it.
Overturned by: ShiMeta supplying the image, or a legitimate vendor download
surfacing.

### A-09: No firmware from untrusted sources
**2026-09-18 · status: decided (constraint set by James)**
No firmware is downloaded from forum mirrors or random firmware sites. Vendor,
Firefly, Radxa and Rockchip sources only.

### D-10: Target selection: vendor Android 11 first, Firefly Android 10 as fallback
**2026-09-18 · status: decided, revisit when ShiMeta reply**
Ranked on peripheral compatibility, not version number:
1. ShiMeta IoT-3399E Android 11, if supplied. Board-specific, and the only option
   that starts with this panel, touch, amplifier and Wi-Fi already configured.
2. Firefly ROC-RK3399-PC-Plus Android 10 with the VAHA device tree ported in. The
   only RK3399 Android with a documented SD-boot procedure.
3. Radxa Android 11 for ROCK Pi 4. Source only, no documented SD boot.
Overturned by: ShiMeta's answer, or Stage 0 revealing a constraint that favours a
different base.

### A-07: Widevine is the real Phase 7 risk, not the Android version
**2026-09-18 · status: assumed**
A vendor image is far more likely to carry a provisioned Widevine keybox than a
self-built AOSP image, which typically lands at L3 or no Widevine at all.
Consequence: check `dumpsys media.drm` early in Phase 7, not at the end. Also
strengthens D-10's preference for the vendor image.

### A-11: The eMMC block device index is not yet established
**2026-09-18 · status: open**
The task description refers to `/dev/mmcblk1` as possibly the eMMC. This has not
been confirmed for this board and must not be hard-coded anywhere until it is.
Settled by: `by-name.txt` from the inventory, and `mmc list` at Stage 0.

### A-12: Minimum card 32 GB
**2026-09-18 · status: assumed**
Android 10/11 use dynamic partitions; `super` plus a usable `userdata` does not
fit comfortably on 16 GB.

### D-13: Project lives in `vaha-android-sd-boot/` inside the repository
**2026-09-18 · status: decided (routine, reversible)**
The repository root README is James's public profile. The project deliverables
are placed in a subdirectory so the profile is not overwritten. Move it out to a
repository of its own at any time; nothing depends on the path.

### A-14: Phase 1 cannot be executed from this session
**2026-09-18 · status: fact**
This session runs in a cloud container with no USB, no ADB and no serial access
to the VAHA, and the VAHA is powered down. The inventory harness was written
here; it has to be run by James on the Ubuntu workstation. The offline DTB
extraction from the existing backups needs no device at all and can be done first.
