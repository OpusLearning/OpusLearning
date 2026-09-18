# HARDWARE-INVENTORY: VAHA X / ShiMeta IoT-3399E

**Status: not yet collected.** This session had no access to the VAHA. The
device is powered down, and this session runs in a cloud container with no USB,
no ADB and no serial port, so it could not have reached the device even if it
were powered on.

What exists today is the collection harness, not the data. Running
`scripts/collect-inventory.sh` on your Ubuntu workstation with the VAHA powered
on and ADB connected fills `hardware-inventory/` and this report becomes real.

Everything the harness does is read-only. It issues no `pm`, no `settings put`,
no `mount -o rw`, no `dd of=`, and it never touches a block device for writing.
The script refuses to run if it detects more than one ADB device, so it cannot
address the wrong target.

## Why this matters before anything is built

The stock Android 7.1.2 installation is the only complete, working specification
of this hardware that exists. The vendor's published PDF documents a different
board revision, and the public RK3399 reference device trees do not describe this
panel, this amplifier or this power arrangement. The stock DTB does.

`RESEARCH.md` section 6 explains why: an Android 10 or 11 image built for a
reference board will start the kernel and then go silent, exactly as rgriebl's
generic Linux images did, because it has no correct device tree. The inventory is
what lets us write one.

## What gets collected

Each item lands as a file in `hardware-inventory/`, with a SHA-256 recorded in
`hardware-inventory/MANIFEST.sha256`.

| # | Item | Output file | Method |
|---|---|---|---|
| 1 | Board and revision identifiers | `board-id.txt` | `getprop`, `/proc/device-tree/model`, `/proc/device-tree/compatible` |
| 2 | Kernel command line | `cmdline.txt` | `cat /proc/cmdline` |
| 3 | Kernel version and build | `kernel-version.txt` | `cat /proc/version` |
| 4 | Full property dump | `getprop.txt` | `getprop` |
| 5 | Live device tree | `device-tree.tar.gz` | tar of `/proc/device-tree`, read-only |
| 6 | Decompiled device tree | `stock.dts` | `dtc -I fs -O dts /proc/device-tree`, or offline from the resource partition |
| 7 | Partition table | `partitions.txt`, `by-name.txt` | `cat /proc/partitions`, `ls -l /dev/block/by-name/` |
| 8 | Block device map | `blockdevs.txt` | `ls -l /dev/block/platform/*/*/by-name/` |
| 9 | Mount and fstab state | `mounts.txt`, `fstab.txt` | `cat /proc/mounts`, vendor fstab |
| 10 | Display and LVDS configuration | `display.txt`, `drm-modes.txt` | `dumpsys display`, `/sys/class/drm/*/modes`, `/sys/class/graphics/fb0/*` |
| 11 | Panel timings | extracted from `stock.dts` | the `panel-timing` node under the LVDS/panel node |
| 12 | Touchscreen VID/PID and driver | `usb-devices.txt`, `input-devices.txt` | `cat /sys/kernel/debug/usb/devices`, `/proc/bus/input/devices` |
| 13 | Camera VID/PID | `usb-devices.txt` | same source, identified by class |
| 14 | Wi-Fi and Bluetooth chipset | `wifi.txt`, `bluetooth.txt`, `firmware-list.txt` | `getprop`, `/sys/class/net/wlan0/device/`, `ls /vendor/etc/firmware` and `/system/etc/firmware` |
| 15 | Audio codec and amplifier | `audio.txt`, `asound.txt` | `/proc/asound/cards`, `/proc/asound/*/codec*`, `dumpsys media.audio_flinger` |
| 16 | GPIO and power button | `gpio.txt`, `keylayout.txt` | `/sys/kernel/debug/gpio`, `/proc/interrupts`, key layout files |
| 17 | Loaded kernel modules | `modules.txt` | `lsmod`, `ls /vendor/lib/modules` |
| 18 | Android HALs and vendor libraries | `hals.txt`, `vendor-lib.txt` | `lshal` where present, `ls -lR /vendor/lib*` |
| 19 | DRM / Widevine capability | `drm.txt` | `dumpsys media.drm`, `getprop` filtered for widevine |
| 20 | Installed packages | `packages.txt` | `pm list packages -f` |
| 21 | Full boot log | `dmesg.txt`, `logcat-boot.txt` | `dmesg`, `logcat -d -b all` |
| 22 | SELinux and verified boot state | `security.txt` | `getenforce`, `getprop ro.boot.veritymode` |

Items 1 to 9 and 21 are the ones the SD-boot design depends on directly. Items 10
to 18 are what the device-tree port needs. Item 19 decides how much of Phase 7 is
achievable, and is worth reading early rather than at the end.

## Offline extraction from the existing backups

If the VAHA stays off, several of the most important items can still be recovered
from the 13 partition backups you already have, with no device access at all.
`scripts/extract-dtb.sh` does this: the `resource` partition holds the DTB in
Rockchip's resource container, and `boot.img` holds the kernel and ramdisk.

This is worth doing first, because it is free, it risks nothing, and the DTB is
the single most valuable artefact in the whole project. Point the script at your
backup directory and it will produce `stock.dtb` and `stock.dts` without the VAHA
being powered on at all.

## Current gaps

Everything. No inventory data has been collected. The table above is the
specification for what "collected" means, and `hardware-inventory/README.md`
describes the file format so the results are machine-readable.

Known facts carried over from research, to be confirmed against the collected
data rather than trusted:

- eMMC device node is expected to be `/dev/block/mmcblk*`; **which index is the
  eMMC has not been confirmed on this board** and must be established before any
  script refers to it. Stage 0 of `SD-BOOT-DESIGN.md` confirms it from U-Boot,
  and `by-name.txt` confirms it from Android.
- 13 partitions backed up and hash-verified. The inventory should confirm that
  the backup set matches `by-name.txt` exactly, with nothing missing.
