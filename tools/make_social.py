#!/usr/bin/env python3
"""Builds the GitHub social preview card: the screen edge, the trail so far, Odysseus hanging there.

    python3 tools/make_social.py      # needs rsvg-convert (brew install librsvg)

Writes docs/social-preview.svg (editable source) and docs/social-preview.png (1280x640, the size
GitHub asks for; upload it in the repository's Settings > General > Social preview). Text stays
40 px clear of the border, where some sites crop. Colours are the app's Tones (light).
"""
import os, re, subprocess

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
FRAME = os.path.join(ROOT, "assets/characters/odysseus-vector/cling-1.svg")
OUT = os.path.join(ROOT, "docs")
W, H = 1280, 640
PAPER, FACE, INK, MUTED, TEAL, BRASS = "#F3F0E8", "#E9E5DC", "#18222F", "#56606E", "#4A807C", "#977542"
FONT = "'.SF NS Rounded', 'SF Pro Rounded', 'Helvetica Neue', sans-serif"   # macOS system rounded face

INSET, R = 28, 36                      # the "screen edge": a rounded rectangle just inside the card
X0, Y0, X1, Y1 = INSET, INSET, W - INSET, H - INSET
HANG_X = 860                            # where Odysseus hangs on the top edge


def edge_path():
    """Traced the way the traveler goes: bottom left->right, up the right, right->left along the top."""
    return (f"M{X0 + R} {Y1} L{X1 - R} {Y1} A{R} {R} 0 0 0 {X1} {Y1 - R} L{X1} {Y0 + R} "
            f"A{R} {R} 0 0 0 {X1 - R} {Y0} L{X0 + R} {Y0} A{R} {R} 0 0 0 {X0} {Y0 + R} "
            f"L{X0} {Y1 - R} A{R} {R} 0 0 0 {X0 + R} {Y1} Z")


def svg():
    import math
    inner = re.sub(r"^<svg[^>]*>|</svg>\s*$", "", open(FRAME).read().strip())
    arc = math.pi * R / 2
    total = 2 * (X1 - X0 - 2 * R) + 2 * (Y1 - Y0 - 2 * R) + 4 * arc
    done = (X1 - X0 - 2 * R) + arc + (Y1 - Y0 - 2 * R) + arc + (X1 - R - HANG_X)   # trail ends at him
    k = 5.0                                # sprite units -> px (32x26 -> 160x130)
    # the edge turns the top-edge sprite 180 degrees and its SVG is drawn pre-turned; undo that, branch on the edge
    fig = f'<g transform="translate({HANG_X - 16 * k} {Y0 - 1.6 * k}) scale({k}) rotate(180 16 13)">{inner}</g>'
    trail = edge_path()
    return f"""<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">
<defs>
  <linearGradient id="bg" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="{PAPER}"/><stop offset="1" stop-color="{FACE}"/></linearGradient>
</defs>
<rect width="{W}" height="{H}" fill="url(#bg)"/>
<path d="{trail}" fill="none" stroke="{INK}" stroke-opacity="0.10" stroke-width="8"/>
<path d="{trail}" fill="none" stroke="{TEAL}" stroke-opacity="0.25" stroke-width="22" stroke-dasharray="{done:.1f} {total:.1f}" stroke-linecap="round"/>
<path d="{trail}" fill="none" stroke="{TEAL}" stroke-width="8" stroke-dasharray="{done:.1f} {total:.1f}" stroke-linecap="round"/>
{fig}
<circle cx="{X0 + 6}" cy="{Y1 - 6}" r="10" fill="{BRASS}"/>
<text x="104" y="300" font-family="{FONT}" font-size="104" font-weight="700" fill="{INK}" letter-spacing="-2">Edge Odyssey</text>
<text x="108" y="372" font-family="{FONT}" font-size="40" font-weight="500" fill="{MUTED}">A pomodoro that lives on your screen edge</text>
<text x="108" y="452" font-family="{FONT}" font-size="28" font-weight="600" fill="{TEAL}" letter-spacing="1">macOS  ·  open source  ·  no telemetry</text>
</svg>
"""


def main():
    os.makedirs(OUT, exist_ok=True)
    src = os.path.join(OUT, "social-preview.svg")
    open(src, "w").write(svg())
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), src, "-o", os.path.join(OUT, "social-preview.png")], check=True)
    print("wrote", src, "and social-preview.png")


if __name__ == "__main__":
    main()
