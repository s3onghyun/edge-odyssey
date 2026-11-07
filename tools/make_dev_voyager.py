#!/usr/bin/env python3
"""Developer Voyager - a present-day traveler for Edge Odyssey.

A coder in a hoodie and headphones sails a small dinghy over a "terminal sea": stepped block
waves with phosphor prompt chevrons and a cursor block. Every shape is an SVG primitive placed
by hand in this file. No image generation, no traced or third-party art, no fonts in frames
(glyphs such as ">" are drawn as paths).

The boat sails every edge, turning at the corners (the app rotates it), so there are no
climb, cling or slide frames; and no Odyssey episode props (ep-*), so this character has no
mythic encounters. Frames use the app's vector-character canvas: 32x26 units, 1 unit = 1 pt.
Run:  python3 tools/make_dev_voyager.py   -> assets/characters/dev-voyager/
"""
import os

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "..", "assets", "characters", "dev-voyager")
W, H = 32, 26
C = {
    "o": "#2A1F33",   # outline (same ink as Odysseus)
    "s": "#F2C29B",   # skin
    "S": "#C98E6B",   # skin shade
    "hr": "#3A2B2E",  # hair
    "hd": "#2F6F73",  # hoodie
    "HD": "#22525A",  # hoodie shade
    "dc": "#F4EAD2",  # drawstrings, mug
    "a": "#F08A4B",   # accent: headphones, sail stripe, sneakers
    "A": "#B8602F",   # accent shade
    "j": "#3E4D6E",   # jeans
    "lp": "#D3D8E0",  # laptop aluminium
    "LP": "#8E97A6",  # laptop shade
    "g": "#7EE8A8",   # phosphor: screen, prompt glyphs
    "hu": "#F1ECE2",  # hull
    "HU": "#C9C0AE",  # hull shade
    "sl": "#FBF8F1",  # sail
    "ms": "#4F4A55",  # mast, boom
    "n": "#16222E",   # terminal sea
    "m": "#3A5872",   # block crests: keeps the sea edge visible on a dark desktop
    "f": "#DDEBE6",   # foam blocks
    "k": "#7C8299",   # storm cloud
    "K": "#4A4F66",   # cloud shade
    "p": "#9CC3F0",   # rain
    "z": "#8A96FF",   # sleep z
    "P": "#F5A3B5",   # blush
    "ph": "#9FC4FF",  # phone glow
    "wd": "#8A5530",  # pier wood
    "WD": "#4F2F1C",  # pier shade
    "br": "#E8C47A",  # lamp (brass, as the app's arrival colour)
}
OL = f'stroke="{C["o"]}" stroke-width="0.8" stroke-linejoin="round"'


def svg(body, w=W, h=H):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}">{body}</svg>'


def line(pts, color, width, cap="round"):
    d = "M" + " L".join(f"{x:.2f} {y:.2f}" for x, y in pts)
    return f'<path d="{d}" fill="none" stroke="{color}" stroke-width="{width}" stroke-linecap="{cap}" stroke-linejoin="round"/>'


def limb(pts, color, width=1.3):
    """Outlined limb: dark stroke under a coloured one."""
    return line(pts, C["o"], width + 0.8) + line(pts, color, width)


def hand(x, y, r=0.75):
    return f'<circle cx="{x}" cy="{y}" r="{r}" fill="{C["s"]}" {OL}/>'


# ------------------------------------------------------------------ sea, boat, props

def sea(phase=0, rough=False, glyphs=True, top=23.4):
    """Terminal sea: stepped block waves (like the bar glyphs of a terminal), a prompt
    chevron every 8 units and one cursor block. phase 0..3 shifts the pattern."""
    hs = [0, 0.45, 0.9, 0.45] if not rough else [0, 0.9, 1.8, 0.9]
    o = [f'<rect x="0" y="{top}" width="{W}" height="{H - top}" fill="{C["n"]}"/>']
    for i in range(16):
        h = hs[(i + phase) % 4]
        if h:
            o.append(f'<rect x="{i * 2}" y="{top - h:.2f}" width="2.02" height="{h + 0.05:.2f}" fill="{C["n"]}"/>')
        o.append(f'<rect x="{i * 2}" y="{top - h:.2f}" width="2.02" height="0.4" fill="{C["m"]}"/>')
    if glyphs:
        for i in range(4):
            x = (i * 8 + phase * 2 + 2) % W
            y = top + 0.9
            o.append(line([(x, y), (x + 0.8, y + 0.55), (x, y + 1.1)], C["g"], 0.42))
        cx = (phase * 2 + 13) % W
        if phase % 2 == 0:   # the cursor blinks every other frame
            o.append(f'<rect x="{cx}" y="{top + 0.75}" width="0.75" height="1.3" fill="{C["g"]}"/>')
    return "".join(o)


def wake(x, y, phase=0):
    xs = [x, x - 1.6, x - 3.0][: 3 - phase % 2]
    return "".join(f'<rect x="{xx:.2f}" y="{y - (k % 2) * 0.5:.2f}" width="0.8" height="0.6" fill="{C["f"]}"/>'
                   for k, xx in enumerate(xs))


def hull(x=6, y=19, tilt=0):
    """Small modern dinghy: off-white hull, accent stripe, raised bow on the right."""
    return (f'<g transform="rotate({tilt} {x + 10} {y + 2})">'
            f'<path d="M{x} {y} L{x + 19} {y} Q{x + 20.3} {y - 0.2} {x + 20.6} {y - 1.5} '
            f'Q{x + 20.8} {y + 1.6} {x + 17.8} {y + 3.6} L{x + 2.6} {y + 3.6} Q{x + 0.6} {y + 2.2} {x} {y} Z" '
            f'fill="{C["hu"]}" {OL}/>'
            f'<path d="M{x + 0.9} {y + 1.5} L{x + 19.6} {y + 1.5}" stroke="{C["a"]}" stroke-width="0.75"/>'
            f'<path d="M{x + 2.4} {y + 3.0} L{x + 17.6} {y + 3.0}" stroke="{C["HU"]}" stroke-width="0.5"/></g>')


def mast(x=20.5, top=2.6, sail="full"):
    """Mast with a triangular (bermuda) sail to the right of it: full, slack or furled."""
    o = [line([(x, top), (x, 19.2)], C["ms"], 0.9)]
    boom_y = 16.6
    if sail == "full":
        o.append(f'<path d="M{x + 0.4} {top + 0.6} Q{x + 6.2} {top + 7} {x + 7.6} {boom_y - 0.3} L{x + 0.4} {boom_y - 0.3} Z" '
                 f'fill="{C["sl"]}" {OL}/>')
        o.append(line([(x + 0.6, boom_y - 3.2), (x + 6.6, boom_y - 3.2)], C["a"], 0.6, "butt"))
    elif sail == "slack":
        o.append(f'<path d="M{x + 0.4} {top + 0.6} Q{x + 3.2} {top + 8} {x + 6.6} {boom_y - 0.3} L{x + 0.4} {boom_y - 0.3} '
                 f'Q{x + 1.6} {top + 8} {x + 0.4} {top + 0.6} Z" fill="{C["sl"]}" {OL}/>')
        o.append(line([(x + 1.2, boom_y - 3.2), (x + 5.4, boom_y - 3.2)], C["a"], 0.6, "butt"))
    o.append(line([(x - 0.6, boom_y), (x + 8.2, boom_y)], C["ms"], 0.8))
    if sail == "furled":
        o.append(f'<rect x="{x + 0.6}" y="{boom_y - 1.5}" width="7.2" height="1.4" rx="0.7" fill="{C["sl"]}" {OL}/>')
        o.append(line([(x + 3.0, boom_y - 1.6), (x + 3.0, boom_y - 0.1)], C["a"], 0.5, "butt"))
        o.append(line([(x + 5.6, boom_y - 1.6), (x + 5.6, boom_y - 0.1)], C["a"], 0.5, "butt"))
    return "".join(o)


def laptop_open(hx, hy, glow=True, lid=1.0):
    """Side view, screen toward the user on the left. (hx, hy) = hinge. lid = 1 open, 0.4 half shut."""
    lx, ly = hx + 1.3 * lid, hy - 4.1 * lid + (1 - lid) * 0.9
    if lid < 0.6:
        lx, ly = hx - 2.6, hy - 1.9
    o = []
    if glow:   # light cone from the screen onto the face
        o.append(f'<path d="M{hx - 0.3} {hy - 0.2} L{lx - 0.3} {ly} L{hx - 5.2} {ly + 0.8} L{hx - 4.4} {hy - 0.4} Z" '
                 f'fill="{C["g"]}" opacity="0.18"/>')
    o.append(f'<path d="M{hx - 4.6} {hy} L{hx + 0.3} {hy} L{hx + 0.3} {hy + 0.6} L{hx - 4.6} {hy + 0.6} Z" fill="{C["lp"]}" {OL}/>')
    o.append(f'<path d="M{hx} {hy + 0.1} L{lx} {ly} L{lx + 0.6} {ly + 0.1} L{hx + 0.6} {hy + 0.2} Z" fill="{C["lp"]}" {OL}/>')
    if glow:
        o.append(line([(hx - 0.15, hy - 0.4), (lx + 0.05, ly + 0.5)], C["g"], 0.4))
    return "".join(o)


def laptop_closed(x, y, w=4.6, angle=0):
    return (f'<g transform="rotate({angle} {x + w / 2} {y})"><rect x="{x}" y="{y - 0.5}" width="{w}" height="1.0" rx="0.3" '
            f'fill="{C["lp"]}" {OL}/><path d="M{x + 0.3} {y} L{x + w - 0.3} {y}" stroke="{C["LP"]}" stroke-width="0.3"/></g>')


def mug(x, y, steam=True):
    o = [f'<path d="M{x} {y} L{x + 1.5} {y} L{x + 1.35} {y + 1.8} L{x + 0.15} {y + 1.8} Z" fill="{C["dc"]}" {OL}/>',
         line([(x + 0.1, y + 0.75), (x + 1.4, y + 0.75)], C["a"], 0.4, "butt")]
    if steam:
        o.append(f'<path d="M{x + 0.5} {y - 0.5} q-0.5 -0.7 0 -1.3 q0.5 -0.6 0 -1.2" fill="none" stroke="{C["f"]}" stroke-width="0.35" stroke-linecap="round"/>')
    return "".join(o)


def phone(x, y):
    return (f'<path d="M{x} {y} L{x + 1.4} {y - 0.4} L{x + 1.4} {y - 3.0} L{x} {y - 2.6} Z" fill="{C["ph"]}" opacity="0.25"/>'
            f'<rect x="{x - 0.5}" y="{y - 2.2}" width="0.9" height="2.0" rx="0.25" fill="{C["ms"]}" {OL.replace("0.8", "0.45")}/>'
            f'<rect x="{x - 0.3}" y="{y - 2.0}" width="0.5" height="1.6" fill="{C["ph"]}"/>')


def cloud(x, y):
    return (f'<path d="M{x} {y + 3} Q{x - 1.2} {y + 1.2} {x + 1} {y + 0.8} Q{x + 1.8} {y - 1.2} {x + 4.2} {y - 0.2} '
            f'Q{x + 6.4} {y - 0.8} {x + 6.8} {y + 1.2} Q{x + 8.6} {y + 1.6} {x + 7.8} {y + 3} Z" fill="{C["k"]}" {OL}/>'
            f'<path d="M{x + 0.6} {y + 2.4} L{x + 7.2} {y + 2.4}" stroke="{C["K"]}" stroke-width="0.6"/>')


def rain(x, y, phase=0):
    o = []
    for i, (dx, dy) in enumerate([(0.6, 0), (2.8, 1.2), (5.0, 0.4), (7.0, 1.6), (1.6, 2.6), (4.2, 3.0)]):
        yy = y + dy + (phase % 2) * 0.8
        o.append(line([(x + dx, yy), (x + dx - 0.4, yy + 1.0)], C["p"], 0.45))
    return "".join(o)


def zs(x, y):
    return "".join(line([(x + dx, y + dy), (x + dx + s, y + dy), (x + dx, y + dy + s), (x + dx + s, y + dy + s)], C["z"], 0.4)
                   for dx, dy, s in [(0, 0, 0.9), (1.4, -1.8, 1.2)])


def pier():
    return (f'<rect x="25.2" y="17.6" width="7.2" height="1.2" fill="{C["wd"]}" {OL}/>'
            f'<path d="M26.6 18.8 L26.6 25 M30.6 18.8 L30.6 25" stroke="{C["WD"]}" stroke-width="1.0"/>'
            f'<rect x="25.6" y="15.6" width="1.1" height="2.2" rx="0.4" fill="{C["WD"]}" {OL}/>'
            + line([(29.4, 17.6), (29.4, 9.6), (30.6, 9.6)], C["ms"], 0.6)
            + f'<circle cx="30.6" cy="10.6" r="2.4" fill="{C["br"]}" opacity="0.28"/>'
            f'<rect x="30.0" y="9.9" width="1.2" height="1.4" rx="0.3" fill="{C["br"]}" {OL.replace("0.8", "0.5")}/>')


def prompt_bubble(x, y, cursor=True):
    """Speech bubble with a prompt: the agent is waiting for your answer."""
    o = [f'<path d="M{x} {y} L{x + 7} {y} Q{x + 7.8} {y} {x + 7.8} {y + 0.8} L{x + 7.8} {y + 3.2} Q{x + 7.8} {y + 4} {x + 7} {y + 4} '
         f'L{x + 2.2} {y + 4} L{x + 0.8} {y + 5.4} L{x + 1.1} {y + 4} L{x} {y + 4} Q{x - 0.8} {y + 4} {x - 0.8} {y + 3.2} '
         f'L{x - 0.8} {y + 0.8} Q{x - 0.8} {y} {x} {y} Z" fill="{C["n"]}" {OL}/>',
         line([(x + 0.4, y + 1.2), (x + 1.6, y + 2.0), (x + 0.4, y + 2.8)], C["g"], 0.55)]
    if cursor:
        o.append(f'<rect x="{x + 2.6}" y="{y + 1.0}" width="1.0" height="2.0" fill="{C["g"]}"/>')
    return "".join(o)


# ------------------------------------------------------------------ head

def eyes_side(ex, ey, expr):
    o = C["o"]
    if expr in ("neutral", "listen"):
        return (f'<ellipse cx="{ex}" cy="{ey}" rx="0.45" ry="0.6" fill="{o}"/>'
                f'<circle cx="{ex - 0.12}" cy="{ey - 0.22}" r="0.15" fill="#fff"/>')
    if expr == "focused":
        return (f'<ellipse cx="{ex}" cy="{ey + 0.1}" rx="0.45" ry="0.45" fill="{o}"/>'
                f'<circle cx="{ex + 0.1}" cy="{ey - 0.05}" r="0.15" fill="{C["g"]}"/>'
                + line([(ex - 0.7, ey - 0.45), (ex + 0.6, ey - 0.35)], o, 0.4))
    if expr == "alert":
        return (f'<ellipse cx="{ex}" cy="{ey}" rx="0.6" ry="0.8" fill="#fff" stroke="{o}" stroke-width="0.35"/>'
                f'<circle cx="{ex + 0.12}" cy="{ey + 0.05}" r="0.36" fill="{o}"/>'
                + line([(ex - 0.6, ey - 1.35), (ex + 0.6, ey - 1.55)], o, 0.4))
    if expr in ("happy", "call"):
        return line([(ex - 0.55, ey + 0.25), (ex, ey - 0.35), (ex + 0.55, ey + 0.25)], o, 0.45)
    if expr in ("proud", "sleep", "bob"):
        return line([(ex - 0.55, ey - 0.1), (ex, ey + 0.35), (ex + 0.55, ey - 0.1)], o, 0.45)
    if expr == "worried":
        return (f'<ellipse cx="{ex}" cy="{ey + 0.1}" rx="0.42" ry="0.55" fill="{o}"/>'
                f'<circle cx="{ex - 0.1}" cy="{ey - 0.1}" r="0.14" fill="#fff"/>'
                + line([(ex - 0.7, ey - 1.05), (ex + 0.55, ey - 1.45)], o, 0.4))
    if expr == "dazed":
        return (f'<ellipse cx="{ex}" cy="{ey + 0.15}" rx="0.45" ry="0.4" fill="{o}"/>'
                + line([(ex - 0.6, ey - 0.1), (ex + 0.6, ey - 0.1)], C["s"], 0.5, "butt")
                + line([(ex - 0.6, ey - 0.15), (ex + 0.6, ey - 0.15)], o, 0.35))
    raise ValueError(expr)


def mouth_side(mx, my, expr):
    o = C["o"]
    if expr in ("neutral", "listen", "bob"):
        return line([(mx - 0.5, my), (mx + 0.2, my + 0.15)], o, 0.35)
    if expr in ("focused", "dazed"):
        return line([(mx - 0.4, my + 0.05), (mx + 0.3, my + 0.05)], o, 0.35)
    if expr in ("happy", "proud"):
        return f'<path d="M{mx - 0.7} {my - 0.1} Q{mx} {my + 0.9} {mx + 0.5} {my - 0.2} Z" fill="{o}"/>'
    if expr == "call":
        return f'<ellipse cx="{mx}" cy="{my + 0.25}" rx="0.5" ry="0.65" fill="{o}"/>'
    if expr == "alert":
        return f'<circle cx="{mx}" cy="{my + 0.2}" r="0.35" fill="{o}"/>'
    if expr == "worried":
        return line([(mx - 0.6, my + 0.2), (mx - 0.2, my - 0.05), (mx + 0.2, my + 0.2), (mx + 0.5, my)], o, 0.33)
    if expr == "sleep":
        return f'<ellipse cx="{mx - 0.1}" cy="{my + 0.15}" rx="0.3" ry="0.22" fill="{o}"/>'
    raise ValueError(expr)


def head_side(cx, cy, expr="neutral", gear="phones", tilt=0, glow=None, cup_off=False):
    """Profile facing right, r = 3.4. gear: phones | beanie | hood."""
    r = 3.4
    o = [f'<g transform="rotate({tilt} {cx} {cy + 2})">']
    if gear == "hood":   # hood up: a soft shell around the head
        o.append(f'<path d="M{cx - 4.3} {cy + 3.6} Q{cx - 4.9} {cy - 3.6} {cx + 0.2} {cy - 4.4} Q{cx + 4.1} {cy - 4.2} {cx + 4.0} {cy - 0.6} '
                 f'L{cx + 2.6} {cy + 3.6} Z" fill="{C["hd"]}" {OL}/>')
    o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{C["s"]}" {OL}/>')
    # hair: cap over the back and top, a fringe tuft at the front
    if gear != "hood":
        o.append(f'<path d="M{cx - 3.3} {cy + 1.4} Q{cx - 3.9} {cy - 3.2} {cx - 0.2} {cy - 3.6} Q{cx + 2.4} {cy - 3.8} {cx + 3.4} {cy - 1.4} '
                 f'L{cx + 2.5} {cy - 2.0} L{cx + 2.2} {cy - 1.4} L{cx + 1.0} {cy - 2.1} Q{cx - 0.8} {cy - 1.0} {cx - 1.6} {cy + 1.3} Z" '
                 f'fill="{C["hr"]}" {OL}/>')
    else:
        o.append(f'<path d="M{cx - 2.6} {cy - 2.2} Q{cx} {cy - 3.6} {cx + 2.8} {cy - 1.6} L{cx + 1.6} {cy - 1.2} L{cx + 0.8} {cy - 1.9} '
                 f'Q{cx - 1} {cy - 1.2} {cx - 2.6} {cy - 2.2} Z" fill="{C["hr"]}"/>')
    if gear == "beanie":
        o.append(f'<path d="M{cx - 3.5} {cy - 0.4} Q{cx - 3.4} {cy - 4.6} {cx + 0.2} {cy - 4.5} Q{cx + 3.6} {cy - 4.3} {cx + 3.4} {cy - 1.2} Z" '
                 f'fill="{C["a"]}" {OL}/>')
        o.append(f'<path d="M{cx - 3.6} {cy - 0.8} Q{cx} {cy - 2.6} {cx + 3.5} {cy - 1.3}" fill="none" stroke="{C["A"]}" stroke-width="1.0"/>')
    # face
    ex, ey = cx + 1.75, cy + 0.15
    o.append(eyes_side(ex, ey, expr))
    if expr not in ("sleep", "dazed", "focused"):
        o.append(f'<circle cx="{cx + 1.2}" cy="{cy + 1.35}" r="0.6" fill="{C["P"]}" opacity="0.85"/>')
    o.append(mouth_side(cx + 2.55, cy + 1.75, expr))
    o.append(f'<path d="M{cx + 3.3} {cy + 0.4} q0.5 0.4 0.1 0.9" fill="none" stroke="{C["S"]}" stroke-width="0.4" stroke-linecap="round"/>')
    if expr == "worried":
        o.append(f'<path d="M{cx + 3.6} {cy - 1.8} q0.5 0.8 0 1.1 q-0.5 -0.3 0 -1.1 Z" fill="{C["p"]}"/>')
    if glow:   # rim light on the front of the face from the screen (green) or the phone (blue)
        o.append(f'<path d="M{cx + 1.6} {cy - 2.6} A{r - 0.5} {r - 0.5} 0 0 1 {cx + 1.4} {cy + 2.6}" fill="none" '
                 f'stroke="{C["g"] if glow == "screen" else C["ph"]}" stroke-width="0.55" stroke-linecap="round" opacity="0.9"/>')
    # headphones: band over the top, the near cup over the ear
    if gear in ("phones", "hood"):
        if gear == "phones":
            o.append(f'<path d="M{cx - 1.4} {cy + 0.8} Q{cx - 2.8} {cy - 4.6} {cx + 0.4} {cy - 4.3}" fill="none" stroke="{C["o"]}" stroke-width="1.6" stroke-linecap="round"/>')
            o.append(f'<path d="M{cx - 1.4} {cy + 0.8} Q{cx - 2.8} {cy - 4.6} {cx + 0.4} {cy - 4.3}" fill="none" stroke="{C["a"]}" stroke-width="0.8" stroke-linecap="round"/>')
        if cup_off:
            o.append(f'<rect x="{cx - 2.8}" y="{cy - 0.6}" width="2.0" height="2.8" rx="0.9" fill="{C["a"]}" {OL} transform="rotate(-25 {cx - 1.8} {cy + 0.8})"/>')
        elif gear == "phones":
            o.append(f'<rect x="{cx - 2.3}" y="{cy - 0.6}" width="2.0" height="2.8" rx="0.9" fill="{C["a"]}" {OL}/>')
            o.append(f'<rect x="{cx - 1.9}" y="{cy - 0.1}" width="0.6" height="1.8" rx="0.3" fill="{C["A"]}"/>')
    o.append("</g>")
    return "".join(o)


def head_front(cx, cy, expr="neutral", view="front", gear="phones"):
    r = 3.4
    o = []
    if view == "back":
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{C["hr"]}" {OL}/>')
        o.append(f'<path d="M{cx - 2.2} {cy + 2.6} Q{cx} {cy + 1.6} {cx + 2.2} {cy + 2.6}" fill="none" stroke="{C["o"]}" stroke-width="0.4"/>')
    else:
        o.append(f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{C["s"]}" {OL}/>')
        o.append(f'<path d="M{cx - 3.4} {cy + 0.6} Q{cx - 3.8} {cy - 3.8} {cx} {cy - 3.6} Q{cx + 3.8} {cy - 3.8} {cx + 3.4} {cy + 0.6} '
                 f'L{cx + 2.6} {cy - 1.2} L{cx + 1.4} {cy - 0.6} L{cx + 0.7} {cy - 1.6} L{cx - 0.6} {cy - 0.7} L{cx - 1.6} {cy - 1.5} '
                 f'L{cx - 2.7} {cy - 0.9} Z" fill="{C["hr"]}" {OL}/>')
        for sx in (-1, 1):
            o.append(eyes_side(cx + sx * 1.3, cy + 0.5, expr))
            o.append(f'<circle cx="{cx + sx * 2.1}" cy="{cy + 1.6}" r="0.55" fill="{C["P"]}" opacity="0.85"/>')
        o.append(mouth_side(cx + 0.15, cy + 2.0, expr))
    if gear == "phones":
        o.append(f'<path d="M{cx - 3.5} {cy} Q{cx - 3.8} {cy - 4.9} {cx} {cy - 4.9} Q{cx + 3.8} {cy - 4.9} {cx + 3.5} {cy}" fill="none" stroke="{C["o"]}" stroke-width="1.6"/>')
        o.append(f'<path d="M{cx - 3.5} {cy} Q{cx - 3.8} {cy - 4.9} {cx} {cy - 4.9} Q{cx + 3.8} {cy - 4.9} {cx + 3.5} {cy}" fill="none" stroke="{C["a"]}" stroke-width="0.8"/>')
        for sx in (-1, 1):
            o.append(f'<rect x="{cx + sx * 3.6 - 0.9}" y="{cy - 0.6}" width="1.8" height="2.8" rx="0.8" fill="{C["a"]}" {OL}/>')
    return "".join(o)


# ------------------------------------------------------------------ seated body (profile)

HIP = (11.6, 19.2)


def torso_side(lean=0, hood_up=False):
    x, y = HIP
    return (f'<path d="M{x - 3.4} {y - 5.0} Q{x - 3.6} {y - 6.4} {x - 1.6} {y - 6.0} L{x - 0.6} {y - 5.2} Z" fill="{C["HD"]}" {OL}/>'
            f'<path d="M{x - 2.4} {y - 5.5} Q{x} {y - 6.2} {x + 1.9} {y - 5.4} L{x + 2.6} {y + 0.2} L{x - 3.0} {y + 0.2} Z" '
            f'fill="{C["hd"]}" {OL}/>'
            + ("" if hood_up else line([(x + 1.1, y - 5.3), (x + 1.3, y - 3.9)], C["dc"], 0.3))
            + line([(x + 2.3, y - 1.3), (x - 0.4, y - 1.3)], C["HD"], 0.45))


def thigh(knee=(15.4, 16.9)):
    return limb([(HIP[0] + 0.6, HIP[1] - 0.6), knee, (knee[0] + 0.8, 20.0)], C["j"], 1.7)


def seated(head, arms_back, arms_front, lean=0, props_mid="", hood_up=False, knee=(15.4, 16.9)):
    x, y = HIP
    return (f'<g transform="rotate({lean} {x} {y})">{arms_back}{torso_side(hood_up=hood_up)}{head}</g>'
            f'{thigh(knee)}{props_mid}<g transform="rotate({lean} {x} {y})">{arms_front}</g>')


SH_F, SH_B = (12.6, 15.0), (11.6, 14.8)   # near / far shoulder


def frame(*parts):
    return svg("".join(parts))


# ------------------------------------------------------------------ poses
HEAD = (11.6, 10.2)


def typing(step=0, gear="phones", expr="focused"):
    hf = (16.4, 15.6 + 0.35 * (step % 2))
    hb = (15.3, 15.9 - 0.35 * (step % 2))
    return seated(head_side(*HEAD, expr, gear, glow="screen"),
                  limb([SH_B, (13.0, 17.0), hb], C["HD"]) + hand(*hb),
                  limb([SH_F, (14.0, 17.2), hf], C["hd"]) + hand(*hf),
                  lean=4, props_mid=laptop_open(18.3, 16.1))


def walk(step=0, gear="phones"):
    """Working / focus timer running: sails and types; sea glyphs scroll."""
    return frame(mast(), typing(step, gear), hull(), wake(5.0, 24.2, step), sea(step))


def idle_base(gear="phones"):
    hb, hf = (15.0, 16.0), (16.0, 16.2)
    return frame(mast(sail="slack"),
                 seated(head_side(*HEAD, "neutral", gear),
                        limb([SH_B, (12.6, 17.4), hb], C["HD"]) + hand(*hb),
                        limb([SH_F, (13.6, 17.6), hf], C["hd"]) + hand(*hf),
                        lean=-2, props_mid=laptop_open(18.3, 16.1, glow=False)),
                 hull(), sea(0))


def habit_coffee(k):
    lift = k == 1
    hf = (14.6, 12.6) if lift else (15.4, 14.6)
    m = mug(hf[0] - 0.2, hf[1] - 1.4, steam=True) if lift else mug(hf[0] - 0.2, hf[1] - 1.2)
    hb = (15.2, 16.0)
    return frame(mast(sail="slack"),
                 seated(head_side(*HEAD, "proud" if lift else "neutral", tilt=-6 if lift else 0),
                        limb([SH_B, (12.8, 17.4), hb], C["HD"]) + hand(*hb),
                        limb([SH_F, (13.8, 16.6), hf], C["hd"]) + m + hand(*hf),
                        lean=-3, props_mid=laptop_open(18.3, 16.1, glow=False)),
                 hull(), sea(1))


def habit_stretch(k):
    if k == 0:
        hf, hb, ef, eb = (13.6, 4.8), (10.6, 4.6), (14.6, 9.6), (9.4, 9.8)
    else:
        hf, hb, ef, eb = (17.2, 7.6), (6.4, 7.8), (15.6, 11.6), (8.0, 11.8)
    return frame(mast(sail="slack"),
                 seated(head_side(*HEAD, "sleep" if k == 0 else "happy", tilt=-8),
                        limb([SH_B, eb, hb], C["HD"]) + hand(*hb),
                        limb([SH_F, ef, hf], C["hd"]) + hand(*hf),
                        lean=-6, props_mid=laptop_open(18.3, 16.1, glow=False)),
                 hull(), sea(2))


def habit_headphones(k):
    """Hand on the ear cup, head bobbing to the music."""
    tilt = -7 if k == 0 else 7
    cup = (HEAD[0] - 1.3, HEAD[1] + 1.0)
    hb = (15.4, 16.0)
    marks = "".join(f'<path d="M{HEAD[0] - 5.2 - i * 0.9} {HEAD[1] - 1 + i * 0.2} q-0.6 1.3 0 2.6" fill="none" stroke="{C["a"]}" stroke-width="0.4" stroke-linecap="round" opacity="{0.9 - i * 0.35}"/>' for i in range(2))
    return frame(mast(sail="slack"),
                 seated(head_side(*HEAD, "bob", tilt=tilt) + marks,
                        limb([SH_B, (12.8, 17.4), hb], C["HD"]) + hand(*hb),
                        limb([SH_F, (11.2, 15.4), cup], C["hd"]) + hand(*cup),
                        lean=-2, props_mid=laptop_open(18.3, 16.1, glow=False)),
                 hull(), sea(3))


def sirens(k=0):
    """Agent waiting for you: turns to you, waves, and the prompt bubble blinks."""
    cx = 12.4
    wave = (17.6, 8.0) if k == 0 else (16.4, 7.4)
    body = (f'<path d="M{cx - 3.0} 14.2 Q{cx} 13.2 {cx + 3.0} 14.2 L{cx + 3.4} 19.4 L{cx - 3.4} 19.4 Z" fill="{C["hd"]}" {OL}/>'
            + line([(cx - 0.6, 14.0), (cx - 0.7, 15.4)], C["dc"], 0.3) + line([(cx + 0.6, 14.0), (cx + 0.7, 15.4)], C["dc"], 0.3))
    return frame(mast(sail="slack"),
                 limb([(cx - 2.6, 15.0), (cx - 4.0, 17.2), (cx - 2.4, 18.0)], C["HD"]),
                 body, head_front(cx, 10.0, "call"),
                 limb([(cx + 2.6, 14.8), (wave[0] - 0.4, 11.6), wave], C["hd"]) + hand(*wave),
                 prompt_bubble(19.6 + (k * 0.0), 4.6, cursor=(k == 0)),
                 hull(), sea(0, glyphs=True))


def storm(k=0):
    """Near the usage limit: rain, sail furled, hood up, the laptop hugged dry."""
    x, y = HIP
    hug = laptop_closed(12.0, 16.2, 4.4, angle=-20)
    return frame(cloud(17.4, 1.6), rain(17.8, 5.2, k), mast(sail="furled"),
                 seated(head_side(HEAD[0] + 0.3, HEAD[1] + 0.6, "worried", "hood", tilt=6),
                        limb([SH_B, (13.6, 17.8), (15.0, 15.8)], C["HD"]),
                        hug + limb([SH_F, (14.4, 17.6), (15.6, 15.2)], C["hd"]) + hand(15.6, 15.2),
                        lean=10, hood_up=True, knee=(15.0, 17.2)),
                 hull(tilt=-3 if k % 2 else 3), sea(k, rough=True))


def ithaca(k=0):
    """Arrived (focus done, or a short break): moored at a lit pier, laptop shut, arms up."""
    up = k == 0
    hf, hb = ((15.2, 5.2), (8.0, 5.0)) if up else ((16.6, 11.6), (6.8, 11.8))
    ef, eb = ((15.2, 10.4), (8.6, 10.2)) if up else ((15.0, 13.2), (8.6, 13.4))
    return frame(f'<g transform="translate(0.6 0)">{pier()}</g>',
                 f'<g transform="translate(-3 0)">', mast(sail="furled"),
                 seated(head_side(*HEAD, "proud" if up else "happy", tilt=-5),
                        limb([SH_B, eb, hb], C["HD"]) + hand(*hb),
                        limb([SH_F, ef, hf], C["hd"]) + hand(*hf),
                        lean=-4, props_mid=laptop_closed(13.8, 16.0, 4.4, angle=-8)),
                 hull(), '</g>', line([(23.2, 19.6), (26.6, 16.8)], C["WD"], 0.45), sea(0, glyphs=False))


def rest(k=0):
    """Long break: lies back across the boat, headphones on, laptop shut on the chest."""
    breathe = 0.3 if k else 0
    body = (limb([(13.0, 18.0), (17.6, 16.6), (21.6, 18.4)], C["j"], 1.7)
            + f'<path d="M7.6 {16.8 - breathe} Q10.4 {15.4 - breathe} 13.6 {16.4 - breathe} L13.6 18.8 L7.6 18.8 Z" fill="{C["hd"]}" {OL}/>'
            + laptop_closed(8.6, 15.6 - breathe, 4.2, angle=-6))
    head = head_side(5.6, 15.0, "sleep", tilt=-70)
    arm = limb([(8.4, 16.4), (6.4, 12.4), (4.4, 13.6)], C["hd"])
    return frame(mast(sail="furled"), arm, head, body, zs(8.4, 8.6 - k * 0.6), hull(), sea(k, glyphs=False))


def doze(k=0):
    """A distracting app in front (the Lotus-eaters): slumped, scrolling a phone, laptop half shut."""
    ph = (15.0, 12.0 + 0.3 * k)
    return frame(mast(sail="slack"),
                 seated(head_side(*HEAD, "dazed", tilt=10, glow="phone"),
                        limb([SH_B, (12.4, 17.6), (14.6, 16.6)], C["HD"]),
                        limb([SH_F, (13.8, 16.0), ph], C["hd"]) + phone(ph[0] + 0.3, ph[1] + 0.2) + hand(*ph),
                        lean=-8, props_mid=laptop_open(18.3, 16.1, glow=False, lid=0.4)),
                 hull(tilt=2), sea(k, glyphs=False))


# ------------------------------------------------------------------ animations the app plays

# (name, fps, frames). Edges and episodes are left out on purpose (see the module docstring).
ANIMS = [
    ("walk", 5, [lambda i=i: walk(i) for i in range(4)]),
    ("idle", 2.5, [idle_base, lambda: habit_coffee(0), lambda: habit_coffee(1), idle_base,
                   lambda: habit_stretch(0), lambda: habit_stretch(1), lambda: habit_headphones(0), lambda: habit_headphones(1)]),
    ("sirens", 3, [lambda: sirens(0), lambda: sirens(1)]),
    ("storm", 4, [lambda i=i: storm(i) for i in range(4)]),
    ("rest", 1.5, [lambda: rest(0), lambda: rest(1)]),
    ("ithaca", 2, [lambda: ithaca(0), lambda: ithaca(1)]),
    ("doze", 1.5, [lambda: doze(0), lambda: doze(1)]),
]


def main():
    os.makedirs(OUT, exist_ok=True)
    for f in os.listdir(OUT):
        if f.endswith(".svg"):
            os.remove(os.path.join(OUT, f))
    manifest = ["# Edge Odyssey vector character - Developer Voyager (SVG frames). Source: tools/make_dev_voyager.py",
                "name: Developer Voyager", f"size: {W}x{H}"]
    for name, fps, frames in ANIMS:
        files = []
        for i, draw in enumerate(frames):
            files.append(f"{name}-{i}.svg")
            with open(os.path.join(OUT, files[-1]), "w") as fh:
                fh.write(draw())
        manifest.append(f"anim: {name} fps={fps} frames={','.join(files)}")
    with open(os.path.join(OUT, "character.txt"), "w") as fh:
        fh.write("\n".join(manifest) + "\n")
    print(f"{sum(len(f) for _, _, f in ANIMS)} frames -> {os.path.normpath(OUT)}")


if __name__ == "__main__":
    main()
