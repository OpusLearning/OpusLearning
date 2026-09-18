#!/usr/bin/env bash
# collect-inventory.sh - Phase 1 hardware inventory for the VAHA X / IoT-3399E.
#
# READ-ONLY. This script issues no command that writes to the device. It does
# not use pm, settings, mount -o rw, dd of=, or any block-device write.
#
# Usage:  scripts/collect-inventory.sh [output-dir]
# Default output-dir: hardware-inventory/
#
# Requires: adb on PATH, exactly one device connected, root available via su.

set -euo pipefail

OUT="${1:-$(cd "$(dirname "$0")/.." && pwd)/hardware-inventory}"
mkdir -p "$OUT"

log()  { printf '[inv] %s\n' "$1"; }
warn() { printf '[inv] WARNING: %s\n' "$1" >&2; }
die()  { printf '[inv] ERROR: %s\n' "$1" >&2; exit 1; }

command -v adb >/dev/null || die "adb not found on PATH"

# Exactly one device, so we cannot address the wrong target.
mapfile -t DEVICES < <(adb devices | awk 'NR>1 && $2=="device" {print $1}')
case "${#DEVICES[@]}" in
    0) die "no ADB device connected. Power the VAHA on, enable USB debugging, and connect the USB A/A cable to the USB/ADB port." ;;
    1) log "target: ${DEVICES[0]}" ;;
    *) die "${#DEVICES[@]} ADB devices connected. Disconnect all but the VAHA; this script refuses to guess." ;;
esac

# Read-only wrappers.
sh_cmd()   { adb shell "$*" 2>&1 || true; }
root_cmd() { adb shell "su -c '$*'" 2>&1 || true; }

grab() {   # grab <outfile> <description> <command...>
    local f="$1"; shift
    local desc="$1"; shift
    log "$desc -> $f"
    { printf '# %s\n# command: %s\n# collected: %s\n\n' "$desc" "$*" "$(date -Is)"; sh_cmd "$@"; } > "$OUT/$f"
}

grab_root() {
    local f="$1"; shift
    local desc="$1"; shift
    log "$desc (root) -> $f"
    { printf '# %s\n# command (root): %s\n# collected: %s\n\n' "$desc" "$*" "$(date -Is)"; root_cmd "$@"; } > "$OUT/$f"
}

log "starting read-only inventory into $OUT"
date -Is > "$OUT/COLLECTED-AT.txt"

# --- 1-4: identity -----------------------------------------------------------
grab board-id.txt        "board and revision identifiers" \
    "getprop ro.product.model; getprop ro.product.device; getprop ro.product.board; getprop ro.board.platform; getprop ro.product.manufacturer; getprop ro.build.fingerprint; getprop ro.build.version.release; getprop ro.build.display.id; cat /proc/device-tree/model; echo; cat /proc/device-tree/compatible | tr '\0' ' '; echo"
grab cmdline.txt         "kernel command line"    "cat /proc/cmdline"
grab kernel-version.txt  "kernel version"         "cat /proc/version"
grab getprop.txt         "full property dump"     "getprop"
grab cpuinfo.txt         "CPU information"        "cat /proc/cpuinfo"
grab meminfo.txt         "memory information"     "cat /proc/meminfo"

# --- 5-6: device tree --------------------------------------------------------
log "live device tree -> device-tree.tar.gz"
if adb shell 'su -c "tar -cz -C /proc -f - device-tree"' > "$OUT/device-tree.tar.gz" 2>/dev/null \
   && [[ -s "$OUT/device-tree.tar.gz" ]]; then
    log "device tree captured ($(du -h "$OUT/device-tree.tar.gz" | cut -f1))"
else
    warn "tar of /proc/device-tree failed; falling back to a file-by-file pull"
    rm -f "$OUT/device-tree.tar.gz"
    adb pull /proc/device-tree "$OUT/device-tree" >/dev/null 2>&1 \
        || warn "could not pull /proc/device-tree. Use scripts/extract-dtb.sh against the partition backups instead."
fi

if command -v dtc >/dev/null && [[ -d "$OUT/device-tree" ]]; then
    dtc -I fs -O dts "$OUT/device-tree" > "$OUT/stock.dts" 2>/dev/null \
        && log "decompiled device tree -> stock.dts" \
        || warn "dtc could not decompile the pulled device tree"
elif ! command -v dtc >/dev/null; then
    warn "dtc not installed (apt install device-tree-compiler) - stock.dts not produced"
fi

# --- 7-9: storage layout -----------------------------------------------------
grab partitions.txt "partition table"     "cat /proc/partitions"
grab by-name.txt    "by-name partition map" \
    "ls -l /dev/block/by-name/ 2>/dev/null; echo '--- platform ---'; ls -l /dev/block/platform/*/by-name/ 2>/dev/null; ls -l /dev/block/platform/*/*/by-name/ 2>/dev/null"
grab blockdevs.txt  "block device tree"   "ls -lR /dev/block/ 2>/dev/null"
grab mounts.txt     "mounted filesystems" "cat /proc/mounts"
grab fstab.txt      "fstab files"         "cat /vendor/etc/fstab* /etc/fstab* /fstab.* 2>/dev/null"
grab_root mmc-sysfs.txt "MMC host and device sysfs" \
    "for d in /sys/class/mmc_host/*; do echo \"== \$d\"; cat \$d/../../*/type 2>/dev/null; ls \$d; done; echo '== block =='; for b in /sys/block/mmcblk*; do echo \"-- \$b\"; cat \$b/device/type 2>/dev/null; cat \$b/device/name 2>/dev/null; cat \$b/size 2>/dev/null; done"

# --- 10-11: display ----------------------------------------------------------
grab display.txt   "display service state" "dumpsys display"
grab drm-modes.txt "DRM connectors and modes" \
    "for c in /sys/class/drm/*/; do echo \"== \$c\"; cat \${c}status 2>/dev/null; cat \${c}modes 2>/dev/null; done; echo '== fb0 =='; cat /sys/class/graphics/fb0/modes 2>/dev/null; cat /sys/class/graphics/fb0/virtual_size 2>/dev/null; cat /sys/class/graphics/fb0/bits_per_pixel 2>/dev/null"
grab surfaceflinger.txt "SurfaceFlinger display config" "dumpsys SurfaceFlinger --display-id; wm size; wm density"

# --- 12-13: USB peripherals (touchscreen, camera) ----------------------------
grab_root usb-devices.txt "USB device tree with VID/PID" "cat /sys/kernel/debug/usb/devices"
grab input-devices.txt    "input devices"                "cat /proc/bus/input/devices"
grab usb-sysfs.txt        "USB sysfs VID/PID summary" \
    "for d in /sys/bus/usb/devices/*/; do v=\$(cat \${d}idVendor 2>/dev/null); p=\$(cat \${d}idProduct 2>/dev/null); [ -n \"\$v\" ] && echo \"\$d \$v:\$p \$(cat \${d}manufacturer 2>/dev/null) \$(cat \${d}product 2>/dev/null)\"; done"
grab camera.txt           "camera HAL state"             "dumpsys media.camera"

# --- 14: wifi / bluetooth ----------------------------------------------------
grab wifi.txt      "Wi-Fi state and chipset" \
    "getprop | grep -i -e wifi -e wlan; echo '--- driver ---'; ls -l /sys/class/net/wlan0/device/driver 2>/dev/null; cat /sys/class/net/wlan0/device/modalias 2>/dev/null; echo '--- ifconfig ---'; ifconfig wlan0 2>/dev/null"
grab bluetooth.txt "Bluetooth state and chipset" \
    "getprop | grep -i -e bluetooth -e bt_; dumpsys bluetooth_manager 2>/dev/null | head -50"
grab firmware-list.txt "vendor firmware blobs" \
    "ls -l /vendor/etc/firmware/ /system/etc/firmware/ /vendor/firmware/ /lib/firmware/ 2>/dev/null"

# --- 15: audio ---------------------------------------------------------------
grab audio.txt  "audio flinger state" "dumpsys media.audio_flinger"
grab asound.txt "ALSA cards and codecs" \
    "cat /proc/asound/cards 2>/dev/null; echo '--- pcm ---'; cat /proc/asound/pcm 2>/dev/null; for c in /proc/asound/card*/codec*; do echo \"== \$c\"; cat \$c 2>/dev/null; done"
grab audio-policy.txt "audio policy configuration" \
    "cat /vendor/etc/audio_policy_configuration.xml /system/etc/audio_policy*.conf 2>/dev/null"

# --- 16: gpio and power ------------------------------------------------------
grab_root gpio.txt "GPIO state" "cat /sys/kernel/debug/gpio"
grab interrupts.txt "interrupt map" "cat /proc/interrupts"
grab keylayout.txt "key layout files" \
    "ls /system/usr/keylayout/ /vendor/usr/keylayout/ 2>/dev/null; echo '--- gpio-keys ---'; cat /system/usr/keylayout/gpio-keys.kl 2>/dev/null"
grab power.txt "power and wakeup sources" \
    "getprop | grep -i -e power -e sleep -e wake; echo '--- wakeup ---'; ls /sys/class/wakeup/ 2>/dev/null"

# --- 17: modules -------------------------------------------------------------
grab modules.txt "loaded kernel modules" "lsmod; echo '--- available ---'; ls -lR /vendor/lib/modules/ /system/lib/modules/ 2>/dev/null"

# --- 18: HALs and vendor libraries -------------------------------------------
grab hals.txt       "registered HALs" "lshal 2>/dev/null || service list"
grab vendor-lib.txt "vendor libraries" "ls -lR /vendor/lib/ /vendor/lib64/ 2>/dev/null"
grab vendor-bin.txt "vendor binaries"  "ls -l /vendor/bin/ 2>/dev/null"

# --- 19: DRM / Widevine ------------------------------------------------------
grab drm.txt "DRM and Widevine capability" \
    "dumpsys media.drm 2>/dev/null; echo '--- props ---'; getprop | grep -i -e widevine -e drm"

# --- 20: packages ------------------------------------------------------------
grab packages.txt "installed packages with paths" "pm list packages -f"

# --- 21: logs ----------------------------------------------------------------
grab_root dmesg.txt "kernel ring buffer" "dmesg"
grab logcat-boot.txt "logcat, all buffers" "logcat -d -b all"

# --- 22: security state ------------------------------------------------------
grab security.txt "SELinux and verified boot state" \
    "getenforce; getprop ro.boot.veritymode; getprop ro.boot.verifiedbootstate; getprop ro.secure; getprop ro.debuggable; getprop ro.boot.storagemedia"

# --- manifest ----------------------------------------------------------------
log "writing SHA-256 manifest"
( cd "$OUT" && find . -type f ! -name 'MANIFEST.sha256' -print0 | sort -z | xargs -0 -r sha256sum > MANIFEST.sha256 )

log "done. $(find "$OUT" -type f | wc -l) files in $OUT"
log "Nothing was written to the device."
log "Next: review by-name.txt to establish which mmcblk device is the eMMC (assumption A-11)."
