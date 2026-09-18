#!/usr/bin/env python3
"""Build a Rockchip-structured SD card image as a file. Never touches a device.

Subcommands
-----------
plan     <parameter.txt>            Parse a Rockchip parameter.txt and print the
                                    partition layout it describes.
stage0   --idbloader F --uboot F    Build the Stage 0 diagnostic card: mainline
         -o out.img [--size 8G]     idbloader + U-Boot FIT, no Android at all.
android  --bsp DIR -o out.img       Build an Android SD boot image from a
         [--size 32G] [--confirm-layout]   Rockchip rockdev output directory.

Safety
------
* Writes only to the output file given with -o. It takes no device argument and
  has no code path that opens a block device.
* Refuses any input that looks like a Rockchip update/upgrade image, because
  those exist to flash internal storage.
* `android` refuses to run without --confirm-layout until the loader offsets
  have been confirmed against the chosen BSP. See SD-BOOT-DESIGN.md section 3.
"""

import argparse
import os
import re
import shutil
import struct
import subprocess
import sys

SECTOR = 512
IDB_SECTOR = 64           # RK3399 BootROM looks for the ID block here
UBOOT_FIT_SECTOR = 16384  # mainline convention for u-boot.itb
FIRST_PART_SECTOR = 32768 # mainline convention: first partition at 16 MiB

RK_UPDATE_MAGICS = (b"RKFW", b"RKAF")


def die(msg):
    print("ERROR: %s" % msg, file=sys.stderr)
    sys.exit(1)


def parse_size(text):
    text = str(text).strip().upper()
    mult = 1
    if text.endswith("G"):
        mult, text = 1024 ** 3, text[:-1]
    elif text.endswith("M"):
        mult, text = 1024 ** 2, text[:-1]
    elif text.endswith("K"):
        mult, text = 1024, text[:-1]
    return int(float(text) * mult)


def reject_update_image(path):
    """Refuse Rockchip upgrade artefacts (SD-BOOT-DESIGN.md, decision D-06)."""
    name = os.path.basename(path).lower()
    if name == "update.img" or name.startswith("update_") or "upgrade" in name:
        die("%s looks like a Rockchip update image. Update images exist to "
            "flash internal storage and are prohibited by this project "
            "(decision D-06)." % path)
    try:
        with open(path, "rb") as fh:
            head = fh.read(8)
    except OSError:
        return
    for magic in RK_UPDATE_MAGICS:
        if head.startswith(magic):
            die("%s carries a Rockchip firmware header (%s). Prohibited by "
                "decision D-06." % (path, magic.decode()))


# --------------------------------------------------------------------------
# parameter.txt
# --------------------------------------------------------------------------

PART_RE = re.compile(r"(0x[0-9a-fA-F]+|-)@(0x[0-9a-fA-F]+)\(([^)]+)\)")


def parse_parameter(path):
    """Return (cmdline, [(name, start_sector, size_sectors_or_None), ...])."""
    with open(path, "r", errors="replace") as fh:
        text = fh.read()

    cmdline = ""
    for line in text.splitlines():
        if line.strip().upper().startswith("CMDLINE:"):
            cmdline = line.split(":", 1)[1].strip()
            break
    if not cmdline:
        die("no CMDLINE: line found in %s" % path)

    m = re.search(r"mtdparts=[^\s:]+:(.*)", cmdline)
    if not m:
        die("no mtdparts= section found in the CMDLINE of %s" % path)

    parts = []
    for size_s, start_s, name in PART_RE.findall(m.group(1)):
        start = int(start_s, 16)
        size = None if size_s == "-" else int(size_s, 16)
        # Rockchip names may carry a leading flag such as ':grow'
        name = name.split(":")[0].strip()
        parts.append((name, start, size))
    if not parts:
        die("mtdparts section in %s contained no partitions" % path)
    return cmdline, parts


def cmd_plan(args):
    cmdline, parts = parse_parameter(args.parameter)
    print("CMDLINE:\n  %s\n" % cmdline)
    print("%-20s %14s %14s %12s %12s" % ("name", "start(sector)", "size(sector)",
                                         "start(MiB)", "size(MiB)"))
    total = 0
    for name, start, size in parts:
        size_mib = "grow" if size is None else "%.1f" % (size * SECTOR / 1048576.0)
        print("%-20s %14d %14s %12.1f %12s"
              % (name, start, "grow" if size is None else size,
                 start * SECTOR / 1048576.0, size_mib))
        if size:
            total = max(total, (start + size) * SECTOR)
    print("\nminimum card size implied by fixed partitions: %.2f GiB"
          % (total / (1024.0 ** 3)))

    for flag in ("storagemedia", "androidboot.mode", "root="):
        if flag in cmdline:
            print("note: CMDLINE contains %r - check it is correct for SD boot"
                  % flag)
    return 0


# --------------------------------------------------------------------------
# image writing
# --------------------------------------------------------------------------

def create_image(path, size_bytes):
    if os.path.exists(path):
        die("%s already exists. Remove it or choose another name; this script "
            "will not overwrite." % path)
    with open(path, "wb") as fh:
        fh.truncate(size_bytes)
    print("created %s (%.2f GiB)" % (path, size_bytes / (1024.0 ** 3)))


def write_at(image, src, sector):
    reject_update_image(src)
    size = os.path.getsize(src)
    end = sector * SECTOR + size
    if end > os.path.getsize(image):
        die("%s (%d bytes) at sector %d would run past the end of the image"
            % (src, size, sector))
    with open(image, "r+b") as dst, open(src, "rb") as fh:
        dst.seek(sector * SECTOR)
        shutil.copyfileobj(fh, dst)
    print("  wrote %-24s %8d bytes at sector %-8d (offset %d)"
          % (os.path.basename(src), size, sector, sector * SECTOR))


def cmd_stage0(args):
    for f in (args.idbloader, args.uboot):
        if not os.path.isfile(f):
            die("%s does not exist" % f)
        reject_update_image(f)

    size = parse_size(args.size)
    if size < 64 * 1024 * 1024:
        die("image size %s is too small" % args.size)

    create_image(args.output, size)
    print("writing the Stage 0 diagnostic layout (mainline U-Boot convention):")
    write_at(args.output, args.idbloader, IDB_SECTOR)
    write_at(args.output, args.uboot, UBOOT_FIT_SECTOR)
    print("\nStage 0 image complete. It contains NO Android and NO update image.")
    print("Boot it with UART capturing at 1500000 8N1 and expect a U-Boot prompt.")
    print("From that prompt use only read commands: mmc list, part list, md.")
    return 0


def cmd_android(args):
    bsp = args.bsp
    if not os.path.isdir(bsp):
        die("%s is not a directory" % bsp)

    param = os.path.join(bsp, "parameter.txt")
    if not os.path.isfile(param):
        die("no parameter.txt in %s. Point --bsp at the BSP's rockdev output "
            "directory." % bsp)

    for entry in sorted(os.listdir(bsp)):
        reject_update_image(os.path.join(bsp, entry))

    cmdline, parts = parse_parameter(param)

    loader = None
    for cand in ("MiniLoaderAll.bin", "idbloader.img"):
        p = os.path.join(bsp, cand)
        if os.path.isfile(p):
            loader = p
            break
    if loader is None:
        die("no MiniLoaderAll.bin or idbloader.img in %s" % bsp)

    print("BSP        : %s" % bsp)
    print("loader     : %s" % os.path.basename(loader))
    print("partitions : %d from parameter.txt" % len(parts))
    print()

    missing = []
    plan = []
    for name, start, size in parts:
        src = None
        for cand in ("%s.img" % name, name):
            p = os.path.join(bsp, cand)
            if os.path.isfile(p):
                src = p
                break
        if src is None:
            missing.append(name)
        plan.append((name, start, size, src))

    for name, start, size, src in plan:
        print("  %-16s sector %-10d %-12s %s"
              % (name, start,
                 "grow" if size is None else "%d" % size,
                 os.path.basename(src) if src else "(created empty)"))
    if missing:
        print("\nnote: no image supplied for: %s" % ", ".join(missing))
        print("      these are normally created empty on first boot "
              "(userdata, misc, metadata); check that none of them should "
              "have carried content.")

    if not args.confirm_layout:
        print("\nSTOPPING before writing anything.")
        print("The offset at which this BSP expects parameter.txt itself to be")
        print("written has not been confirmed for the chosen BSP, and this")
        print("script will not guess it. Confirm it against the BSP's own")
        print("flashing tool or documentation, record it in DECISIONS.md, then")
        print("re-run with --confirm-layout.")
        print("See SD-BOOT-DESIGN.md section 3.")
        return 3

    size = parse_size(args.size)
    create_image(args.output, size)
    write_at(args.output, loader, IDB_SECTOR)
    for name, start, _size, src in plan:
        if src:
            write_at(args.output, src, start)

    print("\nAndroid SD image written to %s" % args.output)
    print("Inspect it offline before going anywhere near a card:")
    print("  sgdisk -p %s   (or: fdisk -l %s)" % (args.output, args.output))
    print("  sha256sum %s" % args.output)
    return 0


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = ap.add_subparsers(dest="cmd", required=True)

    p = sub.add_parser("plan", help="parse a parameter.txt and print the layout")
    p.add_argument("parameter")
    p.set_defaults(func=cmd_plan)

    p = sub.add_parser("stage0", help="build the diagnostic U-Boot card image")
    p.add_argument("--idbloader", required=True)
    p.add_argument("--uboot", required=True)
    p.add_argument("--size", default="8G")
    p.add_argument("-o", "--output", required=True)
    p.set_defaults(func=cmd_stage0)

    p = sub.add_parser("android", help="build an Android SD boot image")
    p.add_argument("--bsp", required=True, help="Rockchip rockdev output directory")
    p.add_argument("--size", default="32G")
    p.add_argument("--confirm-layout", action="store_true")
    p.add_argument("-o", "--output", required=True)
    p.set_defaults(func=cmd_android)

    args = ap.parse_args()
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
