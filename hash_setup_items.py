#!/usr/bin/env python3
"""Set each CUSTOM_SCRIPT_ITEM index to a stable numeric hash of its ID"""

import re
import sys
import zlib
from pathlib import Path

DIGITS = 8
ROOT = Path(__file__).resolve().parent
SETUP = ROOT / "Source/base/data/setup.ini"
HEADER = re.compile(r"^\[CUSTOM_SCRIPT_ITEM_(\d+)\](.*)$")
ID_LINE = re.compile(r"^ID\s*=\s*(\S+)")


def index_for(item_id: str) -> str:
    return str((zlib.crc32(item_id.encode()) & 0xFFFFFFFF) % 10**DIGITS)


def parse(text: str):
    lines = text.splitlines(keepends=True)
    items = []
    for i, line in enumerate(lines):
        match = HEADER.match(line.rstrip("\r\n"))
        if not match:
            continue
        item_id = None
        for nxt in lines[i + 1 :]:
            body = nxt.rstrip("\r\n")
            if body.startswith("["):
                break
            id_match = ID_LINE.match(body.strip())
            if id_match:
                item_id = id_match.group(1)
                break
        items.append((i, match.group(1), match.group(2), item_id))
    return lines, items


def rewrite(path: Path, old_to_new=None, taken=None):
    lines, items = parse(path.read_text(encoding="utf-8"))
    mapping, owners = {}, dict(taken or {})
    for line_i, old, suffix, item_id in items:
        if item_id:
            new = index_for(item_id)
            other = owners.get(new)
            if other and other != item_id:
                sys.exit(f"{path}: {other} and {item_id} both hash to {new}")
            owners[new] = item_id
        elif old_to_new and old in old_to_new:
            new = old_to_new[old]
        else:
            sys.exit(f"{path}: CUSTOM_SCRIPT_ITEM_{old} has no ID")
        if old in mapping and mapping[old] != new:
            sys.exit(f"{path}: CUSTOM_SCRIPT_ITEM_{old} maps to two indices")
        mapping[old] = new
        ending = lines[line_i][len(lines[line_i].rstrip("\r\n")) :]
        lines[line_i] = f"[CUSTOM_SCRIPT_ITEM_{new}]{suffix}{ending}"
    path.write_bytes("".join(lines).encode("utf-8"))
    return mapping, owners


def main():
    base_map, owners = rewrite(SETUP)
    print(f"{SETUP.relative_to(ROOT)}: {len(base_map)} items")
    for addon in sorted(ROOT.glob("Source/*/data/setup.addon.ini")):
        rewrite(addon, base_map, owners)
        print(f"{addon.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
