#!/usr/bin/env python3
"""Generate the Terra-Battle-parity battle-UI texture set (Hybrid: dark field + gold HUD).

Repaints existing textures IN PLACE at their exact current dimensions (so the
code-pinned geometry and portrait-clip masks stay valid) and authors a few new
ones. Run from the project root:

    python3 tools/gen_battle_ui_art.py

Backs up every file it overwrites to /tmp/ui_backup/ first. Everything is drawn
at 4x supersample and downscaled with LANCZOS for crisp edges. No external deps
beyond Pillow (numpy used only if present, for the vignette).
"""
import os
import shutil

from PIL import Image, ImageDraw, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TERRA = os.path.join(ROOT, "assets", "terra", "ui")
BACKUP = "/tmp/ui_backup"
SS = 4  # supersample factor

os.makedirs(BACKUP, exist_ok=True)

# ---- palette (RGBA 0-255) --------------------------------------------------
ALLY_CYAN      = (38, 206, 194)
ALLY_CYAN_HI   = (180, 250, 240)
ENEMY_RED      = (255, 96, 70)
ENEMY_RED_HI   = (255, 198, 178)
BOSS_GOLD      = (255, 168, 72)
BOSS_GOLD_HI   = (255, 224, 150)
TILE_TOP       = (243, 236, 222)
TILE_BOT       = (223, 212, 190)
TILE_RIM       = (176, 156, 124, 120)
HP_TOP         = (122, 240, 142)
HP_BOT         = (64, 198, 92)
HP_TRACK       = (15, 21, 28)
HP_TRACK_RIM   = (44, 56, 70)
GOLD_TOP       = (255, 226, 134)
GOLD_BOT       = (222, 170, 70)
GAUGE_TRACK    = (120, 102, 72)
GAUGE_TRACK_RIM= (150, 124, 80)
GRID_LINE      = (96, 84, 64, 90)
GRID_FRAME     = (132, 104, 66, 150)
PLATE_DARK     = (11, 14, 20, 235)
PLATE_RIM      = (150, 170, 200, 140)


def _save(img, name, size):
    """Downscale to target size and write, backing up any existing file."""
    path = os.path.join(TERRA, name)
    if os.path.exists(path):
        shutil.copy2(path, os.path.join(BACKUP, name))
    img = img.resize(size, Image.LANCZOS)
    img.save(path)
    print("  wrote %-30s %s" % (name, size))


def _vgrad(size, top, bot):
    """Vertical gradient RGBA image at supersample size."""
    w, h = size
    g = Image.new("RGBA", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        g.putpixel((0, y), tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)) + (255,))
    return g.resize((w, h))


def _rounded_mask(size, radius):
    m = Image.new("L", size, 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] - 1, size[1] - 1], radius=radius, fill=255)
    return m


# --- tiles ------------------------------------------------------------------
def tile(name, px, radius):
    s = (px * SS, px * SS)
    r = radius * SS
    grad = _vgrad(s, TILE_TOP, TILE_BOT)
    grad.putalpha(_rounded_mask(s, r))
    d = ImageDraw.Draw(grad)
    # subtle inner rim-light just inside the rounded edge
    d.rounded_rectangle([SS, SS, s[0] - 1 - SS, s[1] - 1 - SS], radius=max(1, r - SS),
                        outline=TILE_RIM, width=SS)
    # gentle top sheen
    sheen = Image.new("RGBA", s, (0, 0, 0, 0))
    ImageDraw.Draw(sheen).rounded_rectangle([0, 0, s[0] - 1, int(s[1] * 0.42)], radius=r,
                                            fill=(255, 255, 255, 16))
    sheen.putalpha(Image.composite(sheen.split()[3], Image.new("L", s, 0), _rounded_mask(s, r)))
    grad = Image.alpha_composite(grad, sheen)
    _save(grad, name, (px, px))


# --- luminous glow rim (visible on the parchment field, not a hard border) ---
def border(name, px, radius, color, hi):
    s = (px * SS, px * SS)
    r = radius * SS
    rim = round(2.0 * SS)               # ~2px bright edge (reads as glow, not a slab)
    inset = SS
    # a wide bright ring, blurred, then layered for a strong luminous halo that
    # stands out against the cream battlefield
    ring = Image.new("RGBA", s, (0, 0, 0, 0))
    ImageDraw.Draw(ring).rounded_rectangle([inset, inset, s[0] - 1 - inset, s[1] - 1 - inset],
                                           radius=r, outline=color + (255,), width=rim + SS * 3)
    glow = ring.filter(ImageFilter.GaussianBlur(SS * 2.4))
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    img = Image.alpha_composite(img, glow)
    img = Image.alpha_composite(img, glow)      # double pass = brighter, visible glow
    d = ImageDraw.Draw(img)
    # bright luminous rim
    d.rounded_rectangle([inset, inset, s[0] - 1 - inset, s[1] - 1 - inset],
                        radius=r, outline=color + (255,), width=rim)
    # glassy inner highlight
    d.rounded_rectangle([inset + rim, inset + rim, s[0] - 1 - inset - rim, s[1] - 1 - inset - rim],
                        radius=max(1, r - rim), outline=hi + (170,), width=max(1, SS // 2))
    _save(img, name, (px, px))


# --- horizontal rounded bar (nine-patch friendly) ---------------------------
def bar(name, px, top, bot, rim=None):
    w, h = px
    s = (w * SS, h * SS)
    r = (h * SS) // 2 - SS
    grad = _vgrad(s, top, bot)
    grad.putalpha(_rounded_mask(s, r))
    if rim:
        ImageDraw.Draw(grad).rounded_rectangle([0, 0, s[0] - 1, s[1] - 1], radius=r,
                                               outline=rim + (255,), width=SS)
    # top sheen line
    ImageDraw.Draw(grad).line([(r, SS), (s[0] - r, SS)], fill=(255, 255, 255, 70), width=SS)
    _save(grad, name, px)


# --- grid -------------------------------------------------------------------
def grid(name):
    W, H, cols, rows, t = 602, 802, 6, 8, 100
    s = (W * SS, H * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lw = max(1, SS)
    for i in range(cols + 1):
        x = (1 + i * t) * SS
        d.line([(x, SS), (x, (H - 1) * SS)], fill=GRID_LINE, width=lw)
    for j in range(rows + 1):
        y = (1 + j * t) * SS
        d.line([(SS, y), ((W - 1) * SS, y)], fill=GRID_LINE, width=lw)
    # brighter outer frame
    d.rounded_rectangle([SS, SS, (W - 1) * SS, (H - 1) * SS], radius=3 * SS,
                        outline=GRID_FRAME, width=max(1, round(1.5 * SS)))
    _save(img, name, (W, H))


# --- vignette ---------------------------------------------------------------
def vignette(name):
    W, H = 720, 960
    try:
        import numpy as np
        yy, xx = np.mgrid[0:H, 0:W]
        cx, cy = W / 2, H / 2
        d = np.sqrt(((xx - cx) / cx) ** 2 + ((yy - cy) / cy) ** 2)
        a = np.clip((d - 0.55) / 0.75, 0, 1) ** 1.6 * 120
        out = np.zeros((H, W, 4), dtype=np.uint8)
        out[..., 3] = a.astype(np.uint8)
        Image.fromarray(out, "RGBA").save(os.path.join(TERRA, name))
        print("  wrote %-30s %s" % (name, (W, H)))
    except Exception:
        m = Image.new("L", (W, H), 0)
        dd = ImageDraw.Draw(m)
        dd.ellipse([-W * 0.25, -H * 0.25, W * 1.25, H * 1.25], fill=255)
        m = m.filter(ImageFilter.GaussianBlur(120)).point(lambda v: 120 - int(v * 120 / 255))
        img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        img.putalpha(m)
        img.save(os.path.join(TERRA, name))
        print("  wrote %-30s %s (fallback)" % (name, (W, H)))


# --- countdown plate (dark rounded badge) -----------------------------------
def countdown_plate(name, px=44):
    s = (px * SS, px * SS)
    r = 12 * SS
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([SS, SS, s[0] - 1 - SS, s[1] - 1 - SS], radius=r, fill=PLATE_DARK)
    d.rounded_rectangle([SS, SS, s[0] - 1 - SS, s[1] - 1 - SS], radius=r, outline=PLATE_RIM, width=SS)
    _save(img, name, (px, px))


# --- attribute corner triangle (white, tinted in code) ----------------------
def attr_triangle(name, px=16):
    s = (px * SS, px * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.polygon([(0, s[1] - 1), (s[0] - 1, s[1] - 1), (s[0] - 1, 0)], fill=(255, 255, 255, 255))
    d.line([(0, s[1] - 1), (s[0] - 1, 0)], fill=(255, 255, 255, 255), width=SS)
    _save(img, name, (px, px))


# --- weapon chevron backing (corner pennant, white, tinted in code) ---------
def chevron(name, px=32):
    s = (px * SS, px * SS)
    img = Image.new("RGBA", s, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # top-right anchored triangle tab
    d.polygon([(0, 0), (s[0] - 1, 0), (s[0] - 1, s[1] - 1)], fill=(255, 255, 255, 255))
    _save(img, name, (px, px))


def main():
    print("Generating battle-UI art (backups -> %s):" % BACKUP)
    tile("unit_square_bg.png", 98, 16)
    tile("unit_square_bg_2x2.png", 196, 30)
    border("unit_player_border.png", 98, 16, ALLY_CYAN, ALLY_CYAN_HI)
    border("enemy_border.png", 98, 16, ENEMY_RED, ENEMY_RED_HI)
    border("enemy_border_2x2.png", 196, 30, ENEMY_RED, ENEMY_RED_HI)
    border("boss_border.png", 98, 16, BOSS_GOLD, BOSS_GOLD_HI)
    border("boss_border_2x2.png", 196, 30, BOSS_GOLD, BOSS_GOLD_HI)
    bar("hp_bar_fill.png", (104, 8), HP_TOP, HP_BOT)
    bar("hp_bar_bg.png", (104, 8), HP_TRACK, HP_TRACK, rim=HP_TRACK_RIM)
    bar("bar_fill.png", (119, 16), GOLD_TOP, GOLD_BOT)
    bar("bar_bg.png", (119, 16), GAUGE_TRACK, GAUGE_TRACK, rim=GAUGE_TRACK_RIM)
    grid("grid.png")
    vignette("battle_vignette.png")
    countdown_plate("countdown_plate.png")
    attr_triangle("attr_triangle.png")
    chevron("chevron_marker.png")
    print("Done.")


if __name__ == "__main__":
    main()
