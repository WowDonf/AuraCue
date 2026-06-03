#!/usr/bin/env python3
"""Generate AuraCue's addon icon with Pillow.

Draws a "pulse" motif — a glowing dot with two emanating rings — in the
addon's teal on a dark rounded square, at 4x supersample then downscaled
with LANCZOS for clean antialiased edges. Writes ../Icon.png (retail WoW
loads PNG textures for IconTexture, matching CombatReticle / OutOfRange).

Re-run:  python3 tools/make_icon.py
"""

import os

from PIL import Image, ImageDraw, ImageFilter

SIZE = 128            # final icon size
SS = 4                # supersample factor
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "Icon.png"))

BG = (18, 28, 30, 235)         # dark slate
BORDER = (51, 219, 187, 90)    # faint teal rim
TEAL = (51, 219, 187, 255)     # accent #33ddbb


def main():
    s = SIZE * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    pad = 6 * SS
    radius = 26 * SS
    # Rounded-square background + faint rim.
    d.rounded_rectangle([pad, pad, s - pad, s - pad], radius=radius, fill=BG)
    d.rounded_rectangle([pad, pad, s - pad, s - pad], radius=radius,
                        outline=BORDER, width=2 * SS)

    cx = cy = s / 2.0

    # Two emanating rings, fainter outward.
    for r, alpha, w in ((30 * SS, 200, 5 * SS), (46 * SS, 110, 4 * SS)):
        d.ellipse([cx - r, cy - r, cx + r, cy + r],
                  outline=(TEAL[0], TEAL[1], TEAL[2], alpha), width=w)

    # Center dot.
    dot = 13 * SS
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=TEAL)

    # Soft glow: a blurred copy of the teal elements under the crisp ones.
    glow = img.filter(ImageFilter.GaussianBlur(3 * SS))
    out = Image.alpha_composite(glow, img)

    out = out.resize((SIZE, SIZE), Image.LANCZOS)
    out.save(OUT)
    print("wrote", os.path.relpath(OUT, os.path.join(HERE, "..")),
          "(%dx%d)" % (SIZE, SIZE))


if __name__ == "__main__":
    main()
