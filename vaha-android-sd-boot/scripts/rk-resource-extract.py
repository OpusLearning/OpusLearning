#!/usr/bin/env python3
"""Extract files (notably the DTB) from a Rockchip resource image.

Read-only. Operates on backup files on the workstation. Never touches a device.

Rockchip's resource container:

    resource_img_hdr   magic 'RSCE', version, c_version, blks, c_blks, file_nums
    resource_content   magic 'ENTR', path[220], offset (in 512-byte blocks), size

The container may sit in a dedicated 'resource' partition, or be embedded in an
Android boot image (magic 'ANDROID!'), so this scans for the RSCE magic if the
file does not start with it.

Usage:
    rk-resource-extract.py <resource-or-boot-image> [output-dir]
    rk-resource-extract.py --list <image>
"""

import os
import struct
import sys

BLOCK = 512
RSCE_MAGIC = b"RSCE"
ENTR_MAGIC = b"ENTR"
ANDROID_MAGIC = b"ANDROID!"


def find_rsce(data):
    """Return the offset of the RSCE header, or None."""
    if data[:4] == RSCE_MAGIC:
        return 0
    # Scan on block boundaries; the container is always block aligned.
    for off in range(0, len(data) - 4, BLOCK):
        if data[off:off + 4] == RSCE_MAGIC:
            return off
    return None


def parse(data, base):
    magic, version, c_version, blks, c_blks, file_nums = struct.unpack_from(
        "<4sHHBBI", data, base)
    if magic != RSCE_MAGIC:
        raise ValueError("no RSCE magic at offset %d" % base)
    entries = []
    for i in range(file_nums):
        off = base + (blks * BLOCK) + (i * c_blks * BLOCK)
        if off + 232 > len(data):
            raise ValueError("entry %d runs past end of image" % i)
        e_magic, path, e_off, e_size = struct.unpack_from("<4s220sII", data, off)
        if e_magic != ENTR_MAGIC:
            raise ValueError("entry %d has bad magic %r" % (i, e_magic))
        name = path.split(b"\0", 1)[0].decode("utf-8", "replace")
        entries.append((name, base + e_off * BLOCK, e_size))
    return {
        "version": version,
        "c_version": c_version,
        "blks": blks,
        "c_blks": c_blks,
        "entries": entries,
    }


def main(argv):
    listonly = False
    args = [a for a in argv[1:] if a != "--list"]
    if len(args) != len(argv[1:]):
        listonly = True
    if not args:
        print(__doc__)
        return 2

    path = args[0]
    outdir = args[1] if len(args) > 1 else "."

    with open(path, "rb") as fh:
        data = fh.read()

    if data[:8] == ANDROID_MAGIC:
        print("note: %s is an Android boot image; scanning it for an embedded "
              "resource container" % path)

    base = find_rsce(data)
    if base is None:
        print("ERROR: no Rockchip resource container (RSCE) found in %s" % path,
              file=sys.stderr)
        print("       If this is the boot partition, try the resource partition "
              "instead, or vice versa.", file=sys.stderr)
        return 1
    if base:
        print("found RSCE container at offset %d (0x%x)" % (base, base))

    info = parse(data, base)
    print("resource version %d.%d, %d entries"
          % (info["version"], info["c_version"], len(info["entries"])))

    rc = 0
    for name, off, size in info["entries"]:
        print("  %-40s offset %-10d size %d" % (name, off, size))
        if listonly:
            continue
        if off + size > len(data):
            print("    SKIPPED: entry runs past end of image", file=sys.stderr)
            rc = 1
            continue
        dest = os.path.join(outdir, os.path.basename(name))
        os.makedirs(os.path.dirname(dest) or ".", exist_ok=True)
        with open(dest, "wb") as out:
            out.write(data[off:off + size])
        print("    -> %s" % dest)
    return rc


if __name__ == "__main__":
    sys.exit(main(sys.argv))
