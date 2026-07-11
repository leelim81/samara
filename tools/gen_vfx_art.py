#!/usr/bin/env python3
"""Generate placeholder battle-VFX sprites (per-element bursts + per-weapon
impacts) in the same additive-glow style as the existing assets/vfx set.

Outputs (all PLACEHOLDER art, documented in docs/placeholder_art.md):
  assets/vfx/fire_burst.png       6-frame 768x512 atlas (256px frames)
  assets/vfx/ice_burst.png        6-frame atlas
  assets/vfx/lightning_burst.png  6-frame atlas
  assets/vfx/shadow_burst.png     6-frame atlas
  assets/vfx/thrust_streak.png    512x256 single sprite (spear impact)
  assets/vfx/ricochet_star.png    256x256 single sprite (gun impact)
  assets/vfx/arcane_glyph.png     256x256 single sprite (staff impact)

Drawn procedurally at 4x supersample, LANCZOS downscale, deterministic seed.
Run from the project root:  python3 tools/gen_vfx_art.py
"""
import math
import os
import random

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "vfx")
SS = 4
FRAME = 256
COLS, ROWS = 3, 2

rng = random.Random(20260709)


def _save(img, name):
    path = os.path.join(OUT, name)
    img.save(path)
    print("  wrote %s  %s" % (name, img.size))


def _frame_canvas():
    return Image.new("RGBA", (FRAME * SS, FRAME * SS), (0, 0, 0, 0))


def _atlas(frames, name):
    atlas = Image.new("RGBA", (FRAME * COLS, FRAME * ROWS), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        f = f.resize((FRAME, FRAME), Image.LANCZOS)
        atlas.paste(f, ((i % COLS) * FRAME, (i // COLS) * FRAME))
    _save(atlas, name)


def _petal(draw, cx, cy, angle, length, width, color):
    """Tapered flame/shard petal from center outward."""
    tip = (cx + math.cos(angle) * length, cy + math.sin(angle) * length)
    l1 = (cx + math.cos(angle + 0.5) * width, cy + math.sin(angle + 0.5) * width)
    l2 = (cx + math.cos(angle - 0.5) * width, cy + math.sin(angle - 0.5) * width)
    draw.polygon([l1, tip, l2], fill=color)


# --- fire: ragged flame starburst, embers late ------------------------------
def fire_burst():
    frames = []
    angles = [k * math.tau / 9 + rng.uniform(-0.25, 0.25) for k in range(9)]
    embers = [(rng.uniform(0, math.tau), rng.uniform(0.5, 1.0)) for _ in range(14)]
    c = FRAME * SS // 2
    for i in range(6):
        t = i / 5.0
        img = _frame_canvas()
        d = ImageDraw.Draw(img)
        grow = 0.35 + 0.65 * min(1.0, t * 1.8)
        fade = 255 if t < 0.55 else int(255 * (1.0 - (t - 0.55) / 0.45))
        for k, a in enumerate(angles):
            length = grow * SS * (78 + 34 * ((k * 37) % 5) / 4.0)
            _petal(d, c, c, a, length, SS * 20 * grow, (255, 96, 26, int(fade * 0.85)))
            _petal(d, c, c, a, length * 0.62, SS * 13 * grow, (255, 176, 64, fade))
        r = SS * 34 * grow
        d.ellipse([c - r, c - r, c + r, c + r], fill=(255, 236, 176, fade))
        if t > 0.4:
            for a, sp in embers:
                dist = SS * (60 + 90 * (t - 0.4) / 0.6) * sp
                ex, ey = c + math.cos(a) * dist, c + math.sin(a) * dist
                er = SS * 4 * (1.0 - t * 0.5)
                d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(255, 150, 60, fade))
        frames.append(img.filter(ImageFilter.GaussianBlur(SS * 1.2)))
    _atlas(frames, "fire_burst.png")


# --- ice: crystal shards radiating, shatter late ----------------------------
def ice_burst():
    frames = []
    shards = [(k * math.tau / 10 + rng.uniform(-0.2, 0.2), rng.uniform(0.7, 1.15)) for k in range(10)]
    c = FRAME * SS // 2
    for i in range(6):
        t = i / 5.0
        img = _frame_canvas()
        d = ImageDraw.Draw(img)
        grow = 0.3 + 0.7 * min(1.0, t * 2.2)
        drift = SS * 46 * max(0.0, t - 0.5)  # shards break outward late
        fade = 255 if t < 0.6 else int(255 * (1.0 - (t - 0.6) / 0.4))
        for a, sp in shards:
            base = SS * 92 * sp * grow
            ox, oy = c + math.cos(a) * drift, c + math.sin(a) * drift
            tip = (ox + math.cos(a) * base, oy + math.sin(a) * base)
            w = SS * 9 * grow
            l1 = (ox + math.cos(a + math.pi / 2) * w, oy + math.sin(a + math.pi / 2) * w)
            l2 = (ox + math.cos(a - math.pi / 2) * w, oy + math.sin(a - math.pi / 2) * w)
            tail = (ox - math.cos(a) * base * 0.25, oy - math.sin(a) * base * 0.25)
            d.polygon([l1, tip, l2, tail], fill=(122, 214, 255, int(fade * 0.9)))
            d.line([tail, tip], fill=(230, 250, 255, fade), width=int(SS * 2.4))
        r = SS * 26 * grow * (1.0 - t * 0.5)
        d.ellipse([c - r, c - r, c + r, c + r], fill=(214, 244, 255, fade))
        frames.append(img.filter(ImageFilter.GaussianBlur(SS * 0.8)))
    _atlas(frames, "ice_burst.png")


# --- lightning: jagged bolts, flicker per frame -----------------------------
def _bolt(d, cx, cy, angle, length, color, width):
    pts = [(cx, cy)]
    steps = 5
    for s in range(1, steps + 1):
        frac = s / steps
        jitter = (rng.uniform(-1, 1)) * length * 0.16 * (1 if s < steps else 0.2)
        px = cx + math.cos(angle) * length * frac + math.cos(angle + math.pi / 2) * jitter
        py = cy + math.sin(angle) * length * frac + math.sin(angle + math.pi / 2) * jitter
        pts.append((px, py))
    d.line(pts, fill=color, width=width, joint="curve")


def lightning_burst():
    frames = []
    c = FRAME * SS // 2
    for i in range(6):
        t = i / 5.0
        img = _frame_canvas()
        d = ImageDraw.Draw(img)
        fade = 255 if t < 0.5 else int(255 * (1.0 - (t - 0.5) / 0.5))
        n = 7 if i % 2 == 0 else 5  # flicker
        for k in range(n):
            a = k * math.tau / n + (0.35 if i % 2 else 0.0)
            length = SS * (70 + 60 * min(1.0, t * 2.0)) * rng.uniform(0.8, 1.2)
            _bolt(d, c, c, a, length, (120, 170, 255, int(fade * 0.8)), int(SS * 7))
            _bolt(d, c, c, a, length, (255, 255, 235, fade), int(SS * 2.6))
        if t < 0.45:
            r = SS * 40 * (1.0 - t)
            d.ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 224, fade))
        frames.append(img.filter(ImageFilter.GaussianBlur(SS * 1.0)))
    _atlas(frames, "lightning_burst.png")


# --- shadow: imploding violet ring + spiraling wisps ------------------------
def shadow_burst():
    frames = []
    wisps = [(k * math.tau / 8 + rng.uniform(-0.3, 0.3), rng.uniform(0.75, 1.1)) for k in range(8)]
    c = FRAME * SS // 2
    for i in range(6):
        t = i / 5.0
        img = _frame_canvas()
        d = ImageDraw.Draw(img)
        fade = 255 if t < 0.55 else int(255 * (1.0 - (t - 0.55) / 0.45))
        ring_r = SS * (110 - 62 * t)  # implodes inward
        for w in range(int(SS * 10), 0, -int(SS * 2)):
            alpha = int(fade * 0.16)
            d.ellipse([c - ring_r - w, c - ring_r - w, c + ring_r + w, c + ring_r + w],
                    outline=(150, 70, 220, alpha), width=int(SS * 2.5))
        d.ellipse([c - ring_r, c - ring_r, c + ring_r, c + ring_r],
                outline=(212, 130, 255, fade), width=int(SS * 4))
        for a0, sp in wisps:
            a = a0 + t * 2.6  # spiral
            dist = ring_r * sp
            wx, wy = c + math.cos(a) * dist, c + math.sin(a) * dist
            wr = SS * 9 * (1.0 - t * 0.4)
            d.ellipse([wx - wr, wy - wr, wx + wr, wy + wr], fill=(178, 96, 244, int(fade * 0.9)))
        r = SS * (10 + 26 * t)
        d.ellipse([c - r, c - r, c + r, c + r], fill=(236, 190, 255, fade))
        frames.append(img.filter(ImageFilter.GaussianBlur(SS * 1.6)))
    _atlas(frames, "shadow_burst.png")


# --- weapon impact sprites ---------------------------------------------------
def thrust_streak():
    """Spear: three tapered horizontal streaks with bright tips."""
    w, h = 512 * SS, 256 * SS
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for k, (dy, ln, alpha) in enumerate([(-46, 0.9, 200), (0, 1.0, 255), (46, 0.82, 180)]):
        y = h // 2 + dy * SS
        x0, x1 = w * (1.0 - ln) * 0.5 + SS * 8, w - SS * 16 - (0 if k == 1 else SS * 30)
        d.polygon([(x0, y), (x1, y - SS * 13), (x1 + SS * 26, y), (x1, y + SS * 13)],
                fill=(168, 210, 255, alpha))
        d.line([(x0, y), (x1 + SS * 20, y)], fill=(240, 250, 255, alpha), width=int(SS * 3.4))
    img = img.filter(ImageFilter.GaussianBlur(SS * 1.0))
    _save(img.resize((512, 256), Image.LANCZOS), "thrust_streak.png")


def ricochet_star():
    """Gun: sharp four-point ricochet star with chips."""
    s = 256 * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s // 2
    for a, ln in [(0, 1.0), (math.pi / 2, 0.72), (math.pi, 1.0), (3 * math.pi / 2, 0.72)]:
        _petal(d, c, c, a + 0.28, SS * 104 * ln, SS * 12, (255, 214, 120, 235))
        _petal(d, c, c, a + 0.28, SS * 70 * ln, SS * 7, (255, 246, 214, 255))
    for k in range(7):
        a = rng.uniform(0, math.tau)
        dist = SS * rng.uniform(58, 100)
        px, py = c + math.cos(a) * dist, c + math.sin(a) * dist
        pr = SS * rng.uniform(2.4, 4.6)
        d.ellipse([px - pr, py - pr, px + pr, py + pr], fill=(255, 226, 150, 220))
    r = SS * 20
    d.ellipse([c - r, c - r, c + r, c + r], fill=(255, 250, 232, 255))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.9))
    _save(img.resize((256, 256), Image.LANCZOS), "ricochet_star.png")


def arcane_glyph():
    """Staff: rune ring with diamonds and an inner cross."""
    s = 256 * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s // 2
    r_outer, r_inner = SS * 104, SS * 76
    d.ellipse([c - r_outer, c - r_outer, c + r_outer, c + r_outer],
            outline=(196, 150, 255, 235), width=int(SS * 5))
    d.ellipse([c - r_inner, c - r_inner, c + r_inner, c + r_inner],
            outline=(226, 198, 255, 210), width=int(SS * 3))
    for k in range(4):
        a = k * math.pi / 2 + math.pi / 4
        gx, gy = c + math.cos(a) * (r_outer + r_inner) / 2, c + math.sin(a) * (r_outer + r_inner) / 2
        g = SS * 13
        d.polygon([(gx, gy - g), (gx + g, gy), (gx, gy + g), (gx - g, gy)],
                fill=(238, 214, 255, 245))
    for a in (0, math.pi / 2):
        x0, y0 = c + math.cos(a) * r_inner * 0.82, c + math.sin(a) * r_inner * 0.82
        x1, y1 = c - math.cos(a) * r_inner * 0.82, c - math.sin(a) * r_inner * 0.82
        d.line([(x0, y0), (x1, y1)], fill=(214, 178, 255, 190), width=int(SS * 2.6))
    r = SS * 15
    d.ellipse([c - r, c - r, c + r, c + r], fill=(246, 232, 255, 255))
    img = img.filter(ImageFilter.GaussianBlur(SS * 1.1))
    _save(img.resize((256, 256), Image.LANCZOS), "arcane_glyph.png")


def slash_cut():
    """Sword: a crossed pair of tapered slash streaks."""
    s = 256 * SS
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = s // 2
    for ang, ln, alpha in [(-0.62, 1.0, 255), (0.55, 0.78, 200)]:
        dx, dy = math.cos(ang), math.sin(ang)
        x0, y0 = c - dx * SS * 108 * ln, c - dy * SS * 108 * ln
        x1, y1 = c + dx * SS * 108 * ln, c + dy * SS * 108 * ln
        nx, ny = -dy, dx
        d.polygon([(x0, y0),
                (c + nx * SS * 11 * ln, c + ny * SS * 11 * ln),
                (x1, y1),
                (c - nx * SS * 11 * ln, c - ny * SS * 11 * ln)],
                fill=(196, 220, 244, alpha))
        d.line([(x0, y0), (x1, y1)], fill=(250, 252, 255, alpha), width=int(SS * 3))
    r = SS * 14
    d.ellipse([c - r, c - r, c + r, c + r], fill=(255, 255, 255, 235))
    img = img.filter(ImageFilter.GaussianBlur(SS * 0.9))
    _save(img.resize((256, 256), Image.LANCZOS), "slash_cut.png")


def main():
    os.makedirs(OUT, exist_ok=True)
    fire_burst()
    ice_burst()
    lightning_burst()
    shadow_burst()
    thrust_streak()
    ricochet_star()
    arcane_glyph()
    slash_cut()
    print("done")


main()
