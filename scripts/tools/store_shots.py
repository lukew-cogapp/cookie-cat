#!/usr/bin/env python3
"""Copies the chosen game screenshots into store/screenshots for Play.

Play wants screenshots as JPEG or 24-bit PNG with no alpha channel, and
Godot's save_png writes RGBA, so the copy re-encodes as colour type 2.
Run test/shots.gd first; the order here is the upload order.

    python3 scripts/tools/store_shots.py
"""

import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SHOTS = ROOT / "test" / "shots"
STORE = ROOT / "store" / "screenshots"

# Upload order: action first, the shop last. Play shows the first two or
# three in search results, so they carry the pitch.
PICKS = [
    ("03_all_weapons.png", "01_toys_firing.png"),
    ("05_boss.png", "02_big_bug.png"),
    ("02_crowd.png", "03_bug_ring.png"),
    ("20_eclipse.png", "04_eclipse.png"),
    ("06_level_up.png", "05_pick_screen.png"),
    ("00_shop.png", "06_shop.png"),
]


def read_rgba(path):
    data = path.read_bytes()
    width, height = struct.unpack(">II", data[16:24])
    if data[25] != 6:
        raise SystemExit(f"{path.name}: expected RGBA, got colour type {data[25]}")
    idat = b""
    i = 8
    while i < len(data):
        (length,) = struct.unpack(">I", data[i : i + 4])
        if data[i + 4 : i + 8] == b"IDAT":
            idat += data[i + 8 : i + 8 + length]
        i += 12 + length
    raw = zlib.decompress(idat)
    stride = width * 4 + 1
    prev = bytearray(width * 4)
    rows = []
    for y in range(height):
        kind = raw[y * stride]
        px = bytearray(raw[y * stride + 1 : (y + 1) * stride])
        if kind == 1:
            for x in range(4, len(px)):
                px[x] = (px[x] + px[x - 4]) & 255
        elif kind == 2:
            for x in range(len(px)):
                px[x] = (px[x] + prev[x]) & 255
        elif kind == 3:
            for x in range(len(px)):
                a = px[x - 4] if x >= 4 else 0
                px[x] = (px[x] + ((a + prev[x]) >> 1)) & 255
        elif kind == 4:
            for x in range(len(px)):
                a = px[x - 4] if x >= 4 else 0
                b = prev[x]
                c = prev[x - 4] if x >= 4 else 0
                guess = a + b - c
                da, db, dc = abs(guess - a), abs(guess - b), abs(guess - c)
                nearest = a if da <= db and da <= dc else (b if db <= dc else c)
                px[x] = (px[x] + nearest) & 255
        prev = px
        rows.append(px)
    return width, height, rows


def write_rgb(path, width, height, rows):
    out = []
    for px in rows:
        row = bytearray([0])
        for x in range(0, len(px), 4):
            row += px[x : x + 3]
        out.append(bytes(row))
    raw = zlib.compress(b"".join(out), 9)

    def chunk(tag, data):
        head = struct.pack(">I", len(data)) + tag
        return head + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    path.write_bytes(
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", ihdr)
        + chunk(b"IDAT", raw)
        + chunk(b"IEND", b"")
    )


def main():
    STORE.mkdir(parents=True, exist_ok=True)
    missing = [src for src, _ in PICKS if not (SHOTS / src).exists()]
    if missing:
        sys.exit(f"run test/shots.gd first; missing {', '.join(missing)}")
    for src, dst in PICKS:
        width, height, rows = read_rgba(SHOTS / src)
        write_rgb(STORE / dst, width, height, rows)
        print(f"store/screenshots/{dst} {width}x{height}", flush=True)


if __name__ == "__main__":
    main()
