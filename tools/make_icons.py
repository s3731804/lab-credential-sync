#!/usr/bin/env python3
"""
Draws the extension icon (a key on a rounded square) and writes it at
every size the manifests and store listings use, into extension/icons/.

    python3 tools/make_icons.py

Needs Pillow. Drawn large and scaled down so the edges stay smooth.
"""
import os
from PIL import Image, ImageDraw

SIZES = [16, 32, 48, 128]
CANVAS = 1024
BACKGROUND = "#232f3e"  # same navy as the popup heading
KEY = "#f2c14e"

OUT_DIR = os.path.join(os.path.dirname(__file__), "..", "extension", "icons")


def draw_key():
    # Drawn horizontally (ring on the left, teeth pointing down), then
    # rotated so it sits on the diagonal.
    layer = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)
    cy = CANVAS // 2

    ring_x, ring_r, hole_r = 330, 190, 82
    d.ellipse([ring_x - ring_r, cy - ring_r, ring_x + ring_r, cy + ring_r], fill=KEY)

    shaft_half = 56
    d.rectangle([ring_x + ring_r - 40, cy - shaft_half, 860, cy + shaft_half], fill=KEY)
    d.rounded_rectangle([800, cy - shaft_half, 880, cy + shaft_half], radius=24, fill=KEY)

    for x0, x1, depth in [(690, 760, 130), (800, 880, 100)]:
        d.rectangle([x0, cy, x1, cy + shaft_half + depth], fill=KEY)

    d.ellipse([ring_x - hole_r, cy - hole_r, ring_x + hole_r, cy + hole_r], fill=(0, 0, 0, 0))
    return layer.rotate(-45, resample=Image.BICUBIC, center=(CANVAS // 2, CANVAS // 2))


def main():
    icon = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    ImageDraw.Draw(icon).rounded_rectangle(
        [0, 0, CANVAS - 1, CANVAS - 1], radius=200, fill=BACKGROUND
    )
    icon.alpha_composite(draw_key())

    os.makedirs(OUT_DIR, exist_ok=True)
    for size in SIZES:
        path = os.path.join(OUT_DIR, f"icon-{size}.png")
        icon.resize((size, size), Image.LANCZOS).save(path, optimize=True)
        print(f"Wrote {os.path.normpath(path)}")


if __name__ == "__main__":
    main()
