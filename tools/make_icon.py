#!/usr/bin/env python3
"""Generate CueSense's addon icon as a 32-bit TGA — no PIL required.

Draws a small "pulse" motif (a bright dot with two emanating rings) in the
addon's teal on a dark rounded square, then writes an uncompressed BGRA TGA
with the top-left-origin descriptor byte (0x28) WoW's loader expects.

Writes ../Icon.tga.  Re-run:  python3 tools/make_icon.py
"""

import math
import os
import struct

SIZE = 64
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "Icon.tga"))

# Colors as (r, g, b).
BG = (18, 28, 30)            # dark slate
TEAL = (51, 219, 187)        # the addon accent (#33ddbb)

# pixel buffer: list of [b, g, r, a], row-major top-to-bottom
buf = [[0, 0, 0, 0] for _ in range(SIZE * SIZE)]


def blend(px, r, g, b, a):
    """Alpha-composite (r,g,b,a in 0..255) over existing pixel px (BGRA)."""
    if a <= 0:
        return
    af = a / 255.0
    px[0] = int(b * af + px[0] * (1 - af))
    px[1] = int(g * af + px[1] * (1 - af))
    px[2] = int(r * af + px[2] * (1 - af))
    px[3] = min(255, int(a + px[3] * (1 - af)))


def rounded_rect_alpha(x, y, w, h, radius):
    """Coverage (0..1) for an antialiased rounded rectangle at (x,y)."""
    cx = min(max(x, radius), w - radius)
    cy = min(max(y, radius), h - radius)
    d = math.hypot(x - cx, y - cy)
    return max(0.0, min(1.0, radius - d + 0.5))


def main():
    cx, cy = (SIZE - 1) / 2.0, (SIZE - 1) / 2.0
    for y in range(SIZE):
        for x in range(SIZE):
            px = buf[y * SIZE + x]
            # Dark rounded-square background.
            cov = rounded_rect_alpha(x, y, SIZE, SIZE, 13)
            if cov > 0:
                blend(px, BG[0], BG[1], BG[2], int(235 * cov))
            d = math.hypot(x - cx, y - cy)
            # Center dot.
            dot = max(0.0, min(1.0, 6.5 - d + 0.5))
            if dot > 0:
                blend(px, TEAL[0], TEAL[1], TEAL[2], int(255 * dot))
            # Two emanating rings (annuli), fading outward.
            for radius, alpha in ((15.0, 200), (24.0, 120)):
                ring = max(0.0, 1.0 - abs(d - radius) / 2.0)
                if ring > 0:
                    blend(px, TEAL[0], TEAL[1], TEAL[2], int(alpha * ring))

    header = struct.pack(
        "<BBBHHBHHHHBB",
        0,        # id length
        0,        # color map type
        2,        # image type: uncompressed true-color
        0, 0, 0,  # color map spec (origin, length, entry size)
        0, 0,     # x/y origin
        SIZE, SIZE,
        32,       # bits per pixel
        0x28,     # descriptor: top-left origin + 8 alpha bits
    )
    body = bytearray()
    for px in buf:
        body += bytes((px[0], px[1], px[2], px[3]))
    with open(OUT, "wb") as f:
        f.write(header)
        f.write(body)
    print("wrote", os.path.relpath(OUT, os.path.join(HERE, "..")),
          "(%dx%d, %d bytes)" % (SIZE, SIZE, len(header) + len(body)))


if __name__ == "__main__":
    main()
