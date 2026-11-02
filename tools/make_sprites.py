#!/usr/bin/env python3
"""Compose the hand-drawn pixel stamps below into character sprite files.

Every stamp in this file was typed by hand as a character grid; the code only
places stamps on a canvas (offsets = squash/stretch, bobbing, waving) and writes
`assets/characters/<id>.sprite` plus enlarged PNG previews. No image generation,
no third-party art. Run:  python3 tools/make_sprites.py
"""
import os
import struct
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
ASSETS = os.path.join(HERE, "..", "assets")


# ---------------------------------------------------------------- canvas utils
def canvas(w, h):
    return [["."] * w for _ in range(h)]


def stamp(c, rows, x, y):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch == ".":
                continue
            yy, xx = y + j, x + i
            if 0 <= yy < len(c) and 0 <= xx < len(c[0]):
                c[yy][xx] = ch


def put(c, x, y, ch):
    if 0 <= y < len(c) and 0 <= x < len(c[0]):
        c[y][x] = ch


def rows_of(c):
    return ["".join(r) for r in c]


# ------------------------------------------------------------ character: Pip
# A small inchworm. Limited palette (9 colours), 1px plum outline everywhere,
# light from top-left (l), shade bottom-right (d).
PIP_PALETTE = [
    ("o", "#2E2440", "outline / pupil"),
    ("g", "#8AD15A", "body"),
    ("d", "#4F9A45", "body shade"),
    ("l", "#D2F59A", "highlight"),
    ("y", "#F2C94C", "feet"),
    ("w", "#FFFFFF", "eye white"),
    ("c", "#FF8FA8", "cheek"),
    ("a", "#FF9F43", "antenna tip"),
    ("z", "#6C7BFF", "sleep z / signal"),
]

SEG = [
    ".oooo.",
    "olgggo",
    "oggggo",
    "oggddo",
    ".oooo.",
]
HEAD = [
    "..oooo..",
    ".olgggo.",
    "olgggwwo",
    "ogggwwoo",
    "oggggcgo",
    ".oddgdo.",
    "..oooo..",
]
HEAD_SLEEP = [
    "..oooo..",
    ".olgggo.",
    "olggggo.",
    "ogggoooo",
    "oggggcgo",
    ".oddgdo.",
    "..oooo..",
]
HEAD_BLINK = [
    "..oooo..",
    ".olgggo.",
    "olggggoo",
    "ogggoooo",
    "oggggcgo",
    ".oddgdo.",
    "..oooo..",
]
ANT_UP = ["..a", ".o.", "o.."]          # antenna, relative to head top-left +3,-3
ANT_TILT = ["a..", ".o.", ".o."]
Z_SMALL = ["zzzz", "..z.", ".z..", "zzzz"]
Z_BIG = ["zzzzz", "...z.", "..z..", ".z...", "zzzzz"]
BANG = ["z", "z", "z", ".", "z"]     # tiny "!" used when calling you
FOOT_UP = ["y.", ".y"]                # front foot raised = wave

PIP_W, PIP_H = 26, 14
GROUND = PIP_H - 1                       # feet row


def pip_frame(seg_x, seg_dy, head_x, head_dy, head=HEAD, ant=ANT_UP, extra=None, legs=True):
    c = canvas(PIP_W, PIP_H)
    base_top = GROUND - 5                # segment top so its outline sits above feet row
    for x, dy in zip(seg_x, seg_dy):
        stamp(c, SEG, x, base_top + dy)
    for x, dy in zip(seg_x, seg_dy):     # legs only where a segment touches ground
        if dy == 0 and legs:
            put(c, x + 1, GROUND, "y")
            put(c, x + 4, GROUND, "y")
    hy = GROUND - 7 + head_dy
    stamp(c, ant, head_x + 4, hy - 3)
    stamp(c, head, head_x, hy)
    if head_dy == 0 and legs:
        put(c, head_x + 2, GROUND, "y")
        put(c, head_x + 5, GROUND, "y")
    if extra:
        for rows, x, y in extra:
            stamp(c, rows, x, y)
    return rows_of(c)


def make_pip():
    walk = [  # stretch -> hump (squash in x, stretch up) -> stretch: inchworm gait
        pip_frame([0, 4, 8, 12], [0, 0, 0, 0], 15, 0),
        pip_frame([2, 5, 8, 12], [0, -1, -1, 0], 15, 0),
        pip_frame([4, 6, 9, 12], [0, -2, -2, -1], 15, 0, ant=ANT_TILT),
        pip_frame([2, 5, 9, 13], [0, -1, -1, 0], 16, 0, ant=ANT_TILT),
    ]
    idle = [
        pip_frame([0, 4, 8, 12], [0, 0, 0, 0], 15, 0),
        pip_frame([0, 4, 8, 12], [0, 0, 0, 0], 15, 0, head=HEAD_BLINK),
    ]
    sleep = [
        pip_frame([1, 5, 9, 13], [0, 0, 0, 0], 16, 1, head=HEAD_SLEEP, ant=ANT_TILT,
                  extra=[(Z_SMALL, 23, 1)]),
        pip_frame([1, 5, 9, 13], [0, -1, 0, 0], 16, 1, head=HEAD_SLEEP, ant=ANT_TILT,
                  extra=[(Z_BIG, 22, 0)]),
    ]
    wave = [  # front half rears up; front foot and antenna alternate
        pip_frame([0, 4, 8, 11], [0, 0, -1, -2], 14, -3, extra=[(FOOT_UP, 21, 9), (BANG, 24, 0)]),
        pip_frame([0, 4, 8, 11], [0, 0, -1, -3], 14, -4, ant=ANT_TILT, extra=[(["yy"], 21, 9), (BANG, 24, 0)]),
        pip_frame([0, 4, 8, 11], [0, 0, -1, -2], 14, -3, extra=[(FOOT_UP, 21, 8)]),
    ]
    climb = [  # wall climb (the app rotates the sprite): grip-hump, reach, plant
        pip_frame([4, 6, 9, 12], [0, -2, -2, -1], 15, 0, ant=ANT_TILT),
        pip_frame([1, 5, 9, 13], [0, 0, 0, 0], 17, 0),
        pip_frame([0, 4, 8, 12], [0, 0, 0, 0], 15, 0),
    ]
    slide = [  # belly slide: legs tucked, antenna streaming back
        pip_frame([0, 4, 8, 12], [0, 0, 0, 0], 16, 0, ant=ANT_TILT, legs=False),
        pip_frame([0, 4, 8, 12], [0, -1, 0, 0], 16, 0, ant=ANT_TILT, legs=False),
    ]
    return {
        "id": "pip",
        "name": "Sketch A: inchworm (for discussion)",
        "palette": PIP_PALETTE,
        "size": (PIP_W, PIP_H),
        "anims": [("walk", 6, walk), ("idle", 2, idle), ("sleep", 1.5, sleep), ("wave", 5, wave),
                  ("climb", 3, climb), ("slide", 8, slide)],
    }


# ------------------------------------------------------- character: Drift
# A generic little sailor on a log raft (no specific character is depicted).
DRIFT_PALETTE = [
    ("o", "#2E2440", "outline / eye"),
    ("b", "#C08550", "wood"),
    ("B", "#7E5232", "wood shade / mast"),
    ("s", "#F6EED8", "sail"),
    ("S", "#D9CBA3", "sail shade"),
    ("p", "#E8665A", "sail patch / cap band"),
    ("h", "#B9845A", "felt cap"),
    ("f", "#F7C6A0", "skin"),
    ("r", "#3D7DD8", "shirt"),
    ("w", "#8FDDF5", "water crest"),
    ("W", "#3AA0D8", "water"),
    ("z", "#6C7BFF", "sleep z / signal"),
]

RAFT = [
    "oooooooooooooooo",
    "obbbbbbbbbbbbbbo",
    "obBbbBbbBbbBbbBo",
    ".oooooooooooooo.",
]
MAST = ["oBo"] * 10
SAIL_A = [
    "o......",
    "oso....",
    "osso...",
    "ossso..",
    "osspso.",
    "osssSSo",
    "oooooo.",
]
SAIL_B = [
    "o......",
    "oso....",
    "osso...",
    "ossso..",
    "osspSo.",
    "ossSSo.",
    "oooooo.",
]
SAILOR_SIT = [  # conical felt cap (generic ancient-sailor motif), tunic, hand on knee
    "...o....",
    "..oho...",
    ".ohhho..",
    "oppppo..",
    ".offfo..",
    ".ofofo..",
    ".orrro..",
    "orrrrfo.",
    ".orrro..",
]
SAILOR_SLEEP = [  # cap tipped over the eyes, slumped one row
    "........",
    "....o...",
    "...oho..",
    "..ohhho.",
    ".oppppo.",
    ".offfo..",
    ".orrro..",
    "orrrrro.",
    ".orrro..",
]
SAILOR_WAVE_A = [  # arm up, hand open
    "...o...ff",
    "..oho..fo",
    ".ohhho.o.",
    "oppppo.o.",
    ".offfoo..",
    ".ofofo...",
    ".orrro...",
    "orrrrro..",
    ".orrro...",
]
SAILOR_WAVE_B = [  # hand tilted the other way
    "...o..ff.",
    "..oho.of.",
    ".ohhho.o.",
    "oppppo.o.",
    ".offfoo..",
    ".ofofo...",
    ".orrro...",
    "orrrrro..",
    ".orrro...",
]
WATER_A = ["w...ww....w...ww....ww..", "WWwWWWWwWWWWWwWWWWwWWWWW"]
WATER_B = ["..ww....w...ww...w....w.", "WWWWwWWWWWwWWWWWwWWWWwWW"]

DRIFT_W, DRIFT_H = 26, 20


def drift_frame(bob, sail, sailor, water, sailor_dy=0, extra=None):
    c = canvas(DRIFT_W, DRIFT_H)
    raft_y = DRIFT_H - 6 + bob
    stamp(c, MAST, 13, raft_y - 10)
    stamp(c, sail, 15, raft_y - 10)
    stamp(c, sailor, 4, raft_y - 9 + sailor_dy)
    stamp(c, RAFT, 3, raft_y)
    stamp(c, water, 1, DRIFT_H - 2)
    if extra:
        for rows, x, y in extra:
            stamp(c, rows, x, y)
    return rows_of(c)


def make_drift():
    walk = [  # gentle 2-pixel bob, billowing sail, rolling water
        drift_frame(0, SAIL_A, SAILOR_SIT, WATER_A),
        drift_frame(-1, SAIL_A, SAILOR_SIT, WATER_A),
        drift_frame(-1, SAIL_B, SAILOR_SIT, WATER_B),
        drift_frame(0, SAIL_B, SAILOR_SIT, WATER_B),
    ]
    idle = [
        drift_frame(0, SAIL_A, SAILOR_SIT, WATER_A),
        drift_frame(0, SAIL_A, SAILOR_SIT, WATER_B),
    ]
    sleep = [
        drift_frame(0, SAIL_B, SAILOR_SLEEP, WATER_A, extra=[(Z_SMALL, 2, 0)]),
        drift_frame(-1, SAIL_B, SAILOR_SLEEP, WATER_B, extra=[(Z_BIG, 0, 0)]),
    ]
    wave = [
        drift_frame(0, SAIL_A, SAILOR_WAVE_A, WATER_A, extra=[(BANG, 1, 2)]),
        drift_frame(-1, SAIL_A, SAILOR_WAVE_B, WATER_B, extra=[(BANG, 1, 2)]),
        drift_frame(0, SAIL_B, SAILOR_WAVE_A, WATER_A),
    ]
    return {
        "id": "drift",
        "name": "Sketch B: raft sailor (for discussion)",
        "palette": DRIFT_PALETTE,
        "size": (DRIFT_W, DRIFT_H),
        "anims": [("walk", 4, walk), ("idle", 1.5, idle), ("sleep", 1.5, sleep), ("wave", 5, wave)],
    }


# ------------------------------------------------- placeholder: neutral pebble
# The shipping default until the character is designed with the requester. A plain
# slate-grey blob with one eye showing the travel direction; every pose is done
# with squash and stretch only, so it exercises the motion system without a story.
PEBBLE_PALETTE = [
    ("o", "#2E2440", "outline / eye"),
    ("b", "#9AA5B8", "body"),
    ("d", "#6B7488", "shade"),
    ("l", "#DDE2EA", "highlight"),
    ("z", "#6C7BFF", "sleep z / signal"),
]
PEB_W, PEB_H = 16, 16


def ellipse(c, cx, bottom, w, h, eye=True, eye_closed=False):
    """Outlined, shaded ellipse resting on `bottom`, centred on cx."""
    top = bottom - h + 1
    rx, ry = w / 2.0, h / 2.0
    ox, oy = int(cx) - w // 2, top
    inside = lambda x, y: ((x + 0.5 - rx) / rx) ** 2 + ((y + 0.5 - ry) / ry) ** 2 <= 1.0
    for y in range(h):
        for x in range(w):
            if not inside(x, y):
                continue
            edge = not all(inside(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                ch = "o"
            elif x < w * 0.45 and y < h * 0.4:
                ch = "l"
            elif x > w * 0.55 and y > h * 0.6:
                ch = "d"
            else:
                ch = "b"
            put(c, ox + x, oy + y, ch)
    if eye:
        ex, ey = ox + int(w * 0.68), oy + max(int(h * 0.35), 2)
        put(c, ex, ey, "o")
        if not eye_closed:
            put(c, ex, ey + 1, "o")
        else:
            put(c, ex - 1, ey, "o")


def pebble(w, h, lift=0, eye_closed=False, extra=None):
    c = canvas(PEB_W, PEB_H)
    ellipse(c, PEB_W / 2.0, PEB_H - 1 - lift, w, h, eye_closed=eye_closed)
    if extra:
        for rows, x, y in extra:
            stamp(c, rows, x, y)
    return rows_of(c)


def make_pebble():
    return {
        "id": "placeholder",
        "name": "Placeholder pebble",
        "palette": PEBBLE_PALETTE,
        "size": (PEB_W, PEB_H),
        "anims": [
            ("walk", 6, [pebble(11, 10), pebble(13, 8), pebble(11, 10), pebble(9, 12, lift=1)]),
            ("idle", 1.5, [pebble(11, 10), pebble(11, 10, eye_closed=True)]),
            ("sleep", 1.5, [pebble(13, 8, eye_closed=True, extra=[(Z_SMALL, 12, 0)]),
                             pebble(13, 9, eye_closed=True, extra=[(Z_BIG, 11, 0)])]),
            ("wave", 5, [pebble(9, 12, lift=2, extra=[(BANG, 14, 0)]), pebble(11, 10, extra=[(BANG, 14, 0)]),
                         pebble(13, 8)]),
            ("climb", 3, [pebble(9, 12), pebble(11, 10), pebble(13, 8)]),
            ("slide", 8, [pebble(14, 7), pebble(14, 7, lift=1)]),
        ],
    }


# ------------------------------------------------------------------- writers
def write_sprite(ch, folder="characters"):
    w, h = ch["size"]
    out = [
        "# Edge Odyssey sprite v1 - hand-drawn pixel grid. Edit freely; see PROVENANCE.md.",
        f"name: {ch['name']}",
        f"size: {w}x{h}",
        "palette:",
    ]
    for key, hexv, note in ch["palette"]:
        out.append(f"  {key} {hexv}  # {note}")
    for anim, fps, frames in ch["anims"]:
        out.append(f"anim: {anim} fps={fps}")
        for fr in frames:
            assert len(fr) == h and all(len(r) == w for r in fr), (ch["id"], anim)
            out.append("frame:")
            out.extend("  " + r for r in fr)
    os.makedirs(os.path.join(ASSETS, folder), exist_ok=True)
    path = os.path.join(ASSETS, folder, ch["id"] + ".sprite")
    with open(path, "w") as f:
        f.write("\n".join(out) + "\n")
    return path


def png(path, pixels, w, h):
    raw = b"".join(b"\x00" + bytes(sum((pixels[y][x] for x in range(w)), ())) for y in range(h))
    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
    data += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(data)


def write_sheet(ch, scale, bg=None):
    """One row per animation, frames left to right, nearest-neighbour scaled."""
    w, h = ch["size"]
    pal = {k: tuple(int(v[i:i + 2], 16) for i in (1, 3, 5)) + (255,) for k, v, _ in ch["palette"]}
    cols = max(len(fr) for _, _, fr in ch["anims"])
    pad = 2
    W = (cols * (w + pad) + pad) * scale
    H = (len(ch["anims"]) * (h + pad) + pad) * scale
    clear = bg + (255,) if bg else (0, 0, 0, 0)
    px = [[clear] * W for _ in range(H)]
    for r, (_, _, frames) in enumerate(ch["anims"]):
        for i, fr in enumerate(frames):
            ox, oy = (pad + i * (w + pad)) * scale, (pad + r * (h + pad)) * scale
            for y, row in enumerate(fr):
                for x, k in enumerate(row):
                    if k == ".":
                        continue
                    for dy in range(scale):
                        for dx in range(scale):
                            px[oy + y * scale + dy][ox + x * scale + dx] = pal[k]
    suffix = f"@{scale}x" + ("-on-light" if bg else "")
    path = os.path.join(ASSETS, "previews", f"{ch['id']}-sheet{suffix}.png")
    png(path, px, W, H)
    return path


if __name__ == "__main__":
    for ch, folder in ((make_pebble(), "sketches"), (make_pip(), "sketches"), (make_drift(), "sketches")):
        print(write_sprite(ch, folder))
        for s in (1, 2, 3):
            print(write_sheet(ch, s))
        print(write_sheet(ch, 8, bg=(238, 240, 244)))
