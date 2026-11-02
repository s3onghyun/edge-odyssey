#!/usr/bin/env python3
"""Character sheets for Odysseus in both styles (pixel, clean vector), as editable SVG.

Uses the same stamps and pose table as tools/make_odysseus.py, so the sheet always matches
the in-app art. Rasterise with tools/svg2png (see build notes in README).
Usage: python3 tools/make_character_sheet.py <out_dir>
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import make_odysseus as O  # noqa: E402
from make_sprites import canvas, rows_of, stamp  # noqa: E402

OUT = sys.argv[1] if len(sys.argv) > 1 else "."
INK, MUTED, BG, CARD = "#22263A", "#5F6680", "#EEF1F6", "#FFFFFF"
FONT = 'font-family="Avenir Next, Helvetica Neue, Helvetica, sans-serif"'


def text(x, y, s, size=14, weight=400, color=INK, anchor="start"):
    s = s.replace("&", "&amp;").replace("<", "&lt;")
    return f'<text x="{x}" y="{y}" {FONT} font-size="{size}" font-weight="{weight}" fill="{color}" text-anchor="{anchor}">{s}</text>'


def pix(rows, x, y, scale, silhouette=False, color="#22263A"):
    """Pixel grid -> crisp rects, merging horizontal runs."""
    out = [f'<g transform="translate({x} {y}) scale({scale})" shape-rendering="crispEdges">']
    for j, row in enumerate(rows):
        i = 0
        while i < len(row):
            k = row[i]
            if k == ".":
                i += 1
                continue
            n = 1
            while i + n < len(row) and (row[i + n] != "." if silhouette else row[i + n] == k):
                n += 1
            fill = color if silhouette else O.HEX[k]
            out.append(f'<rect x="{i}" y="{j}" width="{n}" height="1" fill="{fill}"/>')
            i += n
    out.append("</g>")
    return "".join(out)


def vec(els, x, y, scale, view_box=None):
    body = O.svg_frame(els)
    body = re.sub(r"^<svg[^>]*>", "", body.strip())[: -len("</svg>")]
    return f'<g transform="translate({x} {y}) scale({scale})">{body}</g>'


def grid(fn_rows):
    c = canvas(13, 17)
    fn_rows(c)
    return rows_of(c)


def turnaround_pixel(view):
    def draw(c):
        hx = 6
        if view == "side":
            stamp(c, O.CREST["up"] + O.HELMET + O.HEADS["normal"] + [O.BEARD_TIP], hx - 4, 0)
            stamp(c, ["occco", "occco", "oCcCo", ".ooo."], hx - 2, 9)
            for p in [(hx - 1, 13), (hx + 1, 13), (hx - 1, 14), (hx + 1, 14)]:
                c[p[1]][p[0]] = "S"
            c[15][hx - 1] = c[15][hx + 1] = "o"
            c[10][hx + 2] = c[11][hx + 3] = "s"
        else:
            face = O.FRONT_FACE["normal"] if view == "front" else O.BACK_HEAD
            stamp(c, O.FRONT_CREST + O.HELMET + face + [O.BEARD_TIP], hx - 4, 0)
            stamp(c, O.BODY_FRONT if view == "front" else O.BODY_BACK, hx - 3, 9)
    return grid(draw)


def turnaround_vector(view, x, y, s):
    cx = 6.5
    if view == "side":
        els = [O.legs(6, 13, 0), O.torso(6, 9), O.head(6, 5, "normal"), O.limb((8, 10), (9, 12))]
        return vec(els, x, y, s)
    return (f'<g transform="translate({x} {y}) scale({s})">{O.body_view_svg(cx, 9.3, view)}'
            f'<g transform="translate({cx} 4.9) scale(1.3) translate({-cx} -5.5)">'
            f'{O.head_view_svg(cx, 5.5, view, "normal")}</g></g>')


EXPRESSIONS = [("normal", "steady"), ("squint", "scanning for Ithaca"), ("effort", "hauling"), ("joy", "home in sight"),
               ("enchanted", "the Sirens' song"), ("worried", "Poseidon is angry"), ("sleep", "asleep")]
POSES = [
    ("Rows along the bottom", O.row_frame(1)),
    ("Hand to brow: where is Ithaca?", O.idle_frame("look")),
    ("Bails water (idle habit)", O.idle_frame("bail3")),
    ("Ropes up the right cliff", O.climb_frame(1)),
    ("Hugs the mast in the wind", O.cling_frame(1)),
    ("Tied to the mast: Sirens = agent needs you", O.sirens_frame(1)),
    ("Rides the waterfall down", O.slide_frame(0)),
    ("Poseidon's storm = near usage limit", O.storm_frame(2)),
]


def sheet(style):
    W, H = 1240, 1480
    o = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">',
         f'<rect width="{W}" height="{H}" fill="{BG}"/>']
    label = "pixel art" if style == "pixel" else "clean vector"
    o.append(text(48, 66, "Odysseus", 40, 700))
    o.append(text(48, 96, f"Character sheet, {label} style. Draft for the design meeting - not final.", 16, 400, MUTED))

    # turnaround
    o.append(text(48, 150, "Turnaround", 20, 600))
    for i, view in enumerate(("front", "side", "back")):
        x = 56 + i * 150
        if style == "pixel":
            o.append(pix(turnaround_pixel(view), x, 176, 8))
        else:
            o.append(turnaround_vector(view, x, 196, 7.4))
        o.append(text(x + 52, 336, view, 13, 500, MUTED, "middle"))

    # personality card
    cx, cy = 560, 130
    o.append(f'<rect x="{cx}" y="{cy}" width="632" height="220" rx="14" fill="{CARD}"/>')
    o.append(text(cx + 24, cy + 38, "Personality", 20, 600))
    traits = [
        ("Watchful", "always scanning the horizon for Ithaca, hand to brow"),
        ("Stubborn", "ropes up cliffs, bails water, never lets go of the oar"),
        ("Homesick", "every lap ends at home: Penelope, and old Argos wagging"),
    ]
    for i, (t, d) in enumerate(traits):
        o.append(text(cx + 24, cy + 76 + i * 30, t, 15, 600))
        o.append(text(cx + 120, cy + 76 + i * 30, d, 14, 400, MUTED))
    o.append(text(cx + 24, cy + 178, "“One more wave, then home.”", 18, 600, "#B23A30"))
    o.append(text(cx + 24, cy + 202, "“한 파도만 더, 그다음은 집이다.”", 15, 400, MUTED))

    # expressions
    o.append(text(48, 400, "Expressions", 20, 600))
    for i, (ex, note) in enumerate(EXPRESSIONS):
        x = 56 + i * 166
        if style == "pixel":
            rows = O.CREST["up"] + O.HELMET + O.HEADS[ex] + [O.BEARD_TIP]
            o.append(pix(rows, x + 14, 420, 12))
        else:
            o.append(vec([O.head(4, 5, ex)], x + 28, 448, 9))
        o.append(text(x + 68, 552, ex, 13, 600, INK, "middle"))
        o.append(text(x + 68, 570, note, 12, 400, MUTED, "middle"))

    # key poses
    o.append(text(48, 626, "Key poses and habits", 20, 600))
    for i, (cap, els) in enumerate(POSES):
        col, row = i % 4, i // 4
        x, y = 48 + col * 292, 646 + row * 220
        o.append(f'<rect x="{x}" y="{y}" width="276" height="200" rx="12" fill="{CARD}"/>')
        if style == "pixel":
            o.append(pix(O.draw_pixel(els), x + 42, y + 14, 6))
        else:
            o.append(vec(els, x + 42, y + 14, 6))
        o.append(text(x + 138, y + 188, cap, 12, 500, MUTED, "middle"))

    # palette
    py = 1110
    o.append(text(48, py, "Palette (one strong accent: crest and sail red)", 20, 600))
    keys = ["o", "s", "P", "b", "h", "H", "r", "R", "c", "w", "W", "n", "m", "f", "t", "k"]
    for i, k in enumerate(keys):
        x = 48 + (i % 8) * 140
        y = py + 22 + (i // 8) * 52
        name = next(n for kk, v, n in O.PALETTE if kk == k)
        o.append(f'<rect x="{x}" y="{y}" width="30" height="30" rx="6" fill="{O.HEX[k]}" stroke="#0002"/>')
        o.append(text(x + 38, y + 14, O.HEX[k], 12, 600))
        o.append(text(x + 38, y + 29, name.split(":")[0].split("/")[0][:22], 11, 400, MUTED))

    # silhouette test at actual size
    sy = 1270
    o.append(text(48, sy, "Silhouette and real size", 20, 600))
    picks = [O.row_frame(1), O.climb_frame(1), O.cling_frame(1), O.sirens_frame(1), O.rest_frame(1)]
    for i, els in enumerate(picks):
        x = 56 + i * 110
        rows = O.draw_pixel(els)
        o.append(pix(rows, x, sy + 20, 3, silhouette=True))
        if style == "pixel":
            o.append(pix(rows, x + 4, sy + 110, 1))
            o.append(f'<rect x="{x + 44}" y="{sy + 104}" width="40" height="34" rx="4" fill="#20222E"/>')
            o.append(pix(rows, x + 48, sy + 108, 1))
        else:
            o.append(vec(els, x + 4, sy + 110, 1))
            o.append(f'<rect x="{x + 44}" y="{sy + 104}" width="40" height="34" rx="4" fill="#20222E"/>')
            o.append(vec(els, x + 48, sy + 108, 1))
    o.append(text(48, sy + 168, "Top: silhouettes at 3x. Bottom: 1 pt per sprite pixel, as on screen, on light and dark.", 12, 400, MUTED))

    # principles
    px0 = 680
    o.append(text(px0, sy, "Charm rules applied", 20, 600))
    rules = [
        "Big readable head, about half the body (Kirby, Tamagotchi)",
        "One accent colour that reads at 1 pt: the red crest and sail",
        "A habit for every idle moment: scanning, bailing (Rusty's Retirement)",
        "Motion tells the state before colour does (RunCat)",
        "Gentle, never guilt-tripping: he waits, he never nags (Finch)",
        "Squash on landing, lean before a pull: anticipation reads small",
    ]
    for i, r in enumerate(rules):
        o.append(text(px0, sy + 30 + i * 22, "• " + r, 13, 400, MUTED))
    o.append("</svg>")
    path = os.path.join(OUT, f"odysseus-{style}-sheet.svg")
    with open(path, "w") as f:
        f.write("".join(o))
    return path


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for st in ("pixel", "vector"):
        print(sheet(st))
