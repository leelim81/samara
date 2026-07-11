#!/usr/bin/env python3
"""Generate the Ink and Jade button glyph set: small gold icons used by every
button in the game (wired in code through ui/button_icons.gd).

Outputs 40x40 PNGs to assets/ui/icons/ (all PLACEHOLDER art, documented in
docs/placeholder_art.md). Drawn at 4x supersample with a flat gold fill and a
darker gold outline so they read at 22px next to button text.

Run from the project root:  python3 tools/gen_button_icons.py
"""
import math
import os

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "ui", "icons")
SS = 4
SIZE = 40

GOLD = (232, 198, 124, 255)
GOLD_DARK = (148, 114, 56, 255)
LINE = int(SS * 3.2)


def canvas():
    return Image.new("RGBA", (SIZE * SS, SIZE * SS), (0, 0, 0, 0))


def save(img, name):
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.25))
    img = img.resize((SIZE, SIZE), Image.LANCZOS)
    img.save(os.path.join(OUT, name + ".png"))
    print("  wrote icons/%s.png" % name)


def P(*pts):
    return [(x * SS, y * SS) for x, y in pts]


def outline_polygon(d, pts, fill=GOLD, width=None):
    d.polygon(pts, fill=fill, outline=GOLD_DARK)


# --- glyphs -------------------------------------------------------------------
def g_return(d):
    d.line(P((26, 8), (14, 20), (26, 32)), fill=GOLD, width=int(SS * 4.6), joint="curve")
    d.line(P((26, 8), (14, 20), (26, 32)), fill=GOLD_DARK, width=int(SS * 1.2), joint="curve")


def g_battle(d):
    for sx in (1, -1):
        cxs = [(20 + sx * (x - 20), y) for x, y in [(10, 8), (13, 8), (30, 25), (30, 28), (27, 28), (10, 11)]]
        outline_polygon(d, P(*cxs))
        hx = [(20 + sx * (x - 20), y) for x, y in [(25, 29), (29, 25)]]
        d.line(P(*hx), fill=GOLD, width=int(SS * 5))
        gx = [(20 + sx * (x - 20), y) for x, y in [(31, 31), (34, 34)]]
        d.line(P(*gx), fill=GOLD, width=int(SS * 3.4))


def g_gear(d):
    c = 20 * SS
    for k in range(8):
        a = k * math.tau / 8
        x0, y0 = c + math.cos(a) * 10 * SS, c + math.sin(a) * 10 * SS
        x1, y1 = c + math.cos(a) * 15 * SS, c + math.sin(a) * 15 * SS
        d.line([(x0, y0), (x1, y1)], fill=GOLD, width=int(SS * 5))
    d.ellipse([c - 10 * SS, c - 10 * SS, c + 10 * SS, c + 10 * SS], fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.4))
    d.ellipse([c - 4.6 * SS, c - 4.6 * SS, c + 4.6 * SS, c + 4.6 * SS], fill=(0, 0, 0, 0))


def g_door(d):
    d.rectangle(P((9, 7), (22, 33)), outline=GOLD, width=int(SS * 3))
    d.line(P((26, 14), (34, 20), (26, 26)), fill=GOLD, width=int(SS * 3.6), joint="curve")
    d.line(P((16, 20), (33, 20)), fill=GOLD, width=int(SS * 3.6))


def g_squad(d):
    for cx, cy, r in [(14, 14, 5.4), (26, 14, 5.4)]:
        d.ellipse(P((cx - r, cy - r), (cx + r, cy + r)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))
    d.pieslice(P((5, 20), (23, 38)), 180, 360, fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))
    d.pieslice(P((17, 20), (35, 38)), 180, 360, fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))


def g_figure(d):
    d.ellipse(P((13.5, 6), (26.5, 19)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.4))
    d.pieslice(P((8, 21), (32, 44)), 180, 360, fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.4))


def g_book(d):
    d.polygon(P((6, 10), (19, 13), (19, 33), (6, 30)), fill=GOLD, outline=GOLD_DARK)
    d.polygon(P((34, 10), (21, 13), (21, 33), (34, 30)), fill=GOLD, outline=GOLD_DARK)
    d.line(P((20, 12), (20, 34)), fill=GOLD_DARK, width=int(SS * 1.6))


def g_pouch(d):
    d.polygon(P((12, 14), (28, 14), (33, 30), (26, 36), (14, 36), (7, 30)), fill=GOLD, outline=GOLD_DARK)
    d.line(P((12, 14), (16, 8), (24, 8), (28, 14)), fill=GOLD, width=int(SS * 3.4), joint="curve")
    d.line(P((10, 19), (30, 19)), fill=GOLD_DARK, width=int(SS * 1.8))


def g_scales(d):
    d.line(P((20, 7), (20, 30)), fill=GOLD, width=int(SS * 3.2))
    d.line(P((8, 12), (32, 12)), fill=GOLD, width=int(SS * 3.2))
    for cx in (8, 32):
        d.line(P((cx, 12), (cx - 4.5, 21))[0:1] + P((cx - 4.5, 21)), fill=GOLD, width=int(SS * 1.8))
        d.line(P((cx, 12), (cx + 4.5, 21)), fill=GOLD, width=int(SS * 1.8))
        d.line(P((cx, 12), (cx - 4.5, 21)), fill=GOLD, width=int(SS * 1.8))
        d.pieslice(P((cx - 6.5, 19), (cx + 6.5, 30)), 0, 180, fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))
    d.line(P((13, 34), (27, 34)), fill=GOLD, width=int(SS * 3.6))


def g_question(d):
    d.arc(P((10, 7), (30, 25)), 150, 400, fill=GOLD, width=int(SS * 4.2))
    d.line(P((20, 24), (20, 28)), fill=GOLD, width=int(SS * 4.2))
    d.ellipse(P((17.6, 31), (22.4, 35.8)), fill=GOLD)


def g_plus(d):
    d.line(P((20, 9), (20, 31)), fill=GOLD, width=int(SS * 5))
    d.line(P((9, 20), (31, 20)), fill=GOLD, width=int(SS * 5))


def g_cross(d):
    d.line(P((11, 11), (29, 29)), fill=GOLD, width=int(SS * 5))
    d.line(P((29, 11), (11, 29)), fill=GOLD, width=int(SS * 5))


def g_swap(d):
    d.line(P((8, 14), (28, 14)), fill=GOLD, width=int(SS * 3.6))
    d.polygon(P((28, 9), (35, 14), (28, 19)), fill=GOLD)
    d.line(P((32, 26), (12, 26)), fill=GOLD, width=int(SS * 3.6))
    d.polygon(P((12, 21), (5, 26), (12, 31)), fill=GOLD)


def g_train(d):
    d.polygon(P((20, 6), (30, 16), (24, 16), (24, 24), (16, 24), (16, 16), (10, 16)), fill=GOLD, outline=GOLD_DARK)
    d.line(P((12, 29), (28, 29)), fill=GOLD, width=int(SS * 3.4))
    d.line(P((14, 34), (26, 34)), fill=GOLD, width=int(SS * 3.4))


def g_companion(d):
    d.polygon(P((8, 22), (17, 13), (21, 17), (14, 26)), fill=GOLD)
    d.ellipse(P((16, 12), (26, 22)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))
    d.polygon(P((22, 16), (34, 12), (26, 22)), fill=GOLD)
    d.polygon(P((20, 21), (26, 27), (18, 33), (16, 26)), fill=GOLD)
    d.ellipse(P((22.2, 14.4), (24.4, 16.6)), fill=GOLD_DARK)


def g_awaken(d):
    c = 20 * SS
    for k in range(8):
        a = k * math.tau / 8 + math.pi / 8
        ln = (13 if k % 2 == 0 else 8.5) * SS
        x1, y1 = c + math.cos(a) * ln, c + math.sin(a) * ln
        w = int(SS * (3.6 if k % 2 == 0 else 2.2))
        d.line([(c, c), (x1, y1)], fill=GOLD, width=w)
    d.ellipse([c - 5 * SS, c - 5 * SS, c + 5 * SS, c + 5 * SS], fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.4))


def g_jobs(d):
    d.line(P((20, 34), (20, 22)), fill=GOLD, width=int(SS * 3.8))
    d.line(P((20, 22), (10, 12)), fill=GOLD, width=int(SS * 3.4))
    d.line(P((20, 22), (30, 12)), fill=GOLD, width=int(SS * 3.4))
    d.line(P((20, 22), (20, 10)), fill=GOLD, width=int(SS * 3.4))
    for cx, cy in [(10, 10), (20, 8), (30, 10)]:
        d.ellipse(P((cx - 3.4, cy - 3.4), (cx + 3.4, cy + 3.4)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))


def g_switch(d):
    d.arc(P((8, 8), (32, 32)), 300, 120, fill=GOLD, width=int(SS * 3.8))
    d.arc(P((8, 8), (32, 32)), 120, 300, fill=GOLD, width=int(SS * 3.8))
    d.polygon(P((30, 5), (36, 13), (27, 13)), fill=GOLD)
    d.polygon(P((10, 35), (4, 27), (13, 27)), fill=GOLD)


def g_unlock(d):
    d.rectangle(P((10, 18), (30, 34)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.4))
    d.arc(P((14, 4), (28, 18)), 180, 330, fill=GOLD, width=int(SS * 3.4))
    d.ellipse(P((18, 23), (22, 27)), fill=GOLD_DARK)
    d.line(P((20, 26), (20, 30)), fill=GOLD_DARK, width=int(SS * 2))


def g_locked(d):
    d.rectangle(P((10, 18), (30, 34)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.4))
    d.arc(P((13, 5), (27, 19)), 180, 360, fill=GOLD, width=int(SS * 3.4))
    d.ellipse(P((18, 23), (22, 27)), fill=GOLD_DARK)
    d.line(P((20, 26), (20, 30)), fill=GOLD_DARK, width=int(SS * 2))


def g_check(d):
    d.line(P((9, 21), (17, 29), (32, 11)), fill=GOLD, width=int(SS * 5), joint="curve")


def g_link(d):
    d.rounded_rectangle(P((6, 15), (22, 25)), radius=5 * SS, outline=GOLD, width=int(SS * 3.2))
    d.rounded_rectangle(P((18, 15), (34, 25)), radius=5 * SS, outline=GOLD, width=int(SS * 3.2))


def g_unlink(d):
    d.rounded_rectangle(P((5, 15), (18, 25)), radius=5 * SS, outline=GOLD, width=int(SS * 3))
    d.rounded_rectangle(P((22, 15), (35, 25)), radius=5 * SS, outline=GOLD, width=int(SS * 3))
    d.line(P((26, 9), (14, 31)), fill=GOLD, width=int(SS * 3.4))


def g_buy(d):
    d.ellipse(P((7, 7), (33, 33)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.8))
    d.ellipse(P((11.5, 11.5), (28.5, 28.5)), outline=GOLD_DARK, width=int(SS * 1.4))
    d.line(P((20, 13), (20, 27)), fill=GOLD_DARK, width=int(SS * 2.4))
    d.line(P((15, 17), (25, 17)), fill=GOLD_DARK, width=int(SS * 2.2))
    d.line(P((15, 23), (25, 23)), fill=GOLD_DARK, width=int(SS * 2.2))


def g_skip(d):
    d.polygon(P((8, 10), (19, 20), (8, 30)), fill=GOLD, outline=GOLD_DARK)
    d.polygon(P((20, 10), (31, 20), (20, 30)), fill=GOLD, outline=GOLD_DARK)
    d.line(P((33, 10), (33, 30)), fill=GOLD, width=int(SS * 3.4))


def g_retry(d):
    d.arc(P((8, 8), (32, 32)), 30, 300, fill=GOLD, width=int(SS * 3.8))
    d.polygon(P((34, 15), (36, 6), (27, 9)), fill=GOLD)


def g_arrow_right(d):
    d.line(P((7, 20), (28, 20)), fill=GOLD, width=int(SS * 4.2))
    d.polygon(P((26, 12), (35, 20), (26, 28)), fill=GOLD)


def g_pause(d):
    d.rectangle(P((11, 9), (17, 31)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))
    d.rectangle(P((23, 9), (29, 31)), fill=GOLD, outline=GOLD_DARK, width=int(SS * 1.2))


def g_fast_forward(d):
    d.polygon(P((7, 10), (19, 20), (7, 30)), fill=GOLD, outline=GOLD_DARK)
    d.polygon(P((21, 10), (33, 20), (21, 30)), fill=GOLD, outline=GOLD_DARK)


def g_play(d):
    d.polygon(P((12, 8), (32, 20), (12, 32)), fill=GOLD, outline=GOLD_DARK)


def g_flag(d):
    d.line(P((12, 6), (12, 34)), fill=GOLD, width=int(SS * 3.2))
    d.polygon(P((14, 8), (32, 11), (26, 15), (32, 19), (14, 22)), fill=GOLD, outline=GOLD_DARK)


def g_globe(d):
    d.ellipse(P((7, 7), (33, 33)), outline=GOLD, width=int(SS * 3))
    d.ellipse(P((14, 7), (26, 33)), outline=GOLD, width=int(SS * 2))
    d.line(P((7, 20), (33, 20)), fill=GOLD, width=int(SS * 2))
    d.arc(P((9, -1), (31, 21)), 20, 160, fill=GOLD, width=int(SS * 2))
    d.arc(P((9, 19), (31, 41)), 200, 340, fill=GOLD, width=int(SS * 2))


def g_funnel(d):
    d.line(P((8, 10), (32, 10)), fill=GOLD, width=int(SS * 4))
    d.line(P((12, 18), (28, 18)), fill=GOLD, width=int(SS * 4))
    d.line(P((16, 26), (24, 26)), fill=GOLD, width=int(SS * 4))


def g_more(d):
    for cx in (11, 20, 29):
        d.ellipse(P((cx - 3.2, 16.8), (cx + 3.2, 23.2)), fill=GOLD, outline=GOLD_DARK)


GLYPHS = {
    "return": g_return,
    "battle": g_battle,
    "gear": g_gear,
    "door": g_door,
    "squad": g_squad,
    "figure": g_figure,
    "book": g_book,
    "pouch": g_pouch,
    "scales": g_scales,
    "question": g_question,
    "plus": g_plus,
    "cross": g_cross,
    "swap": g_swap,
    "train": g_train,
    "companion": g_companion,
    "awaken": g_awaken,
    "jobs": g_jobs,
    "switch": g_switch,
    "unlock": g_unlock,
    "locked": g_locked,
    "check": g_check,
    "link": g_link,
    "unlink": g_unlink,
    "buy": g_buy,
    "skip": g_skip,
    "retry": g_retry,
    "arrow_right": g_arrow_right,
    "pause": g_pause,
    "fast_forward": g_fast_forward,
    "play": g_play,
    "flag": g_flag,
    "globe": g_globe,
    "funnel": g_funnel,
    "more": g_more,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, fn in GLYPHS.items():
        img = canvas()
        fn(ImageDraw.Draw(img))
        save(img, name)
    print("done: %d icons" % len(GLYPHS))


main()
