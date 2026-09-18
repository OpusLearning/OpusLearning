#!/usr/bin/env bash
# guard.sh - refuse to write to anything that could be the VAHA eMMC, the
# workstation's own disk, or any device that is not a removable SD card.
#
# Source this from any script capable of writing to a block device:
#     source "$(dirname "$0")/lib/guard.sh"
#     guard_check_target /dev/sdX
#     guard_confirm_target /dev/sdX
#
# There is deliberately no --force flag. Do not add one.

set -euo pipefail

guard_die() {
    printf '\n[GUARD] REFUSED: %s\n' "$1" >&2
    printf '[GUARD] Safety rule: the VAHA eMMC is read-only for this project.\n' >&2
    exit 1
}

guard_info() { printf '[guard] %s\n' "$1"; }

# Strip /dev/ and any partition suffix to get the parent block device name.
guard_basedev() {
    local dev="${1#/dev/}"
    if [[ "$dev" =~ ^(mmcblk[0-9]+)p[0-9]+$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    elif [[ "$dev" =~ ^(nvme[0-9]+n[0-9]+)p[0-9]+$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    elif [[ "$dev" =~ ^(sd[a-z]+)[0-9]+$ ]]; then
        printf '%s' "${BASH_REMATCH[1]}"
    else
        printf '%s' "$dev"
    fi
}

guard_sysattr() {
    local path="$1"
    [[ -r "$path" ]] && cat "$path" 2>/dev/null || printf ''
}

# guard_check_target /dev/sdX
# Aborts unless every condition for a safe SD-card target is met.
guard_check_target() {
    local target="${1:-}"
    [[ -n "$target" ]] || guard_die "no target device given"

    # 1. Whole devices only, and only shapes we expect an SD card to take.
    local dev base
    dev="${target#/dev/}"
    base="$(guard_basedev "$target")"
    [[ "$dev" == "$base" ]] \
        || guard_die "$target is a partition. Give the whole device, e.g. /dev/${base}"
    [[ "$dev" =~ ^(sd[a-z]+|mmcblk[0-9]+)$ ]] \
        || guard_die "$target is not a shape an SD card takes (expected /dev/sdX or /dev/mmcblkN)"
    [[ -b "$target" ]] || guard_die "$target is not a block device"

    local sys="/sys/block/${dev}"
    [[ -d "$sys" ]] || guard_die "no sysfs entry for $target"

    # 2. eMMC is refused unconditionally, by MMC type.
    local mmctype
    mmctype="$(guard_sysattr "${sys}/device/type")"
    if [[ -n "$mmctype" ]]; then
        guard_info "MMC type reports: ${mmctype}"
        [[ "$mmctype" == "SD" ]] \
            || guard_die "$target reports MMC type '${mmctype}'. Anything that is not 'SD' is treated as eMMC and refused."
    fi

    # An MMC name of the form mmcXX:0001 with a boot area is eMMC.
    if compgen -G "${sys}boot0" >/dev/null 2>&1 || [[ -e "/dev/${dev}boot0" ]]; then
        guard_die "$target has an eMMC boot area (${dev}boot0). This is eMMC, not an SD card."
    fi

    # 3. Removable, or an SD card behind a USB reader.
    local removable transport
    removable="$(guard_sysattr "${sys}/removable")"
    transport=""
    if [[ -L "${sys}/device" ]]; then
        transport="$(readlink -f "${sys}/device" || true)"
    fi
    if [[ "$removable" != "1" ]]; then
        if [[ "$transport" == *"/usb"* ]]; then
            guard_info "not flagged removable, but sits behind USB: ${transport}"
        else
            guard_die "$target is not removable (removable=${removable:-unknown}) and is not behind USB. This looks like a fixed disk."
        fi
    fi

    # 4. Nothing on it may be mounted, and it must not host the running system.
    local mounted
    mounted="$(lsblk -nro MOUNTPOINT "$target" 2>/dev/null | grep -v '^$' || true)"
    if [[ -n "$mounted" ]]; then
        guard_die "$target has mounted filesystems: $(echo "$mounted" | tr '\n' ' ')"
    fi
    local rootsrc rootdev
    rootsrc="$(findmnt -nro SOURCE / 2>/dev/null || true)"
    if [[ -n "$rootsrc" ]]; then
        rootdev="$(guard_basedev "$rootsrc")"
        [[ "$rootdev" != "$dev" ]] \
            || guard_die "$target hosts the running root filesystem"
    fi
    local mp
    for mp in /boot /home /; do
        local src
        src="$(findmnt -nro SOURCE "$mp" 2>/dev/null || true)"
        [[ -z "$src" ]] && continue
        [[ "$(guard_basedev "$src")" != "$dev" ]] \
            || guard_die "$target hosts $mp"
    done

    # 5. Size sanity: 4 GB to 512 GB.
    local sectors bytes
    sectors="$(guard_sysattr "${sys}/size")"
    [[ -n "$sectors" ]] || guard_die "cannot read size of $target"
    bytes=$(( sectors * 512 ))
    if (( bytes < 4000000000 )); then
        guard_die "$target is $(( bytes / 1000000 )) MB, smaller than the 4 GB minimum"
    fi
    if (( bytes > 512000000000 )); then
        guard_die "$target is $(( bytes / 1000000000 )) GB, larger than the 512 GB maximum. A device this large is more likely a hard disk than the SD card you meant."
    fi

    guard_info "$target passed all automatic checks"
    return 0
}

# guard_describe /dev/sdX - print model, serial, size, vendor
guard_describe() {
    local target="$1" dev sys
    dev="${target#/dev/}"
    sys="/sys/block/${dev}"
    printf '\n  Device : %s\n' "$target"
    printf '  Vendor : %s\n' "$(guard_sysattr "${sys}/device/vendor" | tr -d '\n' | xargs || echo unknown)"
    printf '  Model  : %s\n' "$(guard_sysattr "${sys}/device/model" | tr -d '\n' | xargs || echo unknown)"
    printf '  Name   : %s\n' "$(guard_sysattr "${sys}/device/name" | tr -d '\n' | xargs || echo unknown)"
    printf '  Serial : %s\n' "$(guard_sysattr "${sys}/device/serial" | tr -d '\n' | xargs || echo unknown)"
    printf '  CID    : %s\n' "$(guard_sysattr "${sys}/device/cid" | tr -d '\n' | xargs || echo n/a)"
    printf '  Size   : %s\n' "$(lsblk -dnro SIZE "$target" 2>/dev/null || echo unknown)"
    printf '  Type   : %s\n' "$(guard_sysattr "${sys}/device/type" | tr -d '\n' | xargs || echo n/a)"
    printf '\n'
    lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,MODEL,SERIAL "$target" 2>/dev/null || true
    printf '\n'
}

# guard_confirm_target /dev/sdX - require the operator to retype the identity.
guard_confirm_target() {
    local target="$1" dev sys model serial expect reply
    dev="${target#/dev/}"
    sys="/sys/block/${dev}"
    model="$(guard_sysattr "${sys}/device/model" | tr -d '\n' | xargs || true)"
    [[ -n "$model" ]] || model="$(guard_sysattr "${sys}/device/name" | tr -d '\n' | xargs || true)"
    serial="$(guard_sysattr "${sys}/device/serial" | tr -d '\n' | xargs || true)"
    [[ -n "$serial" ]] || serial="$(guard_sysattr "${sys}/device/cid" | tr -d '\n' | xargs || true)"
    [[ -n "$model" ]] || model="unknown"
    [[ -n "$serial" ]] || serial="unknown"

    guard_describe "$target"
    expect="${model} ${serial}"
    printf 'This will DESTROY everything on %s.\n' "$target"
    printf 'To confirm, retype exactly:  %s\n' "$expect"
    printf '> '
    IFS= read -r reply || guard_die "no confirmation given"
    [[ "$reply" == "$expect" ]] || guard_die "confirmation did not match. Nothing was written."
    guard_info "target confirmed by operator"
}

# guard_reject_update_image <file> - refuse Rockchip upgrade artefacts.
guard_reject_update_image() {
    local f="$1"
    [[ -e "$f" ]] || return 0
    case "$(basename "$f")" in
        update.img|update_*.img|*upgrade*.img)
            guard_die "$f looks like a Rockchip update image. Update images exist to flash internal storage and are prohibited by this project." ;;
    esac
    if head -c 16 "$f" 2>/dev/null | grep -qa 'RKFW\|RKAF'; then
        guard_die "$f carries a Rockchip firmware/upgrade header (RKFW/RKAF). Prohibited by this project."
    fi
    return 0
}
