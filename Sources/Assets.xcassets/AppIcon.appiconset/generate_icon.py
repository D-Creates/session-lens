#!/usr/bin/env python3
"""Generate the SessionLens app icon: 1024x1024 PNG, iOS-27 style.

Rounded-square tile with a diagonal gradient and a white "lens over a
timeline" glyph: three horizontal bars (the timeline) seen through a
magnifier ring (the lens). Original artwork for SessionLens.
Rendered at 4x and downscaled for smooth edges. Requires Pillow.

Usage: python3 generate_icon.py [output.png]
"""
import math
import sys

from PIL import Image, ImageDraw, ImageFilter

SIZE = 1024
SS = 4
S = SIZE * SS

# Original palette: deep indigo -> blue -> cyan diagonal gradient.
STOPS = [
    (0.0, (64, 72, 200)),    # top-left indigo
    (0.55, (52, 120, 235)),  # blue
    (1.0, (34, 190, 220)),   # cyan bottom-right
]


def gradient(size):
    img = Image.new("RGB", (size, size))
    px = img.load()
    x1, y1 = size - 1, size - 1
    length = x1 * x1 + y1 * y1
    for y in range(size):
        for x in range(size):
            t = (x * x1 + y * y1) / length
            t = max(0.0, min(1.0, t))
            for i in range(len(STOPS) - 1):
                t0, c0 = STOPS[i]
                t1, c1 = STOPS[i + 1]
                if t0 <= t <= t1:
                    f = 0.0 if t1 == t0 else (t - t0) / (t1 - t0)
                    px[x, y] = tuple(round(c0[k] + (c1[k] - c0[k]) * f) for k in range(3))
                    break
            else:
                px[x, y] = STOPS[-1][1]
    return img


def rounded_mask(size, radius):
    mask = Image.new("L", (size, size), 0)
    d = ImageDraw.Draw(mask)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return mask


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else "AppIcon-1024.png"
    img = gradient(S)
    d = ImageDraw.Draw(img)

    cx, cy = S * 0.50, S * 0.46      # lens center
    ring_r = S * 0.30                # lens ring radius
    ring_w = S * 0.075               # ring thickness

    # Timeline bars behind the lens (three rounded bars).
    bar_x0 = S * 0.22
    bar_x1 = S * 0.78
    for i, y in enumerate([S * 0.34, S * 0.46, S * 0.58]):
        h = S * 0.055
        d.rounded_rectangle([bar_x0, y - h / 2, bar_x1, y + h / 2],
                            radius=h / 2, fill=(255, 255, 255, 235))

    # Lens ring (white, thick).
    d.ellipse([cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r],
              outline=(255, 255, 255), width=int(ring_w))

    # Handle of the magnifier.
    hx0, hy0 = cx + ring_r * 0.72, cy + ring_r * 0.72
    hx1, hy1 = S * 0.86, S * 0.86
    d.line([hx0, hy0, hx1, hy1], fill=(255, 255, 255), width=int(ring_w * 0.9))
    d.ellipse([hx1 - ring_w * 0.45, hy1 - ring_w * 0.45,
               hx1 + ring_w * 0.45, hy1 + ring_w * 0.45], fill=(255, 255, 255))

    # Soft inner glow: subtle highlight top-left.
    glow = Image.new("L", (S, S), 0)
    gd = ImageDraw.Draw(glow)
    gd.ellipse([S * 0.05, S * 0.02, S * 0.75, S * 0.55], fill=60)
    glow = glow.filter(ImageFilter.GaussianBlur(S * 0.06))
    white = Image.new("RGB", (S, S), (255, 255, 255))
    img = Image.composite(white, img, glow.point(lambda p: p // 3))

    # Rounded-square mask (iOS-style continuous corner ~ 22.5%).
    mask = rounded_mask(S, int(S * 0.225))
    img.putalpha(mask)

    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.convert("RGB").save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
