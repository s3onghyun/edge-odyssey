#!/usr/bin/env python3
"""Builds the app icon: Odysseus under sail at dawn, framed by the glowing screen-edge trail.

    python3 tools/make_icon.py      # needs rsvg-convert (brew install librsvg) and iconutil

Writes assets/icon/AppIcon.svg (editable source) and assets/icon/AppIcon.icns (used by
build.sh). The figure is the default character's own walk frame, so the icon stays on-model.
"""
import math, os, re, subprocess, tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAME = os.path.join(ROOT, "assets/characters/odysseus-vector/walk-1.svg")
OUT = os.path.join(ROOT, "assets/icon")

# macOS icon grid: 1024 canvas, 824 body, corner radius ~185.
X0, Y0, S, RAD = 100, 100, 824, 185
SEA, SEA_LIGHT, TEAL, CORAL = "#3B1E3F", "#6E2F5E", "#4FD1C5", "#FF8A66"


def edge_path(inset, r):
    """Rounded square traced the way the traveler goes: bottom left->right, then up, left, down."""
    x0, y0, x1, y1 = X0 + inset, Y0 + inset, X0 + S - inset, Y0 + S - inset
    return (f"M{x0 + r} {y1} L{x1 - r} {y1} A{r} {r} 0 0 0 {x1} {y1 - r} L{x1} {y0 + r} "
            f"A{r} {r} 0 0 0 {x1 - r} {y0} L{x0 + r} {y0} A{r} {r} 0 0 0 {x0} {y0 + r} "
            f"L{x0} {y1 - r} A{r} {r} 0 0 0 {x0 + r} {y1} Z")


def svg():
    frame = open(FRAME).read()
    inner = re.sub(r"^<svg[^>]*>|</svg>\s*$", "", frame.strip())
    k = 20.0                                  # sprite units -> icon px (32x26 -> 640x520)
    sea_top = Y0 + S * 0.80
    fx, fy = 512 - 16 * k, sea_top - 22.6 * k  # the sprite's own sea meets the icon's sea
    inset, r = 46, 150
    trail = edge_path(inset, r)
    side = S - 2 * inset
    total = 4 * (side - 2 * r) + 2 * math.pi * r   # rsvg ignores pathLength, so dash in px
    done, tip = 0.64 * total, 0.035 * total
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="1024" height="1024" viewBox="0 0 1024 1024">
<defs>
  <clipPath id="body"><rect x="{X0}" y="{Y0}" width="{S}" height="{S}" rx="{RAD}"/></clipPath>
  <linearGradient id="sky" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#FFE7B8"/><stop offset="0.55" stop-color="#FFC48C"/><stop offset="1" stop-color="#F59A7A"/>
  </linearGradient>
</defs>
<g clip-path="url(#body)">
  <rect x="{X0}" y="{Y0}" width="{S}" height="{S}" fill="url(#sky)"/>
  <circle cx="{X0 + S * 0.73}" cy="{Y0 + S * 0.36}" r="92" fill="#FFF3D6" opacity="0.9"/>
  <rect x="{X0}" y="{sea_top + 6}" width="{S}" height="{S}" fill="{SEA}"/>
  <g transform="translate({fx} {fy}) scale({k})">{inner}</g>
  <path d="{trail}" fill="none" stroke="#FFFFFF" stroke-opacity="0.28" stroke-width="16"/>
  <path d="{trail}" fill="none" stroke="{TEAL}" stroke-opacity="0.35" stroke-width="34" stroke-dasharray="{done:.1f} {total:.1f}" stroke-linecap="round"/>
  <path d="{trail}" fill="none" stroke="{TEAL}" stroke-width="16" stroke-dasharray="{done:.1f} {total:.1f}" stroke-linecap="round"/>
  <path d="{trail}" fill="none" stroke="{CORAL}" stroke-width="16" stroke-dasharray="{tip:.1f} {total:.1f}" stroke-dashoffset="{tip - done:.1f}" stroke-linecap="round"/>
</g>
</svg>
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    src = os.path.join(OUT, "AppIcon.svg")
    open(src, "w").write(svg())
    with tempfile.TemporaryDirectory() as tmp:
        iconset = os.path.join(tmp, "AppIcon.iconset")
        os.makedirs(iconset)
        for size in (16, 32, 128, 256, 512):
            for scale in (1, 2):
                px = size * scale
                name = f"icon_{size}x{size}{'@2x' if scale == 2 else ''}.png"
                subprocess.run(["rsvg-convert", "-w", str(px), "-h", str(px), src, "-o", os.path.join(iconset, name)], check=True)
        subprocess.run(["iconutil", "-c", "icns", iconset, "-o", os.path.join(OUT, "AppIcon.icns")], check=True)
    subprocess.run(["rsvg-convert", "-w", "256", src, "-o", os.path.join(OUT, "AppIcon-256.png")], check=True)
    print("wrote", src, "and AppIcon.icns")


if __name__ == "__main__":
    main()
