#!/usr/bin/env python3
"""Odysseus - the traveler for the screen-edge journey (Homer's Odyssey, public domain).

One pose table drives two renderers so both style variants always share the same poses:
  * pixel  -> assets/characters/odysseus-pixel.sprite   (hand-placed stamps, 1 px lines)
  * vector -> assets/characters/odysseus-vector/        (clean SVG frames + anim manifest)

Every stamp and shape below was written by hand in this file. No image generation, no
third-party or film/game designs. Run:  python3 tools/make_odysseus.py
"""
import math
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from make_sprites import canvas, png, put, rows_of, stamp  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "assets")
W, H = 32, 26

PALETTE = [
    ("o", "#2A1F33", "outline"),
    ("s", "#F2C29B", "skin"),
    ("S", "#C98E6B", "skin shade"),
    ("b", "#5A3726", "beard"),
    ("h", "#E0AE4A", "bronze helmet"),
    ("H", "#A8742A", "bronze shade"),
    ("r", "#D8473B", "red: plume and sail"),
    ("R", "#9E2E2B", "red shade"),
    ("c", "#F4EAD2", "chiton"),
    ("C", "#C9B99A", "chiton shade"),
    ("w", "#8A5530", "wood"),
    ("W", "#4F2F1C", "dark wood / mast / rope"),
    ("n", "#3B1E3F", "wine-dark sea"),
    ("m", "#6E2F5E", "sea"),
    ("f", "#F3E6F2", "foam / wind"),
    ("y", "#F1D79A", "sand"),
    ("g", "#5DAA5E", "palm"),
    ("G", "#2F6B3C", "palm shade"),
    ("k", "#7C8299", "storm cloud"),
    ("K", "#4A4F66", "storm cloud shade / rock"),
    ("j", "#FFE36B", "lightning"),
    ("p", "#9CC3F0", "rain"),
    ("t", "#FFD36E", "siren song notes"),
    ("z", "#8A96FF", "sleep z"),
    ("P", "#F5A3B5", "blush, piglets, lotus"),
    ("Q", "#D9798F", "piglet shade"),
    ("e", "#A7B98A", "cyclops skin"),
    ("d", "#B07A4A", "dog"),
]
HEX = {k: v for k, v, _ in PALETTE}

# ----------------------------------------------------------------------- pose table
# A frame is a list of elements; renderers below know how to draw each element type.


def sea(phase, rough=False):
    return {"t": "sea", "phase": phase, "rough": rough}


def hull(x, y, tilt=0):
    return {"t": "hull", "x": x, "y": y, "tilt": tilt}


def mast(x, top, bottom, sail="A"):
    return {"t": "mast", "x": x, "top": top, "bottom": bottom, "sail": sail}


def head(cx, cy, expr="normal", plume="up"):
    return {"t": "head", "cx": cx, "cy": cy, "expr": expr, "plume": plume}


def torso(cx, top, rows=4, tied=False):
    return {"t": "torso", "cx": cx, "top": top, "rows": rows, "tied": tied}


def limb(a, b, kind="arm"):
    return {"t": "limb", "a": a, "b": b, "kind": kind}


def legs(cx, top, step):
    return {"t": "legs", "cx": cx, "top": top, "step": step}


def line(a, b, color="W", kind="rope"):
    return {"t": "line", "a": a, "b": b, "color": color, "kind": kind}


def dots(points, color):
    return {"t": "dots", "points": points, "color": color}


def note(x, y):
    return {"t": "note", "x": x, "y": y}


def zee(x, y, big):
    return {"t": "zee", "x": x, "y": y, "big": big}


def cloud(x, y, flash=False):
    return {"t": "cloud", "x": x, "y": y, "flash": flash}


def island():
    return {"t": "island"}


def rock():
    return {"t": "rock"}


def row_frame(phase):
    bob = [0, 1, 1, 0][phase]
    hands, blade = [((16, 15), (26, 23)), ((15, 16), (23, 24)), ((13, 17), (19, 24)), ((15, 14), (27, 20))][phase]
    hy = 11 + bob
    return [
        mast(19, 4 + bob, 18 + bob, sail="AB"[phase // 2]),
        torso(11, hy + 4),
        head(11, hy),
        limb((13, hy + 5), (hands[0], hands[1] + bob)),
        hull(7, 18 + bob),
        line((hands[0], hands[1] + bob), blade, "w", "oar"),
        sea(phase // 2),
    ]


def idle_frame(kind):
    # standing in the boat: scan the horizon for Ithaca, then bail water
    els = [mast(21, 4, 18, sail="A"), legs(11, 15, 0), torso(11, 11)]
    if kind in ("look", "look2"):
        hy = 7 if kind == "look" else 6
        els += [head(11, hy, "squint"), limb((13, 12), (15, hy - 1)), dots([(15, hy - 1), (16, hy - 1)], "s")]
    elif kind == "bail1":
        els += [head(12, 8), limb((13, 12), (15, 16)), dots([(14, 17), (15, 17), (16, 17)], "W")]
    elif kind == "bail2":
        els += [head(11, 7), limb((13, 12), (16, 10)), dots([(16, 9), (17, 9), (18, 9)], "W"), dots([(19, 8)], "f")]
    elif kind == "bail3":
        els += [head(11, 7, "normal"), limb((13, 12), (16, 11)), dots([(16, 10), (17, 11)], "W"),
                dots([(20, 7), (22, 6), (21, 9), (24, 8)], "f")]
    els += [hull(5, 18), sea(0 if kind in ("look", "bail1") else 1)]
    return els


def climb_frame(step):
    # hauling the boat up the cliff by rope (the app rotates this onto the right edge)
    bob = step % 2
    hx = 19
    return [
        rock(),
        hull(-1, 18, tilt=1),
        line((17, 14 - bob), (16, 18), "W"),          # tow line back to the bow
        line((22 + step % 2, 11 - bob), (31, 22), "W"),  # climbing rope ahead, anchored on the cliff
        legs(hx, 15 - bob, step),
        torso(hx, 11 - bob),
        head(hx, 7 - bob, "effort"),
        limb((hx + 2, 12 - bob), (22 + step % 2, 11 - bob)),
    ]


def cling_frame(k):
    # Book 12: above Charybdis he clings to the fig tree "like a bat", hand over hand.
    # Drawn upright hanging from a branch, then flipped: the app turns it onto the top edge.
    cx = 15 + (k == 1)
    hands = [((cx - 3, 3), (cx + 3, 3)), ((cx - 2, 3), (cx + 5, 2)), ((cx - 5, 2), (cx + 2, 3))][k]
    return [
        el("figbranch", phase=k),
        legs(cx, 19, k), torso(cx, 15), head(cx, 11, "effort"),
        limb((cx - 2, 15), hands[0]), limb((cx + 2, 15), hands[1]),
        dots([hands[0], hands[1]], "s"),
        el("flip"),
    ]


def zip_frame(k):
    # Top edge, alternate laps: a zipline - a pulley on a line, legs kicking, trailing back.
    cx = 15
    return [
        line((0, 1), (31, 1), "W", "rope"),
        el("pulley", x=cx, y=2),
        line((cx - 3, 5), (cx + 3, 5), "W", "oar"),
        el("kick", x=cx + 1, y=19, k=k),
        torso(cx + 1, 14), head(cx + 1, 10, "joy"),
        limb((cx - 1, 14), (cx - 2, 5)), limb((cx + 3, 14), (cx + 2, 5)),
        line((23, 9 + k % 2), (28, 9 + k % 2), "f", "wind"), line((25, 14), (30, 14), "f", "wind"),
        el("flip"),
    ]


def climb_var_frame(k, variant):
    # Right edge variants (rotated by the app): Circe's crag lookout (Book 10), the olive
    # tree of the marriage bed (Book 23), the mast as a lookout for Ithaca.
    look = variant == "crag" and k == 3
    bob = k % 2
    hx = 14
    els = [el(variant, phase=k)]
    els += [legs(hx, 16 - bob, k), torso(hx, 12 - bob), head(hx, 8 - bob, "squint" if look else "effort")]
    if look:
        els += [limb((hx + 2, 13), (hx + 4, 7)), dots([(hx + 4, 6), (hx + 5, 6)], "s"), el("smoke", x=24, y=2, phase=k)]
    else:
        reach = [(hx + 6, 21), (hx + 4, 21), (hx + 7, 21)][k % 3]
        els += [limb((hx + 2, 13 - bob), reach), limb((hx, 13 - bob), (hx + 2, 21)), dots([reach], "s")]
    return els


def ram_frame(k):
    # Book 9: out of the Cyclops' cave clinging under the belly of a woolly ram.
    return [
        el("ground"),
        el("ram", x=4, y=6, step=k),
        head(15, 17 + (k % 2), "squint"),
        dots([(11, 15), (20, 15)], "s"),
    ]


def slide_frame(k):
    return [
        sea(k, rough=True),
        torso(15, 15, rows=2),
        head(15, 12 - k, "joy", plume="wind"),
        limb((13, 15), (11, 9 - k)), limb((17, 15), (19, 9 - k)),
        hull(7, 18, tilt=-1),
        line((1, 9 + k), (5, 9 + k), "f", "wind"), line((0, 13), (4, 13), "f", "wind"),
        line((2, 17 - k), (6, 17 - k), "f", "wind"),
        dots([(27, 17 - k), (28, 15 - k), (29, 18)], "f"),
    ]


def sirens_frame(k):
    lean = 1 if k == 1 else 0
    notes = [note(24 + k, 9 - 3 * k), note(28, 5 - k)] if k < 2 else [note(25, 6), note(28, 1)]
    return [
        mast(18, 0, 18, sail="furl"),
        legs(17, 15, 0),
        torso(17, 11, tied=True),
        head(17 + lean, 7, "enchanted"),
        hull(6, 18),
        sea(k % 2),
    ] + notes


def storm_frame(k):
    # Book 5: shipwrecked by Poseidon, he rides the capsized keel "as one rides a horse".
    bob = [0, 1, 0, -1][k]
    return [
        cloud(5, 0, flash=k == 2),
        dots([(8 + k % 2, 6), (13 + k % 2, 7), (18 + k % 2, 6), (23 + k % 2, 7), (10, 9 + k % 2), (21, 9 + k % 2)], "p"),
        line((6, 19 + bob), (27, 15 + bob), "W", "oar"),
        legs(16, 17 + bob, 1), torso(16, 13 + bob),
        head(16, 9 + bob, "worried", plume="wind"),
        limb((14, 14 + bob), (12, 18 + bob)), limb((18, 14 + bob), (20, 17 + bob)),
        dict(hull(7, 19 + bob, tilt=0), capsized=True),
        sea(k % 2, rough=True),
    ]


def rest_frame(k):
    return [
        sea(k),
        island(),
        hull(-4, 19, tilt=1),
        {"t": "sleeper", "x": 13, "y": 16},
        zee(25 - k, 6 - 2 * k, big=k == 1),
    ]


def el(t, **kw):
    kw["t"] = t
    return kw


def cyclops_frame(k):
    # Book 9: a single giant eye rises over the horizon, blinks, hurls a boulder - splash.
    rise = [0, 1, 2, 2, 2, 2, 2, 1][k]
    els = [el("eye", x=18, rise=rise, blink=k == 3)]
    if k == 4:
        els.append(el("boulder", x=15, y=6))
    if k == 5:
        els.append(el("boulder", x=7, y=9))
    els.append(sea(k % 2))
    if k == 6:
        els.append(el("splash", x=2, y=17, big=True))
    if k == 7:
        els.append(el("splash", x=2, y=19, big=False))
    return els


def bag_frame(k):
    # Book 10: Aeolus' bag of winds bursts - a gust shoves the boat along the ceiling.
    els = [el("bag", x=3, y=9 - (k == 1), open=k >= 2)]
    if k >= 2:
        n = 3 if k == 2 else 5
        for i in range(n):
            y = 8 + i * 3
            els.append(line((9 + (k - 2) * 3, y), (16 + (k - 2) * 6, y - 1 + i % 2), "f", "wind"))
    return els


def whirl_frame(k):
    # Book 12: Charybdis swallows the sea at the corner and spins him round.
    return [sea(0, rough=True), el("whirl", cx=16, cy=22, phase=k)]


def piglet_frame(k):
    # Book 10: Circe's piglets (the crew) trot after the boat for a while.
    return [el("pig", x=2 + (k % 2), y=19, step=k), el("pig", x=11, y=19 - (k % 2), step=k + 1),
            el("pig", x=20 + (k % 2), y=19, step=k)]


def owl_frame(k):
    # Book 1: Athena's owl flies ahead in the last minutes, guiding him home.
    return [el("owl", x=12, y=8 + (k % 2), up=k % 2 == 0), dots([(21, 6 + k % 2)], "j")]


def ithaca_frame(k):
    # Books 13-19: home. Penelope at the loom; old Argos lifts his head and wags.
    return [
        el("ground"),
        hull(-8, 18, tilt=0),
        legs(9, 18, 0), torso(9, 14), head(9, 10, "joy"),
        el("dog", x=12, y=19, wag=k % 2),
        el("loom", x=25, y=8, shuttle=k % 3),
        el("penelope", x=22, y=9, turn=k == 2),
    ]


def doze_frame(k):
    # Book 9: the Lotus-eaters - a distracting app is in front, so he nods off at the oar.
    return [
        mast(19, 4, 18, sail="A"),
        torso(11, 15),
        head(11, 12, "sleep"),
        hull(7, 18),
        el("lotus", x=26, y=21 - (k % 2)),
        sea(k % 2),
        zee(15 + k, 5 - k, big=k == 1),
    ]


ANIMS = [
    ("walk", 5, [row_frame(i) for i in range(4)]),             # bottom edge: rowing
    ("idle", 2.5, [idle_frame(k) for k in ("look", "look2", "look", "look2", "bail1", "bail2", "bail3", "bail1")]),
    ("climb", 4, [climb_frame(i) for i in range(4)]),           # right edge: rope up the cliff
    ("cling", 4, [cling_frame(i) for i in range(3)]),           # top edge: wind, hugging the mast
    ("slide", 8, [slide_frame(i) for i in range(2)]),           # left edge: down the waterfall
    ("sirens", 3, [sirens_frame(i) for i in range(3)]),         # agent waiting: tied to the mast, listening
    ("storm", 4, [storm_frame(i) for i in range(4)]),           # near usage limit: Poseidon's storm
    ("rest", 1.5, [rest_frame(i) for i in range(2)]),           # long break: Calypso's island
    ("ram", 6, [ram_frame(i) for i in range(4)]),
    ("zip", 6, [zip_frame(i) for i in range(3)]),               # top edge, alternate laps: zipline
    ("climb-crag", 3, [climb_var_frame(i, "crag") for i in range(4)]),
    ("climb-olive", 3, [climb_var_frame(i, "olive") for i in range(3)]),
    ("climb-mast", 3, [climb_var_frame(i, "maststrip") for i in range(3)]),               # episode: under the ram (Book 9)
    ("ithaca", 2, [ithaca_frame(i) for i in range(3)]),         # short break: home on Ithaca
    ("doze", 1.5, [doze_frame(i) for i in range(2)]),           # distracting app: Lotus-eaters
    ("ep-cyclops", 3, [cyclops_frame(i) for i in range(8)]),    # episode props (separate layers)
    ("ep-bag", 5, [bag_frame(i) for i in range(4)]),
    ("ep-whirl", 8, [whirl_frame(i) for i in range(4)]),
    ("ep-piglets", 6, [piglet_frame(i) for i in range(2)]),
    ("ep-owl", 5, [owl_frame(i) for i in range(2)]),
]

# ------------------------------------------------------------------- pixel renderer
# Big readable head (9x9, about half the figure), one strong accent (the red crest),
# a 3-row face so expressions read at actual size.
CREST = {
    "up": ["..rrrrr..", ".rRRRRRr."],
    "wind": ["rrrrr....", "rRRRRRr.."],
}
HELMET = ["..ohhho..", ".ohhhhho.", "ohhhhhhho"]
HEADS = {  # rows 5-7 of the side view (facing right)
    "normal": ["oHssssoso", "oHsssPsso", "oHbbbbbso"],
    "squint": ["oHsssooso", "oHsssPsso", "oHbbbbbso"],
    "effort": ["oHsssooso", "oHsssPsso", "oHbbffbso"],
    "joy": ["oHssssoso", "oHsssPsso", "oHbbPPPso"],
    "enchanted": ["oHsssfoso", "oHsssPsso", "oHbbbPbso"],
    "worried": ["oHsssfoso", "oHssSPsso", "oHbbffbso"],
    "sleep": ["oHsssSSso", "oHsssPsso", "oHbbbbbso"],
}
BEARD_TIP = ".obbbbbo."
FRONT_FACE = {"normal": ["oHsossoHo", "oHPsssPHo", "oHbbbbbHo"], "joy": ["oHsossoHo", "oHPsssPHo", "oHbPPPbHo"]}
BACK_HEAD = ["oHhhhhhHo", "oHHhhhHHo", "obbbbbbbo"]
FRONT_CREST = ["...rrr...", "...rRr..."]
BODY_FRONT = [".occco.", "socccos", "socRcos", ".oCcCo.", "..S.S..", "..o.o.."]
BODY_BACK = [".occco.", "socccos", "socRcos", ".oCCCo.", "..S.S..", "..o.o.."]
HULL = [
    "................oo",
    "ooooooooooooooooWo",
    "owwwwwwwwwwwwwfowo",
    ".oWWwWWwWWwWWwWWo.",
    "..oooooooooooooo..",
]
SAILS = {
    "A": ["oooooooo", "orrrrrro", "orrhhrro", "orrhhrro", ".orrrro.", "..oooo.."],
    "B": ["oooooooo", "orrrrrro", "orrhhrro", "orrhhrro", "orrrrrro", ".oooooo."],
    "furl": ["oooooooo", "orRrRrRo", "oooooooo"],
    "stream0": ["oooo....", "rrrro...", "orrrro..", ".orRrro.", "..ooooo."],
    "stream1": ["ooo.....", "orrro...", "rrrrro..", "orRrrro.", ".oooooo."],
}
NOTE = [".tt", ".t.", "tt.", "tt."]
Z_SMALL = ["zzz", "..z", ".z.", "zzz"]
Z_BIG = ["zzzz", "...z", "..z.", ".z..", "zzzz"]
CLOUD = ["...ookkoo.ooo....", ".ookkkkkkokkkoo..", "okkkkkkkkkkkkkkoo", "oKKkKKKkKKKkKKKKo", ".ooooooooooooooo."]
BOLT = ["jj", ".j", "jj", "j."]
SLEEPER = [  # lying on the sand, cap of the helmet as a pillow, eyes closed
    "......ooo..",
    ".....ohhho.",
    "oooooohSSso",
    "occcCcobbbo",
    ".ooooooooo.",
]


EYE = [
    "..bbbbbbbb..",
    ".beeeeeeeeb.",
    "oeeffffffeeo",
    "oefffKKfffeo",
    "oeffKooKffeo",
    "oeefffffeeeo",
    ".oeeeeeeeeo.",
    "..oooooooo..",
]
EYE_BLINK = ["..bbbbbbbb..", ".beeeeeeeeb.", "oeeeeeeeeeeo", "oeoooooooeeo", "oeeeeeeeeeeo",
             "oeeeeeeeeeeo", ".oeeeeeeeeo.", "..oooooooo.."]
BOULDER = [".oo.", "oKko", "oKKo", ".oo."]
SPLASH_BIG = ["f...f", ".f.f.", "f.f.f", ".fff."]
SPLASH_SMALL = [".f.f.", "..f.."]
BAG = ["..oo..", ".oWWo.", ".owwo.", "owwwwo", "owWwwo", "owwwWo", ".oooo."]
BAG_OPEN = ["o....o", ".o..o.", ".owwo.", "owwwwo", "owWwwo", "owwwWo", ".oooo."]
PIG = [".....o..", ".ooooPo.", "oPPPPPPo", "oPPPPoPQ", ".oPPPPo."]
OWL_UP = ["oo...oo", "owoooWo", ".ofofo.", ".owwwo.", "..oho.."]
OWL_DOWN = [".ooooo.", "owofowo", "wofofow", ".owwwo.", "..oho.."]
DOG = ["....oo..", "oooodoo.", "oddddddo", "odd.oddo", ".o....o."]
LOOM = ["oWWWWWo", "oWcrcWo", "oWcrcWo", "oWcrcWo", "oWcrcWo", "oWcrcWo", "oWWWWWo", "oW...Wo",
        "oW...Wo", "oW...Wo", "oW...Wo", "oo...oo"]
PENELOPE = ["..bb..", ".bbbo.", ".bsso.", ".bsSo.", ".oRRo.", "oRRRRo", "oRRRRo", "oRRRRo", "oRRRRo",
            ".oooo."]
LOTUS = [".P.P.", "PPQPP", ".gGg."]


def bresenham(a, b):
    (x0, y0), (x1, y1) = a, b
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        yield x0, y0
        if (x0, y0) == (x1, y1):
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def draw_pixel(els):
    c = canvas(W, H)
    for e in els:
        t = e["t"]
        if t == "sea":
            p = e["phase"]
            top = 22 if e["rough"] else 23
            for x in range(W):
                crest = (x + 4 * p) % 8
                if crest in (1, 2, 3):
                    put(c, x, top, "m")
                if crest == 2:
                    put(c, x, top - 1, "f")
                if e["rough"] and crest in (5, 6):
                    put(c, x, top, "m")
                for y in range(top + 1, H):
                    put(c, x, y, "m" if (y == top + 1 and crest in (0, 4)) else "n")
        elif t == "rock":
            for x in range(W):
                for y in range(23, H):
                    put(c, x, y, "k" if (x * 3 + y) % 7 == 0 else "K")
                if x % 5 == 0:
                    put(c, x, 22, "K")
        elif t == "hull" and e.get("capsized"):
            stamp(c, list(reversed(HULL)), e["x"], e["y"])
        elif t == "hull":
            rows = HULL
            if e["tilt"]:
                rows = [(" " * 0) + r for r in rows]
            stamp(c, rows, e["x"], e["y"])
            if e["tilt"] == 1:      # bow raised: lift right half by one row
                put(c, e["x"] + 17, e["y"] - 1, "o")
            elif e["tilt"] == -1:
                put(c, e["x"], e["y"], "o")
        elif t == "mast":
            for y in range(e["top"], e["bottom"] + 1):
                put(c, e["x"], y, "W")
            sail = SAILS[e["sail"]]
            sx = e["x"] - 4 if not e["sail"].startswith("stream") else e["x"] - 7
            stamp(c, sail, sx, e["top"] + 1)
            for x in range(sx, sx + 8):
                if e["sail"] in ("A", "B", "furl"):
                    put(c, x, e["top"] + 1, "o")
        elif t == "torso":
            cx, top = e["cx"], e["top"]
            body = ["occco", "occco", "oCcCo", ".ooo."][: e["rows"]]
            stamp(c, body, cx - 2, top)
            if e["tied"]:
                for x in range(cx - 3, cx + 4):
                    put(c, x, top + 1, "W")
                    put(c, x, top + 3, "W")
        elif t == "legs":
            cx, top, st = e["cx"], e["top"], e["step"] % 2
            pts = [(cx - 1, top), (cx + 1, top), (cx - 1 - st, top + 1), (cx + 1 + st, top + 1)]
            for x, y in pts:
                put(c, x, y, "S")
            put(c, cx - 1 - st, top + 2, "o")
            put(c, cx + 1 + st, top + 2, "o")
        elif t == "head":
            x0, y0 = e["cx"] - 4, e["cy"] - 5
            view = e.get("view", "side")
            if view == "front":
                stamp(c, FRONT_CREST + HELMET + FRONT_FACE.get(e["expr"], FRONT_FACE["normal"]) + [BEARD_TIP], x0, y0)
            elif view == "back":
                stamp(c, FRONT_CREST + HELMET + BACK_HEAD + [".obbbbbo."], x0, y0)
            else:
                stamp(c, CREST[e["plume"]] + HELMET + HEADS[e["expr"]] + [BEARD_TIP], x0, y0)
        elif t == "limb":
            for x, y in bresenham(e["a"], e["b"]):
                put(c, x, y, "s")
        elif t == "line":
            for x, y in bresenham(e["a"], e["b"]):
                put(c, x, y, e["color"])
        elif t == "dots":
            for x, y in e["points"]:
                put(c, x, y, e["color"])
        elif t == "note":
            stamp(c, NOTE, e["x"], e["y"])
        elif t == "zee":
            stamp(c, Z_BIG if e["big"] else Z_SMALL, e["x"], e["y"])
        elif t == "cloud":
            stamp(c, CLOUD, e["x"], e["y"])
            if e["flash"]:
                stamp(c, BOLT, e["x"] + 11, e["y"] + 5)
        elif t == "island":
            for x in range(12, W):
                top = 20 if 15 <= x <= 29 else 21
                put(c, x, top, "o")
                for y in range(top + 1, 23):
                    put(c, x, y, "y")
            for i, (x, y) in enumerate([(26, 19), (26, 18), (25, 17), (25, 16), (25, 15), (24, 14), (24, 13), (24, 12)]):
                put(c, x, y, "W" if i % 2 else "w")
            stamp(c, ["..ggg.gg.", ".gGGggGGg", "gG..o..Gg", "g.......g"], 20, 9)
        elif t == "sleeper":
            stamp(c, SLEEPER, e["x"], e["y"])
        elif t == "eye":
            stamp(c, EYE_BLINK if e["blink"] else EYE, e["x"], 23 - e["rise"] * 3)
        elif t == "boulder":
            stamp(c, BOULDER, e["x"], e["y"])
        elif t == "splash":
            stamp(c, SPLASH_BIG if e["big"] else SPLASH_SMALL, e["x"], e["y"])
        elif t == "bag":
            stamp(c, BAG_OPEN if e["open"] else BAG, e["x"], e["y"])
        elif t == "whirl":
            for y in range(17, H):
                for x in range(W):
                    if ((x - e["cx"]) / 14.0) ** 2 + ((y - e["cy"]) / 4.6) ** 2 <= 1:
                        put(c, x, y, "n")
            for i in range(90):
                a = i * 0.21 + e["phase"] * 0.9
                r = 0.5 + i * 0.1
                x, y = int(round(e["cx"] + math.cos(a) * r * 1.5)), int(round(e["cy"] + math.sin(a) * r * 0.42))
                put(c, x, y, "f" if (i // 6) % 2 == 0 else "m")
        elif t == "pig":
            rows = list(PIG) + ([".o.o.o.."] if e["step"] % 2 else ["o.o.o..."])
            stamp(c, rows, e["x"], e["y"])
        elif t == "owl":
            stamp(c, OWL_UP if e["up"] else OWL_DOWN, e["x"], e["y"])
        elif t == "ground":
            for x in range(W):
                for y in range(23, H):
                    put(c, x, y, "y" if y > 23 else "o")
        elif t == "dog":
            stamp(c, DOG, e["x"], e["y"])
            put(c, e["x"] + 8, e["y"] + (0 if e["wag"] else 1), "d")
            put(c, e["x"] + 8, e["y"] + 2, "d")
        elif t == "loom":
            stamp(c, LOOM, e["x"], e["y"] + 3)
            put(c, e["x"] + 2 + e["shuttle"], e["y"] + 5 + e["shuttle"], "h")
        elif t == "penelope":
            stamp(c, PENELOPE, e["x"], e["y"] + 4)
            if e["turn"]:
                put(c, e["x"] + 1, e["y"] + 6, "o")
        elif t == "lotus":
            stamp(c, LOTUS, e["x"], e["y"])
        elif t == "figbranch":
            for x in range(W):
                put(c, x, 1, "W")
            for x in (3, 9, 21, 27):
                stamp(c, ["gg.", ".Gg"], x + e["phase"] % 2, 2)
        elif t == "ram":
            x, y = e["x"], e["y"]
            for j in range(8):
                for i in range(20):
                    if ((i - 10) / 10.0) ** 2 + ((j - 4) / 4.2) ** 2 <= 1:
                        put(c, x + i, y + j, "c" if (i + j) % 3 else "C")
            stamp(c, [".ooo.", "oKKKo", "oKoKo", ".oKo."], x + 19, y - 1)
            put(c, x + 18, y - 1, "h"); put(c, x + 18, y, "h")
            st = e["step"] % 2
            for lx in (3, 7, 13, 17):
                put(c, x + lx + (st if lx in (3, 13) else -st), y + 8, "o")
                put(c, x + lx, y + 9, "o")
        elif t == "pulley":
            stamp(c, [".o.", "oKo", ".o."], e["x"] - 1, e["y"])
        elif t == "kick":
            ang = [(-2, 3), (1, 3), (3, 2)][e["k"]]
            for sgn in (-1, 1):
                for x, y in bresenham((e["x"] + sgn, e["y"]), (e["x"] + sgn + ang[0] * (1 if sgn > 0 else 0.5).__int__(), e["y"] + ang[1])):
                    put(c, x, y, "S")
        elif t == "flip":
            c[:] = [list(reversed(r)) for r in reversed(c)]
    return rows_of(c)


# ------------------------------------------------------------------ vector renderer
def head_view_svg(cx, cy, view, ex):
    ol = HEX["o"]
    st = f'stroke="{ol}" stroke-width="0.8" stroke-linejoin="round"'
    g = [f'<ellipse cx="{cx}" cy="{cy - 3.4}" rx="0.9" ry="2" fill="{HEX["r"]}" {st}/>']
    if view == "front":
        g.append(f'<circle cx="{cx}" cy="{cy + 0.9}" r="2.7" fill="{HEX["s"]}" {st}/>')
        g.append(f'<path d="M{cx - 2.5} {cy + 1.6} Q{cx} {cy + 5.6} {cx + 2.5} {cy + 1.6} Q{cx} {cy + 2.8} {cx - 2.5} {cy + 1.6} Z" fill="{HEX["b"]}"/>')
        g.append(f'<path d="M{cx - 3} {cy + 0.8} Q{cx - 3} {cy - 2.6} {cx} {cy - 2.6} Q{cx + 3} {cy - 2.6} {cx + 3} {cy + 0.8} '
                 f'L{cx + 2} {cy + 0.8} L{cx + 2} {cy - 0.4} L{cx - 2} {cy - 0.4} L{cx - 2} {cy + 0.8} Z" fill="{HEX["h"]}" {st}/>')
        for dx in (-1, 1):
            g.append(f'<circle cx="{cx + dx}" cy="{cy + 0.5}" r="0.42" fill="{ol}"/>')
            g.append(f'<circle cx="{cx + dx * 1.9}" cy="{cy + 1.5}" r="0.55" fill="{HEX["P"]}" opacity="0.85"/>')
        if ex == "joy":
            g.append(f'<ellipse cx="{cx}" cy="{cy + 2.5}" rx="0.6" ry="0.5" fill="{ol}"/>')
    else:
        g.append(f'<circle cx="{cx}" cy="{cy + 0.9}" r="2.7" fill="{HEX["b"]}" {st}/>')
        g.append(f'<path d="M{cx - 3} {cy + 1.2} Q{cx - 3} {cy - 2.6} {cx} {cy - 2.6} Q{cx + 3} {cy - 2.6} {cx + 3} {cy + 1.2} Z" fill="{HEX["h"]}" {st}/>')
    return "".join(g)


def body_view_svg(cx, top, view):
    ol = HEX["o"]
    st = f'stroke="{ol}" stroke-width="0.8" stroke-linejoin="round"'
    g = []
    for dx in (-3.2, 3.2):
        g.append(f'<path d="M{cx + dx * 0.8} {top + 0.6} L{cx + dx} {top + 3.4}" stroke="{HEX["s"]}" stroke-width="1" stroke-linecap="round"/>')
    for dx in (-1, 1):
        g.append(f'<path d="M{cx + dx} {top + 3.8} L{cx + dx} {top + 6}" stroke="{HEX["S"]}" stroke-width="0.9" stroke-linecap="round"/>')
    g.append(f'<path d="M{cx - 2.4} {top + 0.3} Q{cx} {top - 0.6} {cx + 2.4} {top + 0.3} L{cx + 2.7} {top + 4} L{cx - 2.7} {top + 4} Z" fill="{HEX["c"]}" {st}/>')
    g.append(f'<path d="M{cx - 2.5} {top + 2} L{cx + 2.5} {top + 2}" stroke="{HEX["R"]}" stroke-width="0.7"/>')
    return "".join(g)


def svg_frame(els):
    out = []
    add = out.append
    ol = HEX["o"]
    stroke = f'stroke="{ol}" stroke-width="0.8" stroke-linejoin="round"'
    for e in els:
        t = e["t"]
        if t == "sea":
            p = e["phase"] * 4
            top = 22.6 if e["rough"] else 23.3
            amp = 1.1 if e["rough"] else 0.7
            d = f"M0 {H} L0 {top}"
            for i in range(17):
                x = i * 2
                d += f" Q{x + 1 - p % 2:.1f} {top - amp if (i + e['phase']) % 2 else top + amp:.1f} {x + 2} {top}"
            d += f" L{W} {H} Z"
            add(f'<path d="{d}" fill="{HEX["n"]}"/>')
            for i in range(4):
                cx = (i * 8 + p) % W + 1
                add(f'<path d="M{cx - 1.2} {top + 0.2} q1.2 -1.2 2.4 0" fill="none" stroke="{HEX["f"]}" stroke-width="0.6" stroke-linecap="round"/>')
        elif t == "rock":
            add(f'<path d="M0 22.5 L4 22 L7 22.8 L12 21.9 L18 22.6 L24 21.8 L28 22.4 L32 22 L32 26 L0 26Z" fill="{HEX["K"]}"/>')
            add(f'<path d="M3 24 l2 -0.6 M13 23.6 l3 -0.8 M22 24.2 l2 -0.5" stroke="{HEX["k"]}" stroke-width="0.6" stroke-linecap="round"/>')
        elif t == "hull":
            x, y, tl = e["x"], e["y"], e["tilt"] * 4
            flipv = f" translate(0 {2 * y + 4}) scale(1 -1)" if e.get("capsized") else ""
            add(f'<g transform="rotate({-tl} {x + 9} {y + 2}){flipv}">'
                f'<path d="M{x} {y + 1} L{x + 16} {y + 1} Q{x + 17.5} {y + 0.5} {x + 17.6} {y - 1.2} '
                f'Q{x + 18.4} {y + 2.4} {x + 15.6} {y + 4.6} L{x + 2.4} {y + 4.6} Q{x + 0.4} {y + 3} {x} {y + 1} Z" '
                f'fill="{HEX["w"]}" {stroke}/>'
                f'<path d="M{x + 1.4} {y + 3} L{x + 16.2} {y + 3}" stroke="{HEX["W"]}" stroke-width="0.6"/>'
                f'<circle cx="{x + 14.6}" cy="{y + 2.1}" r="0.75" fill="{HEX["f"]}" stroke="{ol}" stroke-width="0.35"/>'
                f'<circle cx="{x + 14.9}" cy="{y + 2.1}" r="0.35" fill="{ol}"/></g>')
        elif t == "mast":
            x, top, bot = e["x"] + 0.5, e["top"], e["bottom"]
            add(f'<path d="M{x} {top} L{x} {bot + 1}" stroke="{HEX["W"]}" stroke-width="0.9" stroke-linecap="round"/>')
            s = e["sail"]
            if s in ("A", "B"):
                belly = 2.4 if s == "A" else 1.4
                add(f'<path d="M{x - 4} {top + 1.2} L{x + 4} {top + 1.2} Q{x + 4.4 + belly * 0.3} {top + 4} {x + 3} {top + 6.4} '
                    f'Q{x} {top + 6.4 + belly} {x - 3} {top + 6.4} Q{x - 4.4} {top + 4} {x - 4} {top + 1.2} Z" fill="{HEX["r"]}" {stroke}/>')
                add(f'<circle cx="{x}" cy="{top + 3.8}" r="1.1" fill="{HEX["h"]}"/>')
                add(f'<path d="M{x - 4.6} {top + 1.2} L{x + 4.6} {top + 1.2}" stroke="{HEX["W"]}" stroke-width="0.8" stroke-linecap="round"/>')
            elif s == "furl":
                add(f'<rect x="{x - 4.2}" y="{top + 1}" width="8.4" height="1.8" rx="0.9" fill="{HEX["r"]}" {stroke}/>')
            else:
                k = int(s[-1])
                add(f'<path d="M{x} {top + 1} Q{x - 4} {top + 1 - k} {x - 7.5} {top + 2 + k} Q{x - 4} {top + 4} {x - 6.5} {top + 6 - k} '
                    f'Q{x - 3} {top + 5} {x} {top + 5.5} Z" fill="{HEX["r"]}" {stroke}/>')
        elif t == "torso":
            cx, top, rows = e["cx"] + 0.5, e["top"], e["rows"]
            hgt = 3.6 if rows >= 4 else 2.2
            add(f'<path d="M{cx - 2.3} {top + 0.3} Q{cx} {top - 0.6} {cx + 2.3} {top + 0.3} L{cx + 2.6} {top + hgt} '
                f'L{cx - 2.6} {top + hgt} Z" fill="{HEX["c"]}" {stroke}/>')
            add(f'<path d="M{cx - 2.5} {top + hgt - 0.6} L{cx + 2.5} {top + hgt - 0.6}" stroke="{HEX["R"]}" stroke-width="0.5"/>')
            if e["tied"]:
                for dy in (1.3, 3.0):
                    add(f'<path d="M{cx - 3.2} {top + dy} L{cx + 3.4} {top + dy}" stroke="{HEX["W"]}" stroke-width="0.7" stroke-linecap="round"/>')
        elif t == "legs":
            cx, top, st = e["cx"] + 0.5, e["top"], e["step"] % 2
            for sgn in (-1, 1):
                add(f'<path d="M{cx + sgn} {top} L{cx + sgn * (1 + st)} {top + 2.2}" stroke="{HEX["S"]}" stroke-width="0.9" stroke-linecap="round"/>')
        elif t == "head":
            cx, cy = e["cx"] + 0.5, e["cy"] + 0.5
            ex = e["expr"]
            add(f'<g transform="translate({cx} {cy - 0.6}) scale(1.3) translate({-cx} {-cy})">')
            if e.get("view", "side") != "side":
                add(head_view_svg(cx, cy, e["view"], ex) + "</g>")
                continue
            add(f'<circle cx="{cx}" cy="{cy + 0.9}" r="2.7" fill="{HEX["s"]}" {stroke}/>')
            add(f'<path d="M{cx - 2.6} {cy + 1.4} Q{cx - 0.4} {cy + 5.4} {cx + 2.6} {cy + 1.8} Q{cx + 1.2} {cy + 2.8} {cx} {cy + 2.2} '
                f'Q{cx - 1.4} {cy + 2.6} {cx - 2.6} {cy + 1.4} Z" fill="{HEX["b"]}"/>')
            add(f'<path d="M{cx - 3} {cy + 0.4} Q{cx - 3} {cy - 2.6} {cx} {cy - 2.6} Q{cx + 3} {cy - 2.6} {cx + 3} {cy - 0.7} '
                f'L{cx + 0.4} {cy - 0.7} L{cx - 0.2} {cy + 1} L{cx - 1.8} {cy + 1.6} Z" fill="{HEX["h"]}" {stroke}/>')
            if e["plume"] == "up":
                add(f'<path d="M{cx - 2.2} {cy - 2.2} Q{cx - 1} {cy - 5.4} {cx + 2.8} {cy - 3.6} Q{cx + 0.6} {cy - 3.4} {cx + 1.4} {cy - 2.4} Z" fill="{HEX["r"]}" {stroke}/>')
            else:
                add(f'<path d="M{cx + 1.6} {cy - 2.4} Q{cx - 2} {cy - 4.6} {cx - 5.6} {cy - 2.4} Q{cx - 3} {cy - 2} {cx - 4.6} {cy - 0.6} '
                    f'Q{cx - 1.4} {cy - 1.6} {cx + 1} {cy - 1.8} Z" fill="{HEX["r"]}" {stroke}/>')
            eye = (cx + 1.5, cy + 0.5)
            if ex == "sleep":
                add(f'<path d="M{eye[0] - 0.7} {eye[1] - 0.1} Q{eye[0]} {eye[1] + 0.6} {eye[0] + 0.7} {eye[1] - 0.1}" fill="none" stroke="{ol}" stroke-width="0.5" stroke-linecap="round"/>')
            elif ex in ("squint", "effort"):
                add(f'<path d="M{eye[0] - 0.7} {eye[1]} L{eye[0] + 0.7} {eye[1]}" stroke="{ol}" stroke-width="0.55" stroke-linecap="round"/>')
                if ex == "effort":
                    add(f'<rect x="{cx + 0.2}" y="{cy + 2.1}" width="1.6" height="0.7" rx="0.2" fill="#fff" stroke="{ol}" stroke-width="0.25"/>')
                else:
                    add(f'<path d="M{eye[0] - 0.8} {eye[1] - 0.9} L{eye[0] + 0.6} {eye[1] - 0.6}" stroke="{ol}" stroke-width="0.35"/>')
            elif ex == "joy":
                add(f'<path d="M{eye[0] - 0.7} {eye[1] + 0.2} Q{eye[0]} {eye[1] - 0.7} {eye[0] + 0.7} {eye[1] + 0.2}" fill="none" stroke="{ol}" stroke-width="0.5" stroke-linecap="round"/>')
                add(f'<ellipse cx="{cx + 0.9}" cy="{cy + 2.5}" rx="0.8" ry="0.55" fill="{HEX["P"]}" stroke="{ol}" stroke-width="0.3"/>')
            elif ex in ("enchanted", "worried"):
                add(f'<circle cx="{eye[0]}" cy="{eye[1]}" r="0.75" fill="#fff" stroke="{ol}" stroke-width="0.3"/><circle cx="{eye[0] + 0.25}" cy="{eye[1]}" r="0.35" fill="{ol}"/>')
                if ex == "enchanted":
                    add(f'<ellipse cx="{cx + 1}" cy="{cy + 2.6}" rx="0.5" ry="0.6" fill="{ol}"/>')
                    add(f'<circle cx="{cx - 0.4}" cy="{cy + 1.3}" r="0.55" fill="#F59A9A" opacity="0.8"/>')
                else:
                    add(f'<path d="M{eye[0] - 0.8} {eye[1] - 0.8} L{eye[0] + 0.7} {eye[1] - 1.2}" stroke="{ol}" stroke-width="0.4"/>')
                    add(f'<rect x="{cx + 0.2}" y="{cy + 2.1}" width="1.6" height="0.7" rx="0.2" fill="#fff" stroke="{ol}" stroke-width="0.25"/>')
            else:
                add(f'<ellipse cx="{eye[0]}" cy="{eye[1]}" rx="0.42" ry="0.55" fill="{ol}"/>')
                add(f'<circle cx="{eye[0] - 0.12}" cy="{eye[1] - 0.2}" r="0.14" fill="#fff"/>')
            if ex != "sleep":
                add(f'<circle cx="{cx + 0.2}" cy="{cy + 1.5}" r="0.6" fill="{HEX["P"]}" opacity="0.85"/>')
            add("</g>")
        elif t == "limb":
            (ax, ay), (bx, by) = e["a"], e["b"]
            add(f'<path d="M{ax + 0.5} {ay + 0.5} L{bx + 0.5} {by + 0.5}" stroke="{HEX["s"]}" stroke-width="1" stroke-linecap="round"/>')
        elif t == "line":
            (ax, ay), (bx, by) = e["a"], e["b"]
            w = {"oar": 0.8, "wind": 0.5, "rope": 0.5}[e["kind"]]
            col = HEX[e["color"]]
            add(f'<path d="M{ax + 0.5} {ay + 0.5} L{bx + 0.5} {by + 0.5}" stroke="{col}" stroke-width="{w}" stroke-linecap="round"/>')
            if e["kind"] == "oar":
                add(f'<ellipse cx="{bx + 0.5}" cy="{by + 0.3}" rx="0.7" ry="1.4" transform="rotate(30 {bx + 0.5} {by + 0.3})" fill="{HEX["w"]}" {stroke}/>')
        elif t == "dots":
            for x, y in e["points"]:
                r = 0.55 if e["color"] in "fp" else 0.6
                add(f'<circle cx="{x + 0.5}" cy="{y + 0.5}" r="{r}" fill="{HEX[e["color"]]}"/>')
        elif t == "note":
            x, y = e["x"], e["y"]
            add(f'<path d="M{x + 2.2} {y + 0.2} L{x + 2.2} {y + 3} M{x + 2.2} {y + 0.2} L{x + 3.4} {y + 1}" stroke="{HEX["t"]}" stroke-width="0.6" stroke-linecap="round"/>'
                f'<ellipse cx="{x + 1.4}" cy="{y + 3.1}" rx="1" ry="0.75" fill="{HEX["t"]}"/>')
        elif t == "zee":
            x, y, s = e["x"], e["y"], (1.4 if e["big"] else 1)
            add(f'<path d="M{x} {y} h{3 * s} l{-3 * s} {3 * s} h{3 * s}" fill="none" stroke="{HEX["z"]}" stroke-width="0.7" stroke-linejoin="round" stroke-linecap="round"/>')
        elif t == "cloud":
            x, y = e["x"], e["y"]
            add(f'<path d="M{x + 1} {y + 4.6} Q{x - 0.6} {y + 2} {x + 3} {y + 2} Q{x + 4} {y - 0.6} {x + 7.6} {y + 1} Q{x + 10} {y - 1} {x + 12.6} {y + 1.4} '
                f'Q{x + 17} {y + 1.4} {x + 16} {y + 4.6} Z" fill="{HEX["k"]}" {stroke}/>')
            add(f'<path d="M{x + 2} {y + 4} L{x + 15.4} {y + 4}" stroke="{HEX["K"]}" stroke-width="0.8"/>')
            if e["flash"]:
                add(f'<path d="M{x + 12} {y + 5} L{x + 10.6} {y + 7.6} L{x + 12} {y + 7.6} L{x + 10.8} {y + 10}" fill="none" stroke="{HEX["j"]}" stroke-width="0.8" stroke-linejoin="round"/>')
        elif t == "island":
            add(f'<path d="M12 23 Q13 20 18 20.2 Q24 19.6 30 20.4 Q32 21 32 23 Z" fill="{HEX["y"]}" {stroke}/>')
            add(f'<path d="M26.3 20 Q24.6 15 24.6 12.4" fill="none" stroke="{HEX["w"]}" stroke-width="1" stroke-linecap="round"/>')
            for dx, dy, rot in ((-3, 0.4, -20), (3, 0.2, 20), (-1.6, -1, -60), (1.8, -1, 60)):
                add(f'<ellipse cx="{24.6 + dx}" cy="{12.4 + dy}" rx="3" ry="0.95" transform="rotate({rot} {24.6 + dx} {12.4 + dy})" fill="{HEX["g"]}" stroke="{HEX["G"]}" stroke-width="0.4"/>')
            add(f'<circle cx="24.4" cy="13.2" r="0.6" fill="{HEX["W"]}"/>')
        elif t == "sleeper":
            x, y = e["x"], e["y"]
            add(f'<rect x="{x}" y="{y + 2.2}" width="6.4" height="2.4" rx="1.2" fill="{HEX["c"]}" {stroke}/>')
            add(f'<path d="M{x + 0.2} {y + 3.4} L{x - 1.6} {y + 3.8}" stroke="{HEX["S"]}" stroke-width="0.9" stroke-linecap="round"/>')
            add(f'<circle cx="{x + 8.2}" cy="{y + 2.6}" r="2.2" fill="{HEX["s"]}" {stroke}/>')
            add(f'<path d="M{x + 6.6} {y + 3.4} Q{x + 8.2} {y + 5.6} {x + 10.2} {y + 3.2} Z" fill="{HEX["b"]}"/>')
            add(f'<path d="M{x + 7.4} {y + 2.4} q0.6 0.5 1.2 0" fill="none" stroke="{ol}" stroke-width="0.4" stroke-linecap="round"/>')
            add(f'<path d="M{x + 6} {y + 1.8} Q{x + 8} {y - 0.6} {x + 10.4} {y + 1.6} Z" fill="{HEX["h"]}" {stroke}/>')
        elif t == "eye":
            x, top = e["x"] + 6, 23 - e["rise"] * 3 + 4
            add(f'<ellipse cx="{x}" cy="{top}" rx="6" ry="4" fill="{HEX["e"]}" {stroke}/>')
            if e["blink"]:
                add(f'<path d="M{x - 4.4} {top} Q{x} {top + 1.6} {x + 4.4} {top}" fill="none" stroke="{ol}" stroke-width="0.7" stroke-linecap="round"/>')
            else:
                add(f'<ellipse cx="{x}" cy="{top}" rx="4.2" ry="2.6" fill="#fff" stroke="{ol}" stroke-width="0.5"/>')
                add(f'<circle cx="{x - 0.6}" cy="{top + 0.2}" r="1.6" fill="{HEX["K"]}"/><circle cx="{x - 0.6}" cy="{top + 0.2}" r="0.8" fill="{ol}"/>')
                add(f'<circle cx="{x - 1.1}" cy="{top - 0.4}" r="0.35" fill="#fff"/>')
            add(f'<path d="M{x - 5.4} {top - 3.2} Q{x} {top - 5.6} {x + 5.4} {top - 3.2}" fill="none" stroke="{HEX["b"]}" stroke-width="1.3" stroke-linecap="round"/>')
        elif t == "boulder":
            add(f'<path d="M{e["x"]} {e["y"] + 2} Q{e["x"] + 0.4} {e["y"]} {e["x"] + 2.2} {e["y"]} Q{e["x"] + 4} {e["y"] + 0.4} {e["x"] + 4} {e["y"] + 2.2} '
                f'Q{e["x"] + 3.4} {e["y"] + 4} {e["x"] + 1.8} {e["y"] + 4} Q{e["x"]} {e["y"] + 3.6} {e["x"]} {e["y"] + 2} Z" fill="{HEX["K"]}" {stroke}/>')
        elif t == "splash":
            n = 5 if e["big"] else 3
            for i in range(n):
                ang = math.pi * (0.15 + 0.7 * i / max(n - 1, 1))
                x0, y0 = e["x"] + 2.5, e["y"] + 3.5
                add(f'<path d="M{x0} {y0} L{x0 - math.cos(ang) * 3:.2f} {y0 - math.sin(ang) * 3.4:.2f}" stroke="{HEX["f"]}" stroke-width="0.7" stroke-linecap="round"/>')
        elif t == "bag":
            x, y = e["x"], e["y"]
            add(f'<path d="M{x + 1} {y + 3} Q{x - 0.6} {y + 7} {x + 3} {y + 7} Q{x + 6.6} {y + 7} {x + 5} {y + 3} Z" fill="{HEX["w"]}" {stroke}/>')
            if not e["open"]:
                add(f'<path d="M{x + 2} {y + 3} L{x + 3} {y + 1.2} L{x + 4} {y + 3}" fill="{HEX["W"]}" {stroke}/>')
            else:
                add(f'<path d="M{x + 1} {y + 3} Q{x + 3} {y + 2} {x + 5} {y + 3}" fill="none" stroke="{ol}" stroke-width="0.6"/>')
        elif t == "whirl":
            pts = []
            for i in range(40):
                a = i * 0.36 + e["phase"] * 0.8
                r = 0.6 + i * 0.22
                pts.append(f'{e["cx"] + math.cos(a) * r * 1.6:.2f} {e["cy"] + math.sin(a) * r * 0.45:.2f}')
            add(f'<path d="M{" L".join(pts)}" fill="none" stroke="{HEX["f"]}" stroke-width="0.6" stroke-linecap="round"/>')
        elif t == "pig":
            x, y = e["x"], e["y"]
            add(f'<ellipse cx="{x + 3.6}" cy="{y + 3}" rx="3.3" ry="2" fill="{HEX["P"]}" {stroke}/>')
            add(f'<ellipse cx="{x + 7.1}" cy="{y + 3.3}" rx="0.9" ry="0.7" fill="{HEX["Q"]}" stroke="{ol}" stroke-width="0.4"/>')
            add(f'<path d="M{x + 5} {y + 1.4} l0.6 -1.3 l0.6 1.2" fill="{HEX["P"]}" stroke="{ol}" stroke-width="0.4"/>')
            add(f'<circle cx="{x + 5.6}" cy="{y + 2.6}" r="0.35" fill="{ol}"/>')
            for i, lx in enumerate((1.6, 3.2, 4.8)):
                dx = 0.5 if (i + e["step"]) % 2 else -0.5
                add(f'<path d="M{x + lx} {y + 4.6} l{dx} 1.4" stroke="{ol}" stroke-width="0.6" stroke-linecap="round"/>')
            add(f'<path d="M{x + 0.4} {y + 2.6} q-1 -0.6 -0.6 -1.4" fill="none" stroke="{HEX["Q"]}" stroke-width="0.5"/>')
        elif t == "owl":
            x, y = e["x"], e["y"]
            add(f'<ellipse cx="{x + 3.5}" cy="{y + 3}" rx="2.4" ry="2.8" fill="{HEX["w"]}" {stroke}/>')
            wy = -1.6 if e["up"] else 1.2
            add(f'<path d="M{x + 1.2} {y + 2.4} Q{x - 1.8} {y + 1 + wy} {x - 2.4} {y + 2.6 + wy} Q{x - 0.4} {y + 3.6} {x + 1.4} {y + 3.6} Z" fill="{HEX["W"]}" {stroke}/>')
            add(f'<path d="M{x + 5.8} {y + 2.4} Q{x + 8.8} {y + 1 + wy} {x + 9.4} {y + 2.6 + wy} Q{x + 7.4} {y + 3.6} {x + 5.6} {y + 3.6} Z" fill="{HEX["W"]}" {stroke}/>')
            for ex in (2.6, 4.4):
                add(f'<circle cx="{x + ex}" cy="{y + 2.2}" r="0.85" fill="#fff" stroke="{ol}" stroke-width="0.3"/><circle cx="{x + ex}" cy="{y + 2.2}" r="0.4" fill="{ol}"/>')
            add(f'<path d="M{x + 3.2} {y + 3} l0.3 0.7 l0.3 -0.7 Z" fill="{HEX["h"]}"/>')
        elif t == "ground":
            add(f'<path d="M0 23.2 L32 23.2 L32 26 L0 26 Z" fill="{HEX["y"]}"/><path d="M0 23.2 L32 23.2" stroke="{ol}" stroke-width="0.6"/>')
        elif t == "dog":
            x, y = e["x"], e["y"]
            add(f'<path d="M{x + 0.6} {y + 4} Q{x} {y + 2} {x + 2.2} {y + 1.8} L{x + 7} {y + 2.2} Q{x + 8} {y + 3.4} {x + 7.4} {y + 4} Z" fill="{HEX["d"]}" {stroke}/>')
            add(f'<path d="M{x + 1.2} {y + 2} Q{x + 1.6} {y - 0.2} {x + 3.4} {y + 0.6} L{x + 3.2} {y + 2}" fill="{HEX["d"]}" {stroke}/>')
            add(f'<circle cx="{x + 2.2}" cy="{y + 1.2}" r="0.3" fill="{ol}"/>')
            ty = -1 if e["wag"] else 0.6
            add(f'<path d="M{x + 7.4} {y + 2.6} q1.6 {ty} 1.8 {ty - 1.2}" fill="none" stroke="{HEX["d"]}" stroke-width="0.8" stroke-linecap="round"/>')
        elif t == "loom":
            x, y = e["x"], e["y"] + 3
            add(f'<path d="M{x + 0.6} {y + 12} L{x + 0.6} {y} L{x + 6.4} {y} L{x + 6.4} {y + 12}" fill="none" stroke="{HEX["W"]}" stroke-width="0.9" stroke-linecap="round"/>')
            add(f'<rect x="{x + 1.4}" y="{y + 1}" width="4.2" height="5.4" fill="{HEX["c"]}"/>')
            for i in range(3):
                add(f'<path d="M{x + 2 + i * 1.3} {y + 1} L{x + 2 + i * 1.3} {y + 6.4}" stroke="{HEX["r"]}" stroke-width="0.4"/>')
            sh = e["shuttle"]
            add(f'<circle cx="{x + 2 + sh * 1.3}" cy="{y + 2.2 + sh * 1.6}" r="0.6" fill="{HEX["h"]}"/>')
        elif t == "penelope":
            x, y = e["x"], e["y"] + 4
            add(f'<path d="M{x + 0.6} {y + 9.6} L{x + 1.4} {y + 4} L{x + 4.6} {y + 4} L{x + 5.4} {y + 9.6} Z" fill="{HEX["R"]}" {stroke}/>')
            add(f'<circle cx="{x + 3}" cy="{y + 2.4}" r="1.9" fill="{HEX["s"]}" {stroke}/>')
            add(f'<path d="M{x + 1.1} {y + 2.4} Q{x + 1.4} {y + 0.2} {x + 3.4} {y + 0.4} Q{x + 2.2} {y + 1.6} {x + 2} {y + 3.6} Z" fill="{HEX["b"]}"/>')
            add(f'<circle cx="{x + 1.2}" cy="{y + 0.8}" r="0.9" fill="{HEX["b"]}"/>')
            add(f'<circle cx="{x + 3.6 if not e["turn"] else x + 2.4}" cy="{y + 2.4}" r="0.3" fill="{ol}"/>')
        elif t == "lotus":
            x, y = e["x"], e["y"]
            add(f'<ellipse cx="{x + 2.5}" cy="{y + 2.4}" rx="2.6" ry="0.7" fill="{HEX["g"]}"/>')
            for dx, rot in ((-1.1, -30), (0, 0), (1.1, 30)):
                add(f'<ellipse cx="{x + 2.5 + dx}" cy="{y + 1}" rx="0.7" ry="1.5" transform="rotate({rot} {x + 2.5 + dx} {y + 1.6})" fill="{HEX["P"]}" stroke="{HEX["Q"]}" stroke-width="0.3"/>')
        elif t == "figbranch":
            ph = e["phase"]
            add(f'<path d="M-1 1.6 Q8 {0.8 + ph * 0.3} 16 1.8 Q24 {2.6 - ph * 0.3} 33 1.4" fill="none" stroke="{HEX["W"]}" stroke-width="1.2" stroke-linecap="round"/>')
            for lx in (3, 9.5, 22, 28):
                add(f'<path d="M{lx} 2 q1.6 0.2 2.2 2.2 q-1.8 0.2 -2.2 -2.2 Z" fill="{HEX["g"]}" stroke="{HEX["G"]}" stroke-width="0.35"/>')
            add(f'<circle cx="25" cy="3.2" r="0.9" fill="{HEX["m"]}"/>')
        elif t == "ram":
            x, y, st = e["x"], e["y"], e["step"] % 2
            for lx in (4, 8, 13, 17):
                dx = (0.7 if (lx in (4, 13)) == bool(st) else -0.7)
                add(f'<path d="M{x + lx} {y + 6} L{x + lx + dx} {y + 10.4}" stroke="{HEX["K"]}" stroke-width="1" stroke-linecap="round"/>')
            for cx_, cy_, r in ((x + 4, y + 4.4, 2.6), (x + 8, y + 3.4, 3), (x + 12.4, y + 3.2, 3), (x + 16.4, y + 4, 2.7),
                                (x + 6, y + 6, 2.4), (x + 10.4, y + 6.4, 2.6), (x + 14.6, y + 6.2, 2.4)):
                add(f'<circle cx="{cx_}" cy="{cy_}" r="{r}" fill="{HEX["c"]}" stroke="{ol}" stroke-width="0.7"/>')
            add(f'<path d="M{x + 2} {y + 5} Q{x + 10} {y + 1.6} {x + 18} {y + 5} Q{x + 10} {y + 8.6} {x + 2} {y + 5} Z" fill="{HEX["c"]}"/>')
            add(f'<ellipse cx="{x + 20.6}" cy="{y + 2.6}" rx="2.2" ry="2.6" transform="rotate(20 {x + 20.6} {y + 2.6})" fill="{HEX["K"]}" {stroke}/>')
            add(f'<circle cx="{x + 21.6}" cy="{y + 2}" r="0.45" fill="#fff"/>')
            add(f'<path d="M{x + 19.6} {y + 0.6} q-2.4 -1.4 -2.6 1 q0.2 1.6 1.6 1" fill="none" stroke="{HEX["h"]}" stroke-width="0.9" stroke-linecap="round"/>')
        elif t == "crag":
            add(f'<path d="M0 21.4 L3 20.2 L5 21 L9 19.6 L12 20.8 L16 19.8 L19 21 L23 19.4 L26 20.6 L29 19.8 L32 20.4 L32 26 L0 26 Z" fill="{HEX["K"]}" {stroke}/>')
            add(f'<path d="M4 22.6 l2 -0.8 M13 22.2 l2.6 -0.9 M24 22.8 l2 -0.6" stroke="{HEX["k"]}" stroke-width="0.6" stroke-linecap="round"/>')
            add(f'<path d="M8 20.2 q1 -1 2 0 M21 20 q0.8 -0.9 1.6 0" fill="{HEX["g"]}" stroke="{HEX["G"]}" stroke-width="0.3"/>')
        elif t == "olive":
            add(f'<path d="M0 20.6 Q8 19.6 16 20.4 Q24 21.2 32 20 L32 26 L0 26 Z" fill="#8C7A5B" {stroke}/>')
            add(f'<path d="M2 22.4 Q9 21.4 15 22.6 Q22 23.6 30 22.2 M5 24.2 Q12 23.4 20 24.6" fill="none" stroke="#5E5040" stroke-width="0.5"/>')
            for lx, ly in ((6, 18.6), (19, 18.8), (28, 18.4)):
                add(f'<ellipse cx="{lx}" cy="{ly}" rx="2" ry="0.7" transform="rotate(-25 {lx} {ly})" fill="#9DB58A" stroke="#5F7A52" stroke-width="0.3"/>')
                add(f'<circle cx="{lx + 1.6}" cy="{ly + 0.9}" r="0.45" fill="{HEX["n"]}"/>')
        elif t == "maststrip":
            add(f'<rect x="-1" y="20.4" width="34" height="2.4" rx="1.2" fill="{HEX["w"]}" {stroke}/>')
            for rx in (6, 14, 22):
                add(f'<path d="M{rx} 20.4 L{rx} 22.8" stroke="{HEX["W"]}" stroke-width="0.6"/>')
            add(f'<path d="M28 20.4 L28 15 L31 15 L31 20.4" fill="{HEX["w"]}" {stroke}/>')
            add(f'<path d="M29.5 15 L29.5 11 L33 12.2 L29.5 13.4" fill="{HEX["r"]}" {stroke}/>')
        elif t == "smoke":
            x, y, ph = e["x"], e["y"], e["phase"]
            add(f'<path d="M{x} {y + 4} q1.6 -1.6 3 0 t3 0 t2.6 -0.6" fill="none" stroke="#B9BCC8" stroke-width="0.9" stroke-linecap="round"/>')
            add(f'<path d="M{x - 2} {y + 6.4} l1.2 -1.4 l1.2 1.4 Z" fill="{HEX["w"]}" stroke="{ol}" stroke-width="0.4"/>')
        elif t == "pulley":
            add(f'<circle cx="{e["x"] + 0.5}" cy="{e["y"] + 0.6}" r="1.3" fill="{HEX["K"]}" {stroke}/>')
            add(f'<path d="M{e["x"] + 0.5} {e["y"] + 1.6} L{e["x"] + 0.5} {e["y"] + 3.4}" stroke="{HEX["W"]}" stroke-width="0.6"/>')
        elif t == "kick":
            x, y, k = e["x"] + 0.5, e["y"], e["k"]
            for i, (dx, dy) in enumerate([[(-1.8, 2.6), (1.6, 2.2)], [(0.4, 3), (2.6, 1.6)], [(1.8, 2.2), (-0.6, 3)]][k]):
                sx = x + (-1 if i == 0 else 1)
                add(f'<path d="M{sx} {y} L{sx + dx} {y + dy}" stroke="{HEX["S"]}" stroke-width="0.9" stroke-linecap="round"/>')
        elif t == "flip":
            out[:] = [f'<g transform="rotate(180 {W / 2} {H / 2})">'] + out + ["</g>"]
    body = "".join(out)
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
            f'{body}</svg>\n')


# -------------------------------------------------------------------------- output
def main():
    chars = os.path.join(ASSETS, "characters")
    previews = os.path.join(ASSETS, "previews")
    os.makedirs(chars, exist_ok=True)

    # pixel variant
    lines = ["# Edgeling sprite v1 - Odysseus, pixel variant. Generated by tools/make_odysseus.py from",
             "# hand-written stamps; edit the stamps or the frames directly. See PROVENANCE.md.",
             "name: Odysseus (pixel)", f"size: {W}x{H}", "pixel: 2", "palette:"]
    lines += [f"  {k} {v}  # {n}" for k, v, n in PALETTE]
    sheet = []
    for anim, fps, frames in ANIMS:
        lines.append(f"anim: {anim} fps={fps}")
        rows_all = []
        for fr in frames:
            rows = draw_pixel(fr)
            rows_all.append(rows)
            lines.append("frame:")
            lines += ["  " + r for r in rows]
        sheet.append(rows_all)
    with open(os.path.join(chars, "odysseus-pixel.sprite"), "w") as f:
        f.write("\n".join(lines) + "\n")

    # vector variant
    vdir = os.path.join(chars, "odysseus-vector")
    os.makedirs(vdir, exist_ok=True)
    manifest = ["# Edgeling vector character v1 - Odysseus, clean vector variant (SVG frames).",
                "name: Odysseus (vector)", f"size: {W}x{H}"]
    for anim, fps, frames in ANIMS:
        names = []
        for i, fr in enumerate(frames):
            fn = f"{anim}-{i}.svg"
            with open(os.path.join(vdir, fn), "w") as f:
                f.write(svg_frame(fr))
            names.append(fn)
        manifest.append(f"anim: {anim} fps={fps} frames={','.join(names)}")
    with open(os.path.join(vdir, "character.txt"), "w") as f:
        f.write("\n".join(manifest) + "\n")

    # pixel preview sheet (8x, light background): one row per animation
    pal = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for k, v, _ in PALETTE}
    scale, pad = 6, 3
    cols = max(len(r) for r in sheet)
    PW, PH = (cols * (W + pad) + pad) * scale, (len(sheet) * (H + pad) + pad) * scale
    px = [[(236, 239, 244, 255)] * PW for _ in range(PH)]
    for r, frames in enumerate(sheet):
        for i, rows in enumerate(frames):
            ox, oy = (pad + i * (W + pad)) * scale, (pad + r * (H + pad)) * scale
            for y, row in enumerate(rows):
                for x, k in enumerate(row):
                    if k == ".":
                        continue
                    for dy in range(scale):
                        for dx in range(scale):
                            px[oy + y * scale + dy][ox + x * scale + dx] = pal[k]
    png(os.path.join(previews, "odysseus-pixel-sheet@6x.png"), px, PW, PH)
    print("ok", vdir)


if __name__ == "__main__":
    main()
