#!/usr/bin/env python3
"""Generate AuraCue's addon icon and the marketing icon set with Pillow.

Draws a "pulse" motif — a glowing dot with two emanating rings — in the
addon's teal on a dark rounded square. Rendered at 4x supersample then
downscaled with LANCZOS for clean antialiased edges. Writes:

  - Icon.png             the in-game icon at the repo root (128 px); the TOC
                         `## IconTexture: Interface\\AddOns\\AuraCue\\Icon.png`
                         picks this up at runtime.
  - assets/Icon-64.png   reference / archival
  - assets/Icon-128.png  documentation embeds
  - assets/Icon-256.png  CurseForge / Wago listing avatar

The whole design is authored against a 128 px reference grid and scaled by
ratio, so every size is the same image. `assets/` is excluded from the
packaged zip (see .pkgmeta); only the root Icon.png ships.

Re-run:  python3 tools/make_icon.py
"""

import os
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

SS = 4                          # supersample factor
REPO_ROOT = Path(__file__).resolve().parent.parent
ASSETS_DIR = REPO_ROOT / "assets"
ASSETS_DIR.mkdir(exist_ok=True)

BG = (18, 28, 30, 235)          # dark slate
BORDER = (51, 219, 187, 90)     # faint teal rim
TEAL = (51, 219, 187, 255)      # accent #33ddbb


def create_icon(size):
    """Render the pulse icon at `size` px (square, RGBA)."""
    s = size * SS

    def px(v):                  # design authored on a 128 px grid
        return v / 128.0 * s

    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    pad, radius = px(6), px(26)
    # Rounded-square background + faint rim.
    d.rounded_rectangle([pad, pad, s - pad, s - pad], radius=radius, fill=BG)
    d.rounded_rectangle([pad, pad, s - pad, s - pad], radius=radius,
                        outline=BORDER, width=max(1, int(px(2))))

    cx = cy = s / 2.0

    # Two emanating rings, fainter outward.
    for r, alpha, w in ((px(30), 200, px(5)), (px(46), 110, px(4))):
        d.ellipse([cx - r, cy - r, cx + r, cy + r],
                  outline=(TEAL[0], TEAL[1], TEAL[2], alpha), width=max(1, int(w)))

    # Center dot.
    dot = px(13)
    d.ellipse([cx - dot, cy - dot, cx + dot, cy + dot], fill=TEAL)

    # Soft glow: a blurred copy of the teal elements under the crisp ones.
    glow = img.filter(ImageFilter.GaussianBlur(px(3)))
    out = Image.alpha_composite(glow, img)

    return out.resize((size, size), Image.LANCZOS)


def main():
    # Marketing icon set.
    for size in (64, 128, 256):
        out = ASSETS_DIR / f"Icon-{size}.png"
        create_icon(size).save(out, optimize=True)
        print("wrote", os.path.relpath(out, REPO_ROOT), "(%dx%d)" % (size, size))

    # In-game icon at the repo root (referenced by the TOC IconTexture).
    create_icon(128).save(REPO_ROOT / "Icon.png", optimize=True)
    print("wrote Icon.png (128x128, in-game)")


if __name__ == "__main__":
    main()
